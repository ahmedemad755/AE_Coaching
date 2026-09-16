import 'dart:io';

import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_consistency_cubit.dart';
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
  late ProgramConsistencyCubit cubit;
  late WorkoutSessionRepository sessionRepository;

  const programA = 'program_A';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('program_consistency_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ExerciseSetAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(WorkoutSessionAdapter());

    sessionRepository = WorkoutSessionRepository(
      remoteDataSource: _FakeWorkoutSessionRemoteDataSource(),
      uidOverride: () => 'test-uid',
    );
    cubit = ProgramConsistencyCubit(sessionRepository: sessionRepository);
  });

  tearDown(() async {
    await cubit.close();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('a program with no completed sessions loads the empty summary', () async {
    await cubit.loadConsistency(programA);

    final state = cubit.state as ProgramConsistencyLoaded;
    expect(state.summary.totalCompletedSessions, equals(0));
  });

  test('completed sessions from DIFFERENT templates in the same program both count', () async {
    final push1 = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: 'template_push1',
      workoutNameSnapshot: 'Push 1',
    );
    await sessionRepository.completeWorkoutSession(sessionId: push1.id, totalVolume: 480);

    final pull1 = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: 'template_pull1',
      workoutNameSnapshot: 'Pull 1',
    );
    await sessionRepository.completeWorkoutSession(sessionId: pull1.id, totalVolume: 300);

    await cubit.loadConsistency(programA);

    final state = cubit.state as ProgramConsistencyLoaded;
    expect(state.summary.totalCompletedSessions, equals(2));
  });

  test('a session from a DIFFERENT program is never counted', () async {
    final ownSession = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: 'template_push1',
      workoutNameSnapshot: 'Push 1',
    );
    await sessionRepository.completeWorkoutSession(sessionId: ownSession.id, totalVolume: 480);

    final otherSession = await sessionRepository.startWorkoutSession(
      programId: 'program_B',
      workoutTemplateId: 'template_other',
      workoutNameSnapshot: 'Other',
    );
    await sessionRepository.completeWorkoutSession(sessionId: otherSession.id, totalVolume: 999);

    await cubit.loadConsistency(programA);

    final state = cubit.state as ProgramConsistencyLoaded;
    expect(state.summary.totalCompletedSessions, equals(1));
  });

  test('a cancelled session is never counted', () async {
    final session = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: 'template_push1',
      workoutNameSnapshot: 'Push 1',
    );
    await sessionRepository.cancelWorkoutSession(session.id);

    await cubit.loadConsistency(programA);

    final state = cubit.state as ProgramConsistencyLoaded;
    expect(state.summary.totalCompletedSessions, equals(0));
  });
}
