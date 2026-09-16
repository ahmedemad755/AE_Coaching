import 'package:ae_coaching/features/workout/data/datasources/workout_program_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/workout_id_generator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Data layer for [WorkoutProgram] — Hive (offline-first) + Firestore
/// sync, following the exact same shape as `WorkoutRepositoryImpl` and
/// `MeasurementRepository`.
///
/// Storage:
/// - Local: `workout_programs_$uid` Hive box, keyed by the program's own
///   `id` (not Hive's auto-increment key) so WorkoutTemplate/
///   WorkoutSession (later phases) can reference a stable `programId`.
/// - Cloud: `users/{uid}/workout_programs/{id}`.
///
/// Does not touch `sets_$uid`, `measurements_$uid`, or
/// `progress_photos_$uid` — entirely separate box.
class WorkoutProgramRepository {
  final WorkoutProgramRemoteDataSource remoteDataSource;

  /// Overrides the resolved uid instead of reading
  /// `FirebaseAuth.instance.currentUser`. Exists only so unit tests can
  /// exercise this repository without a real Firebase app — production
  /// code must never pass this.
  @visibleForTesting
  final String? Function()? uidOverride;

  WorkoutProgramRepository({
    WorkoutProgramRemoteDataSource? remoteDataSource,
    @visibleForTesting this.uidOverride,
  }) : remoteDataSource = remoteDataSource ?? WorkoutProgramRemoteDataSourceImpl();

  Future<Box<WorkoutProgram>> getUserBox() async {
    final uid = uidOverride?.call() ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    final boxName = 'workout_programs_$uid';
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<WorkoutProgram>(boxName);
    }

    return Hive.openBox<WorkoutProgram>(boxName);
  }

  /// Creates a new program. Pass [makeActive] to also run the
  /// single-active-program invariant (deactivating whatever was active
  /// before, without deleting it).
  Future<WorkoutProgram> createProgram({
    required String name,
    String? description,
    bool makeActive = false,
  }) async {
    final box = await getUserBox();
    final id = WorkoutIdGenerator.generate('program');
    final program = WorkoutProgram(
      id: id,
      name: name,
      description: description,
      createdAt: DateTime.now(),
    );

    await box.put(id, program);
    await _syncSafely(id, program);

    if (makeActive) {
      await setActiveProgram(id);
      return box.get(id) ?? program;
    }

    return program;
  }

  Future<void> updateProgram(WorkoutProgram program) async {
    final box = await getUserBox();
    await box.put(program.id, program);
    await _syncSafely(program.id, program);
  }

  /// Every stored program for the current user, newest first.
  List<WorkoutProgram> getPrograms(Box<WorkoutProgram> box) {
    final all = box.values.toList();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  /// The single program currently marked active, or null if none is.
  WorkoutProgram? getActiveProgram(Box<WorkoutProgram> box) {
    for (final program in box.values) {
      if (program.isActive) return program;
    }
    return null;
  }

  /// Makes [programId] the only active program.
  ///
  /// Critical invariant: any other program currently active is
  /// deactivated first (isActive = false) — it is NEVER deleted, and
  /// stays fully intact in history. Only one program is active at a
  /// time.
  Future<void> setActiveProgram(String programId) async {
    final box = await getUserBox();

    for (final program in box.values.toList()) {
      if (program.isActive && program.id != programId) {
        final deactivated = program.copyWith(isActive: false);
        await box.put(program.id, deactivated);
        await _syncSafely(program.id, deactivated);
      }
    }

    final target = box.get(programId);
    if (target == null) {
      throw Exception('Workout program not found.');
    }

    // Reactivating a program clears any stale `endedAt` left over from a
    // previous archive — an active program should never carry an
    // "ended" stamp. copyWith can't null out a field (by design, same
    // as BodyMeasurement's), so build the object directly here.
    final activated = WorkoutProgram(
      id: target.id,
      name: target.name,
      description: target.description,
      createdAt: target.createdAt,
      startedAt: target.startedAt ?? DateTime.now(),
      endedAt: null,
      isActive: true,
    );
    await box.put(programId, activated);
    await _syncSafely(programId, activated);
  }

  /// Deactivates a program and stamps `endedAt` if not already set.
  /// Does not delete it — it remains in history as a previous program.
  Future<void> archiveProgram(String programId) async {
    final box = await getUserBox();
    final target = box.get(programId);
    if (target == null) return;

    final archived = target.copyWith(
      isActive: false,
      endedAt: target.endedAt ?? DateTime.now(),
    );
    await box.put(programId, archived);
    await _syncSafely(programId, archived);
  }

  /// Deletes ONLY this program's own record (local + remote) — never
  /// its templates/sessions/sets. [archiveProgram] remains the normal,
  /// non-destructive "I'm done with this" action; use this only as the
  /// last step of a full cascade delete (see
  /// `WorkoutCascadeDeletionService.deleteProgramCascade`, which
  /// deletes every template/session/set under this program FIRST, then
  /// calls this). Calling this directly on a program that still has
  /// templates/sessions would orphan them — always go through the
  /// cascade service from the UI layer.
  Future<void> deleteProgram(String programId) async {
    final box = await getUserBox();
    await box.delete(programId);

    try {
      await remoteDataSource.deleteProgram(programId);
    } catch (error, stackTrace) {
      debugPrint('WorkoutProgram remote delete failed: $error\n$stackTrace');
      rethrow;
    }
  }

  /// Pulls every program stored in the cloud into the local box, then
  /// pushes up any local-only program the cloud doesn't know about yet
  /// — same merge pattern as Workout/Measurement sync.
  Future<void> fetchAndSyncFromRemote(Box<WorkoutProgram> box) async {
    try {
      final remoteDocs = await remoteDataSource.fetchAllRemotePrograms();
      final remoteIds = remoteDocs.map((doc) => doc.id).toSet();

      for (final doc in remoteDocs) {
        final program = WorkoutProgram.fromJson(doc.data());
        await box.put(doc.id, program);
      }

      for (final localId in box.keys) {
        final localProgram = box.get(localId);
        if (localProgram == null || remoteIds.contains(localId)) {
          continue;
        }
        await remoteDataSource.syncProgram(localId as String, localProgram);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch and sync workout programs from cloud: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> _syncSafely(String id, WorkoutProgram program) async {
    try {
      await remoteDataSource.syncProgram(id, program);
    } catch (error, stackTrace) {
      debugPrint('WorkoutProgram remote sync failed: $error\n$stackTrace');
      rethrow;
    }
  }
}
