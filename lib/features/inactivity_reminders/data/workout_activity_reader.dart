import 'dart:async';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:hive/hive.dart';

/// The latest workout activity of one account, from its own per-user Hive
/// boxes (the same qualifying activity as the server: a logged set or a
/// started session). Editing or deleting sets and sessions changes it, so
/// [changes] lets the scheduler recompute.
class WorkoutActivityReader {
  WorkoutActivityReader({required UserStorageManager storage}) : _storage = storage;

  final UserStorageManager _storage;

  Future<DateTime?> latestActivity(String uid) async {
    final sets = await _storage.getUserBox<ExerciseSet>('sets', uid);
    final sessions = await _storage.getUserBox<WorkoutSession>('workout_sessions', uid);
    DateTime? latest;
    void consider(DateTime value) {
      final instant = value.toUtc();
      if (latest == null || instant.isAfter(latest!)) latest = instant;
    }

    for (final set in sets.values) {
      consider(set.date);
    }
    for (final session in sessions.values) {
      consider(session.startedAt);
    }
    return latest;
  }

  /// Fires whenever this account's sets or sessions change.
  Stream<void> changes(String uid) => Stream<void>.multi((controller) async {
    final subscriptions = <StreamSubscription<BoxEvent>>[];
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
    try {
      for (final box in <Box<dynamic>>[
        await _storage.getUserBox<ExerciseSet>('sets', uid),
        await _storage.getUserBox<WorkoutSession>('workout_sessions', uid),
      ]) {
        subscriptions.add(box.watch().listen((_) => controller.add(null)));
      }
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
  });
}
