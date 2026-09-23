import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeWorkoutSessionRemoteDataSource implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSessions() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

void main() {
  late Directory tempDir;
  late WorkoutSessionCubit cubit;

  const programA = 'program_A';
  const push1 = 'template_push1';
  const push2 = 'template_push2';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('workout_session_cubit_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(WorkoutSessionAdapter());
    }

    cubit = WorkoutSessionCubit(
      repository: WorkoutSessionRepository(
        remoteDataSource: _FakeWorkoutSessionRemoteDataSource(),
        storageManager: UserStorageManager(),
        uidOverride: () => 'test-uid',
      ),
    );
  });

  tearDown(() async {
    await cubit.close();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('checkActiveSession emits None when nothing has been started yet', () async {
    await cubit.checkActiveSession();
    expect(cubit.state, isA<WorkoutSessionNone>());
  });

  test('startWorkout emits Active with the new session', () async {
    await cubit.startWorkout(programId: programA, workoutTemplateId: push1, workoutNameSnapshot: 'Push 1');

    expect(cubit.state, isA<WorkoutSessionActive>());
    final session = (cubit.state as WorkoutSessionActive).session;
    expect(session.workoutNameSnapshot, equals('Push 1'));
    expect(session.isInProgress, isTrue);
  });

  test('checkActiveSession reflects the session started via startWorkout', () async {
    await cubit.startWorkout(programId: programA, workoutTemplateId: push1, workoutNameSnapshot: 'Push 1');
    final startedId = (cubit.state as WorkoutSessionActive).session.id;

    // Simulates re-opening the app / the Programs hub — this is what
    // makes "survives app restart" work: it just re-reads Hive.
    await cubit.checkActiveSession();

    expect(cubit.state, isA<WorkoutSessionActive>());
    expect((cubit.state as WorkoutSessionActive).session.id, equals(startedId));
  });

  test('starting a second workout while one is active never silently creates a second '
      'session — it emits Conflict carrying the existing one', () async {
    await cubit.startWorkout(programId: programA, workoutTemplateId: push1, workoutNameSnapshot: 'Push 1');
    final firstId = (cubit.state as WorkoutSessionActive).session.id;

    await cubit.startWorkout(programId: programA, workoutTemplateId: push2, workoutNameSnapshot: 'Push 2');

    expect(cubit.state, isA<WorkoutSessionConflict>());
    expect((cubit.state as WorkoutSessionConflict).existingSession.id, equals(firstId));

    // Confirm no second session was created in storage.
    final box = await cubit.repository.getUserBox();
    expect(box.values.where((s) => s.isInProgress).length, equals(1));
  });

  test('cancelWorkout requires an explicit call and results in None afterward', () async {
    await cubit.startWorkout(programId: programA, workoutTemplateId: push1, workoutNameSnapshot: 'Push 1');
    final sessionId = (cubit.state as WorkoutSessionActive).session.id;

    await cubit.cancelWorkout(sessionId);

    expect(cubit.state, isA<WorkoutSessionNone>());

    final box = await cubit.repository.getUserBox();
    final cancelled = box.get(sessionId);
    expect(cancelled, isNotNull);
    expect(cancelled!.isCancelled, isTrue);
  });

  test(
    'finishWorkout persists the caller-computed totalVolume, marks the session completed, '
    'and results in None afterward (Phase 10)',
    () async {
      await cubit.startWorkout(programId: programA, workoutTemplateId: push1, workoutNameSnapshot: 'Push 1');
      final sessionId = (cubit.state as WorkoutSessionActive).session.id;

      await cubit.finishWorkout(sessionId: sessionId, totalVolume: 480);

      expect(cubit.state, isA<WorkoutSessionNone>());

      final box = await cubit.repository.getUserBox();
      final finished = box.get(sessionId);
      expect(finished, isNotNull);
      expect(finished!.isCompleted, isTrue);
      expect(finished.totalVolume, equals(480));
      expect(finished.completedAt, isNotNull);
    },
  );

  test('finishWorkout on an already-finished session emits an Error and never overwrites it', () async {
    await cubit.startWorkout(programId: programA, workoutTemplateId: push1, workoutNameSnapshot: 'Push 1');
    final sessionId = (cubit.state as WorkoutSessionActive).session.id;
    await cubit.finishWorkout(sessionId: sessionId, totalVolume: 480);

    await cubit.finishWorkout(sessionId: sessionId, totalVolume: 999);

    expect(cubit.state, isA<WorkoutSessionError>());
    expect((cubit.state as WorkoutSessionError).operation, equals(WorkoutSessionOperation.finish));

    final box = await cubit.repository.getUserBox();
    // The original completed volume must survive untouched.
    expect(box.get(sessionId)!.totalVolume, equals(480));
  });

  test(
    'reset() clears a leftover Active state back to Initial (Phase 21 audit fix — '
    'this Cubit is a process-lifetime singleton and must not leak state across a logout)',
    () async {
      await cubit.startWorkout(programId: programA, workoutTemplateId: push1, workoutNameSnapshot: 'Push 1');
      expect(cubit.state, isA<WorkoutSessionActive>());

      cubit.reset();

      expect(cubit.state, isA<WorkoutSessionInitial>());
      // The underlying session itself must NOT be touched by reset() —
      // this only clears the in-memory Cubit state, never storage.
      final box = await cubit.repository.getUserBox();
      expect(box.values.where((s) => s.isInProgress), hasLength(1));
    },
  );

  test('reset() on an already-Initial cubit is a harmless no-op', () {
    expect(cubit.state, isA<WorkoutSessionInitial>());
    cubit.reset();
    expect(cubit.state, isA<WorkoutSessionInitial>());
  });
}
