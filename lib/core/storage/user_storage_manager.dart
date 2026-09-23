import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/features/progress_photos/data/models/progress_photo.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Thrown when [UserStorageManager.closeForUser] fails to close one or
/// more of a user's boxes. Deliberately does NOT include box contents
/// or the raw underlying error in [toString] — callers that need the
/// underlying cause read [failures] directly (for logging), never for
/// display to the user.
class UserStorageCloseException implements Exception {
  final String uid;

  /// Box name -> the error that occurred closing it. Only entries that
  /// actually failed; a box that was never opened for this uid is never
  /// listed as a "failure".
  final Map<String, Object> failures;

  const UserStorageCloseException({required this.uid, required this.failures});

  @override
  String toString() =>
      'UserStorageCloseException: failed to close ${failures.length} '
      'box(es) for the outgoing user.';
}

/// The single lifecycle owner for every per-user Hive box in the app.
///
/// This is NOT a second cache that can disagree with Hive —
/// `Hive.isBoxOpen`/`Hive.box` remain the ground truth for "is this box
/// open"; this class only tracks what Hive itself has no concept of:
/// which boxes belong to which uid (needed to answer "close everything
/// for this user"), and in-flight open/close operations (needed to
/// dedupe concurrent callers without introducing a second registry that
/// could drift out of sync with Hive's own).
///
/// No static/shared singleton lives here (deliberately, per the Stage 3
/// design correction) — the ONE production instance is whatever GetIt
/// resolves via `sl<UserStorageManager>()` (registered in
/// `service_locator.dart`'s `initCore()`), and every production
/// consumer receives it by constructor injection. This class never
/// calls GetIt itself.
class UserStorageManager {
  UserStorageManager();

  /// Closed, canonical prefix -> model-type mapping for the 6
  /// supported per-user boxes. `getUserBox` validates BOTH the prefix
  /// and the caller's requested `T` against this map before touching
  /// Hive at all — an unknown prefix or a mismatched `T` is rejected
  /// deterministically here, not left to a later cast or to Hive's own
  /// runtime type check to catch.
  static const Map<String, Type> supportedBoxes = {
    'sets': ExerciseSet,
    'workout_programs': WorkoutProgram,
    'workout_templates': WorkoutTemplate,
    'workout_sessions': WorkoutSession,
    'measurements': BodyMeasurement,
    'progress_photos': ProgressPhoto,
  };

  final Map<String, Box<dynamic>> _ownedBoxes = {};
  final Map<String, Future<Box<dynamic>>> _openingFutures = {};
  final Map<String, Future<void>> _closingFutures = {};
  final Set<String> _uidsClosing = {};

  @visibleForTesting
  Set<String> get ownedBoxNamesForTesting => _ownedBoxes.keys.toSet();

  @visibleForTesting
  int get inFlightOpenCountForTesting => _openingFutures.length;

  static String boxNameFor(String prefix, String uid) => '${prefix}_$uid';

  void _validate<T>(String prefix, String uid) {
    final expectedType = supportedBoxes[prefix];
    if (expectedType == null) {
      throw ArgumentError.value(
        prefix,
        'prefix',
        'Unknown per-user box prefix. Supported prefixes: '
            '${supportedBoxes.keys.join(', ')}.',
      );
    }
    if (expectedType != T) {
      throw ArgumentError.value(
        T,
        'T',
        'Prefix "$prefix" is registered for $expectedType, not $T.',
      );
    }
    if (uid.isEmpty) {
      throw ArgumentError.value(
        uid,
        'uid',
        'A non-empty uid is required to access per-user storage.',
      );
    }
  }

  /// Resolves the box for ([prefix], [uid]), opening it if necessary.
  /// [prefix] and `T` are validated against [supportedBoxes] and [uid]
  /// is validated non-empty — all three checks happen before any Hive
  /// call. Concurrent calls for the same (prefix, uid) share one
  /// in-flight open rather than each calling `Hive.openBox`
  /// independently.
  Future<Box<T>> getUserBox<T>(String prefix, String uid) async {
    _validate<T>(prefix, uid);

    if (_uidsClosing.contains(uid)) {
      throw StateError(
        'Cannot open "$prefix" storage for this user while their '
        'storage is being closed (logout/account switch in progress). '
        'This is rejected outright, not queued — a caller reaching '
        'this means stale work is racing a logout.',
      );
    }

    final boxName = boxNameFor(prefix, uid);

    final owned = _ownedBoxes[boxName];
    if (owned != null) {
      if (Hive.isBoxOpen(boxName)) {
        return owned as Box<T>;
      }
      // Hive disagrees with our record (closed by something outside
      // our knowledge) — trust Hive, drop the stale entry.
      _ownedBoxes.remove(boxName);
    }

    final inFlight = _openingFutures[boxName];
    if (inFlight != null) {
      return (await inFlight) as Box<T>;
    }

    final opening = _openAndTrack<T>(boxName);
    _openingFutures[boxName] = opening;
    try {
      return await opening;
    } finally {
      _openingFutures.remove(boxName);
    }
  }

