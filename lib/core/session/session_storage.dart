import 'package:hive_flutter/hive_flutter.dart';

/// Owns the `authBox` session contract that used to be duplicated
/// directly across auth views (`Hive.box('authBox').put(...)`/`.get(...)`
/// call sites in `loginview.dart`, `register_view.dart`, `otp_view.dart`,
/// `complete_registration_view.dart`, `session_reconciliation_view.dart`,
/// `verify_phone_migration_view.dart`, `hom.dart`, and
/// `workout_cubit.dart`).
///
/// This is a thin wrapper, not a new storage layer: it takes an already
/// -open [Box] (the same global `authBox` `main.dart` opens at startup)
/// and exposes exactly the operations those call sites already
/// performed, under names that describe intent instead of repeating the
/// same 4 raw key strings everywhere. Every method here is a direct,
/// behavior-preserving translation of an existing call site — nothing
/// new was invented.
///
/// The 4 canonical keys and their exact semantics, unchanged:
/// - `isLoggedIn` (bool, default false)
/// - `currentUserUid` (String, default '')
/// - `currentUserName` (String, default '')
/// - `currentUserPhone` (String — write/delete only; nothing in this
///   codebase reads it back, so no getter is exposed for it)
class SessionStorage {
  final Box _box;

  const SessionStorage(this._box);

  bool get isLoggedIn => _box.get('isLoggedIn', defaultValue: false) as bool;

  String get currentUserUid =>
      _box.get('currentUserUid', defaultValue: '') as String;

  String get currentUserName =>
      _box.get('currentUserName', defaultValue: '') as String;

  /// Writes the full "fully logged in" session — the 4-key write
  /// previously duplicated verbatim across 6 view files. Callers must
  /// only invoke this once a session is actually ready to be considered
  /// complete (e.g. never before a Phase 4 mandatory migration finishes
  /// — see loginview.dart / session_reconciliation_view.dart).
  Future<void> persistLoggedInSession({
    required String uid,
    required String name,
    required String phone,
  }) async {
    await _box.put('isLoggedIn', true);
    await _box.put('currentUserUid', uid);
    await _box.put('currentUserName', name);
    await _box.put('currentUserPhone', phone);
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
    await _box.delete('currentUserPhone');
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
}
