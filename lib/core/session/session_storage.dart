import 'package:hive_flutter/hive_flutter.dart';

/// Owns the `authBox` session contract: the local "setup finished"
/// marker that lets a verified session open Home offline (see
/// resolveStartupDestination). It is a hint only. Firebase Auth is
/// authoritative, and on the auth side only AuthFlowNavigation.enterApp
/// writes it.
///
/// A thin wrapper over the already-open global `authBox`, so call sites
/// use intent-named methods instead of raw key strings.
///
/// Canonical keys:
/// - `isLoggedIn` (bool, default false)
/// - `currentUserUid` (String, default '')
/// - `currentUserName` (String, default '')
/// - `currentUserEmail` (String, default '')
///
/// `currentUserPhone` was written by phone-era builds. It is never written
/// any more, only deleted (on every persist and on logout), so an upgraded
/// install can't keep a previous user's phone number on the device.
///
/// Ownership note (Stage 8 audit): [LocaleCubit] also owns a key
/// (`appLocale`) in this same `authBox`, independently of this class.
/// The two key sets are disjoint by design; see [LocaleCubit]'s doc
/// comment for the full rationale for leaving this shared-box
/// arrangement unchanged.
class SessionStorage {
  final Box _box;

  /// Phone-era key: deleted, never written (see class docs).
  static const String _legacyPhoneKey = 'currentUserPhone';

  const SessionStorage(this._box);

  bool get isLoggedIn => _box.get('isLoggedIn', defaultValue: false) as bool;

  String get currentUserUid =>
      _box.get('currentUserUid', defaultValue: '') as String;

  String get currentUserEmail =>
      _box.get('currentUserEmail', defaultValue: '') as String;

  String get currentUserName =>
      _box.get('currentUserName', defaultValue: '') as String;

  /// Writes the full "fully logged in" session — the 4-key write
  /// previously duplicated verbatim across 6 view files. Callers must
  /// only invoke this once a session is actually ready to be considered
  /// complete (e.g. never before a Phase 4 mandatory migration finishes
  /// — see loginview.dart / session_reconciliation_view.dart).
  ///
  /// No credential, token or verification flag is ever stored here:
  /// Firebase Auth owns those.
  Future<void> persistLoggedInSession({
    required String uid,
    required String name,
    String? email,
  }) async {
    await _box.put('isLoggedIn', true);
    await _box.put('currentUserUid', uid);
    await _box.put('currentUserName', name);
    if (email != null && email.isNotEmpty) {
      await _box.put('currentUserEmail', email);
    } else {
      await _box.delete('currentUserEmail');
    }
    await _box.delete(_legacyPhoneKey);
  }

  /// Full logout: matches `hom.dart`'s `_logout()` exactly — sets
  /// `isLoggedIn` to false (not deleted, kept as an explicit key) and
  /// deletes the 3 identity keys. Does not touch Firebase, per-user
  /// Hive boxes, or `WorkoutSessionCubit` — callers remain responsible
  /// for those, exactly as before.
  Future<void> clearSession() async {
    await _box.put('isLoggedIn', false);
    await _box.delete('currentUserUid');
    await _box.delete('currentUserName');
    await _box.delete(_legacyPhoneKey);
    await _box.delete('currentUserEmail');
  }

  /// Matches `hom.dart._initUserBox()`'s empty-uid branch exactly: marks
  /// the session as logged out WITHOUT deleting the identity keys. A
  /// narrower operation than [clearSession] — kept distinct rather than
  /// unified with it, since this stage is behavior-preserving and the
  /// two call sites have always done different things.
  Future<void> markLoggedOut() async {
    await _box.put('isLoggedIn', false);
  }

  /// Matches the `currentUserUid`-only write in
  /// `hom.dart._initUserBox()` and `WorkoutCubit._getWorkoutBox()`
  /// exactly — a partial "keep this one key fresh" write, distinct from
  /// [persistLoggedInSession]'s full 4-key write.
  Future<void> updateCurrentUserUid(String uid) async {
    await _box.put('currentUserUid', uid);
  }

  Future<void> updateCurrentUserName({
    required String uid,
    required String name,
  }) async {
    if (uid.isEmpty || currentUserUid != uid) {
      throw StateError('Refusing to update a different session user.');
    }
    await _box.put('currentUserName', name);
  }
}