  Future<Box<T>> _openAndTrack<T>(String boxName) async {
    final box = Hive.isBoxOpen(boxName)
        ? Hive.box<T>(boxName)
        : await Hive.openBox<T>(boxName);
    _ownedBoxes[boxName] = box;
    return box;
  }

  /// Closes every box owned for [uid] (across all 6 supported
  /// prefixes) — never `authBox`, never any box outside this manager's
  /// own [supportedBoxes] list, and never a disk delete.
  ///
  /// Honest guarantee, not oversold: this can only close boxes it owns
  /// a `Box<T>` reference for. A caller that already obtained a `Box`
  /// via [getUserBox] and is mid-write when this runs is governed by
  /// Hive's own close/write behavior for that in-flight operation —
  /// this manager cannot retroactively cancel a write already in
  /// flight against a reference the caller is holding directly.
  ///
  /// If closing one box fails, the remaining boxes for this uid are
  /// still attempted (a single failure never abandons the rest of
  /// cleanup). A box that fails to close stays in the ownership
  /// registry (so a retry can find and re-attempt it); only boxes
  /// confirmed closed are removed. If any box failed, this throws a
  /// [UserStorageCloseException] listing which ones — logout must treat
  /// that as "not fully complete", not swallow it.
  Future<void> closeForUser(String uid) {
    if (uid.isEmpty) {
      throw ArgumentError.value(
        uid,
        'uid',
        'A non-empty uid is required to close per-user storage.',
      );
    }

    final existing = _closingFutures[uid];
    if (existing != null) {
      return existing;
    }

    final future = _closeForUser(uid);
    _closingFutures[uid] = future;
    return future.whenComplete(() => _closingFutures.remove(uid));
  }

  Future<void> _closeForUser(String uid) async {
    _uidsClosing.add(uid);
    final failures = <String, Object>{};
    try {
      for (final prefix in supportedBoxes.keys) {
        final boxName = boxNameFor(prefix, uid);

        // An open still in flight for this exact box is awaited first
        // — never close out from under an opener, and never leave a
        // just-opened box ownerless because we raced past it.
        final inFlightOpen = _openingFutures[boxName];
        if (inFlightOpen != null) {
          try {
            await inFlightOpen;
          } catch (_) {
            continue; // the open itself failed — nothing owned here
          }
        }

        final box = _ownedBoxes[boxName];
        if (box == null) continue;

        try {
          if (box.isOpen) {
            await box.close();
          }
          _ownedBoxes.remove(boxName); // only on CONFIRMED close
        } catch (error, stackTrace) {
          debugPrint(
            'UserStorageManager: failed to close a per-user box: '
            '$error\n$stackTrace',
          );
          failures[boxName] = error;
          // Deliberately NOT removed from _ownedBoxes — stays tracked
          // so a retry can find and re-attempt it.
        }
      }
    } finally {
      _uidsClosing.remove(uid);
    }

    if (failures.isNotEmpty) {
      throw UserStorageCloseException(uid: uid, failures: failures);
    }
  }
}

/// Thin, stateless typed accessor over the shared [UserStorageManager].
/// Holds no lifecycle state of its own — every repository constructs
/// one of these around the SAME injected manager instance rather than
/// owning any storage state itself.
class UserBox<T> {
  final UserStorageManager manager;
  final String prefix;

  /// @visibleForTesting seam — overrides Firebase's current user for
  /// tests that have no real Firebase app. Never used in production.
  final String? Function()? uidOverride;

  const UserBox({
    required this.manager,
    required this.prefix,
    this.uidOverride,
  });

  Future<Box<T>> getUserBox() {
    final uid = uidOverride?.call() ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    // Preserves the EXACT historical exception (type and message) every
    // repository's own getUserBox() already threw for this case, before
    // this refactor existed — callers/tests that expect
    // `Exception('User not authenticated')` specifically must keep
    // seeing it. UserStorageManager.getUserBox ALSO independently
    // rejects an empty uid (via ArgumentError, appropriate for a
    // programming-error-shaped internal contract) — this is defense in
    // depth, not a contradiction: the manager must be safe to call
    // directly, but this is the layer that preserves the public,
    // user-facing behavior every existing repository already has.
    if (uid.isEmpty) {
      throw Exception('User not authenticated');
    }
    return manager.getUserBox<T>(prefix, uid);
  }
}
