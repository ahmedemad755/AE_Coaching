import 'dart:io';

import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_history_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeWorkoutSessionRemoteDataSource implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}
  @override
  Future<void> deleteSession(String id) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSessions() async => const [];
}

void main() {
  late Directory tempDir;
  late WorkoutHistoryCubit cubit;
  late WorkoutSessionRepository sessionRepository;

  const programA = 'program_A';
  const push1 = 'template_push1';
  const push2 = 'template_push2';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('workout_history_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ExerciseSetAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(WorkoutSessionAdapter());

    sessionRepository = WorkoutSessionRepository(
      remoteDataSource: _FakeWorkoutSessionRemoteDataSource(),
      storageManager: UserStorageManager(),
      uidOverride: () => 'test-uid',
    );
    cubit = WorkoutHistoryCubit(sessionRepository: sessionRepository);
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

  test('sessions are returned newest first, regardless of status', () async {
    final s1 = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    await sessionRepository.completeWorkoutSession(sessionId: s1.id, totalVolume: 480);

    final s2 = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    await sessionRepository.cancelWorkoutSession(s2.id);

    await cubit.loadHistory(push1);
    final state = cubit.state as WorkoutHistoryLoaded;

    expect(state.sessions, hasLength(2));
    expect(state.sessions.first.id, equals(s2.id)); // most recently started, first
    expect(state.sessions.first.isCancelled, isTrue);
    expect(state.sessions.last.isCompleted, isTrue);
  });

  test('Push 1 and Push 2 histories never mix, even under the same program', () async {
    final push1Session = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    await sessionRepository.completeWorkoutSession(sessionId: push1Session.id, totalVolume: 100);

    await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push2,
      workoutNameSnapshot: 'Push 2',
    );

    await cubit.loadHistory(push1);
    final state = cubit.state as WorkoutHistoryLoaded;

    expect(state.sessions, hasLength(1));
    expect(state.sessions.single.workoutTemplateId, equals(push1));
  });
}
