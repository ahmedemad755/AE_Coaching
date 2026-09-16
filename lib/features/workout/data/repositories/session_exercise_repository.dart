import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Handles session-linked [ExerciseSet] creation/deletion for the
/// active-workout logging UI (Phase 8+).
///
/// Deliberately reuses the SAME `sets_$uid` Hive box and the SAME
/// `WorkoutRemoteDataSource`/`exercise_sets` Firestore collection that
/// the legacy `WorkoutCubit`/`WorkoutRepositoryImpl` already use —
/// Phase 4 made this safe by adding nullable `programId`/
/// `workoutTemplateId`/`workoutSessionId` fields, so session-linked
/// sets and legacy (null-linked) sets coexist in the same box without
/// conflict. This class never touches `WorkoutCubit` itself; it is a
/// separate, additive code path that happens to share storage.
class SessionExerciseRepository {
  final WorkoutRemoteDataSource remoteDataSource;

  @visibleForTesting
  final String? Function()? uidOverride;

  SessionExerciseRepository({
    WorkoutRemoteDataSource? remoteDataSource,
    @visibleForTesting this.uidOverride,
  }) : remoteDataSource = remoteDataSource ?? WorkoutRemoteDataSourceImpl();

  Future<Box<ExerciseSet>> getUserBox() async {
    final uid = uidOverride?.call() ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    final boxName = 'sets_$uid';
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<ExerciseSet>(boxName);
    }
    return Hive.openBox<ExerciseSet>(boxName);
  }

  /// Every set belonging to [sessionId], in insertion order.
  List<ExerciseSet> getSetsForSession(Box<ExerciseSet> box, String sessionId) {
    return box.values.where((s) => s.workoutSessionId == sessionId).toList();
  }

  /// Distinct exercise names that have at least one set in [sessionId],
  /// in first-appearance order — this is "the structure" of a session.
  List<String> getExerciseNamesForSession(Box<ExerciseSet> box, String sessionId) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final set in getSetsForSession(box, sessionId)) {
      if (seen.add(set.exerciseName)) {
        ordered.add(set.exerciseName);
      }
    }
    return ordered;
  }

  /// Sets for one specific exercise within [sessionId], in the order
  /// they were logged.
  List<ExerciseSet> getSetsForExerciseInSession(Box<ExerciseSet> box, String sessionId, String exerciseName) {
    return getSetsForSession(box, sessionId).where((s) => s.exerciseName == exerciseName).toList();
  }

  /// Logs one new set, linked to [workoutSessionId] (and its parent
  /// program/template) — never touches ExerciseSet's constructor
  /// shape, only uses the fields Phase 4 already added. [notes] reuses
  /// the ORIGINAL `notes` field (typeId 0, HiveField 4) that the
  /// legacy Workout Tracker has always had — no new Hive field for
  /// Phase 18's exercise-level notes.
  Future<ExerciseSet> addSet({
    required String programId,
    required String workoutTemplateId,
    required String workoutSessionId,
    required String exerciseName,
    required double weight,
    required int reps,
    String? notes,
  }) async {
    final box = await getUserBox();
    final set = ExerciseSet(
      exerciseName: exerciseName,
      weight: weight,
      reps: reps,
      date: DateTime.now(),
      notes: _normalize(notes),
      programId: programId,
      workoutTemplateId: workoutTemplateId,
      workoutSessionId: workoutSessionId,
    );
    final key = await box.add(set);

    try {
      await remoteDataSource.syncSet(key.toString(), set);
    } catch (error, stackTrace) {
      debugPrint('Session-linked set remote sync failed: $error\n$stackTrace');
      rethrow;
    }
    return set;
  }

  /// [notes] is the new note text to save — always overwrites (an
  /// empty/whitespace-only string clears it to `null`, same
  /// normalization as [addSet]); pass `existing.notes` back explicitly
  /// if the caller isn't changing it.
  Future<void> updateSet(ExerciseSet existing, {required double weight, required int reps, String? notes}) async {
    final key = existing.key.toString();
    final updated = ExerciseSet(
      exerciseName: existing.exerciseName,
      weight: weight,
      reps: reps,
      date: existing.date,
      notes: _normalize(notes),
      programId: existing.programId,
      workoutTemplateId: existing.workoutTemplateId,
      workoutSessionId: existing.workoutSessionId,
    );
    await existing.delete();
    final box = await getUserBox();
    await box.put(existing.key, updated);

    try {
      await remoteDataSource.syncSet(key, updated);
    } catch (error, stackTrace) {
      debugPrint('Session-linked set remote sync failed: $error\n$stackTrace');
      rethrow;
    }
  }

  /// Trims and turns an empty/whitespace-only string into `null` — the
  /// one normalization rule every note-writing path in this repository
  /// shares, so "the user cleared the text field" reliably means "no
  /// note", not a stored empty string.
  String? _normalize(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> deleteSet(ExerciseSet set) async {
    final key = set.key.toString();
    await set.delete();

    try {
      await remoteDataSource.deleteSet(key);
    } catch (error, stackTrace) {
      debugPrint('Session-linked set remote delete failed: $error\n$stackTrace');
      rethrow;
    }
  }
}
