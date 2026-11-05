import 'dart:io';

import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_history_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeWorkoutSessionRemoteDataSource
    implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}
  @override
  Future<void> deleteSession(String id) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSessions() async => const [];
}

class _FakeWorkoutRemoteDataSource implements WorkoutRemoteDataSource {
  @override
  Future<void> syncSet(String key, ExerciseSet set) async {}
  @override
  Future<void> deleteSet(String key) async {}
  @override
  Future<void> deleteMultipleSets(List<String> keys) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSets() async => const [];
}

void main() {
  late Directory tempDir;
  late WorkoutHistoryCubit cubit;
  late WorkoutSessionRepository sessionRepository;
  late SessionExerciseRepository setRepository;

  const programA = 'program_A';
  const push1 = 'template_push1';
  const push2 = 'template_push2';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('workout_history_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ExerciseSetAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(WorkoutSessionAdapter());
    }

    final storageManager = UserStorageManager();
    sessionRepository = WorkoutSessionRepository(
      remoteDataSource: _FakeWorkoutSessionRemoteDataSource(),
      storageManager: storageManager,
      uidOverride: () => 'test-uid',
    );
    setRepository = SessionExerciseRepository(
      remoteDataSource: _FakeWorkoutRemoteDataSource(),
      storageManager: storageManager,
      uidOverride: () => 'test-uid',
    );
    cubit = WorkoutHistoryCubit(
      sessionRepository: sessionRepository,
      setRepository: setRepository,
    );
  });

  tearDown(() async {
    await cubit.close();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('a template with no sessions yet loads an empty list', () async {
    await cubit.loadHistory(push1);

    final state = cubit.state as WorkoutHistoryLoaded;
    expect(state.sessions, isEmpty);
  });

  test('history loads set details and excludes mismatched template links', () async {
    final session = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    final setBox = await setRepository.getUserBox();
    await setBox.add(
      ExerciseSet(
        exerciseName: 'Bench Press',
        weight: 45,
        reps: 8,
        date: DateTime(2026, 10, 25, 10, 30),
        notes: 'Keep elbows tucked',
        programId: programA,
        workoutTemplateId: push1,
        workoutSessionId: session.id,
      ),
    );
    await setBox.add(
      ExerciseSet(
        exerciseName: 'Wrong day set',
        weight: 100,
        reps: 1,
        date: DateTime(2026, 10, 25, 10, 31),
        programId: programA,
        workoutTemplateId: push2,
        workoutSessionId: session.id,
      ),
    );
    await sessionRepository.completeWorkoutSession(
      sessionId: session.id,
      totalVolume: 360,
    );

    await cubit.loadHistory(push1);

    final loaded = cubit.state as WorkoutHistoryLoaded;
    final savedSets = loaded.setsBySessionId[session.id]!;
    expect(savedSets, hasLength(1));
    expect(savedSets.single.exerciseName, 'Bench Press');
    expect(savedSets.single.notes, 'Keep elbows tucked');
  });

  test(
    'cancelled sessions are excluded and completed history stays newest first',
    () async {
      final s1 = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );
      await sessionRepository.completeWorkoutSession(
        sessionId: s1.id,
        totalVolume: 480,
      );

      final s2 = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );
      await sessionRepository.cancelWorkoutSession(s2.id);

      await cubit.loadHistory(push1);
      final state = cubit.state as WorkoutHistoryLoaded;

      expect(state.sessions, hasLength(1));
      expect(state.sessions.single.id, equals(s1.id));
      expect(state.sessions.single.isCompleted, isTrue);
    },
  );

  test(
    'Push 1 and Push 2 histories never mix, even under the same program',
    () async {
      final push1Session = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );
      await sessionRepository.completeWorkoutSession(
        sessionId: push1Session.id,
        totalVolume: 100,
      );

      await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push2,
        workoutNameSnapshot: 'Push 2',
      );

      await cubit.loadHistory(push1);
      final state = cubit.state as WorkoutHistoryLoaded;

      expect(state.sessions, hasLength(1));
      expect(state.sessions.single.workoutTemplateId, equals(push1));
    },
  );

  test('Stage 4: a real repository failure (unauthenticated uid) maps to '
      'its exact known-safe message via the shared generic mapper — '
      'previously this Cubit showed error.toString() unmodified (with '
      'the raw "Exception: " wrapper still attached), now it matches the '
      'other Cubits\' already-correct stripped behavior', () async {
    final unauthenticatedRepository = WorkoutSessionRepository(
      remoteDataSource: _FakeWorkoutSessionRemoteDataSource(),
      storageManager: UserStorageManager(),
      uidOverride: () => '',
    );
    final unauthenticatedCubit = WorkoutHistoryCubit(
      sessionRepository: unauthenticatedRepository,
      setRepository: SessionExerciseRepository(
        remoteDataSource: _FakeWorkoutRemoteDataSource(),
        storageManager: UserStorageManager(),
        uidOverride: () => '',
      ),
    );

    await unauthenticatedCubit.loadHistory(push1);

    expect(unauthenticatedCubit.state, isA<WorkoutHistoryError>());
    expect(
      (unauthenticatedCubit.state as WorkoutHistoryError).message,
      equals('User not authenticated'),
    );

    await unauthenticatedCubit.close();
  });
}
