import 'dart:io';

import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_analytics_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeWorkoutRemoteDataSource implements WorkoutRemoteDataSource {
  @override
  Future<void> syncSet(String key, ExerciseSet set) async {}
  @override
  Future<void> deleteSet(String key) async {}
  @override
  Future<void> deleteMultipleSets(List<String> keys) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSets() async => const [];
}

class _FakeWorkoutSessionRemoteDataSource implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}
  @override
  Future<void> deleteSession(String id) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSessions() async => const [];
}

class _FakeWorkoutTemplateRemoteDataSource implements WorkoutTemplateRemoteDataSource {
  @override
  Future<void> syncTemplate(String id, WorkoutTemplate template) async {}
  @override
  Future<void> deleteTemplate(String id) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteTemplates() async => const [];
}

void main() {
  late Directory tempDir;
  late ProgramAnalyticsCubit cubit;
  late WorkoutTemplateRepository templateRepository;
  late WorkoutSessionRepository sessionRepository;
  late SessionExerciseRepository setRepository;

  const programA = 'program_A';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('program_analytics_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ExerciseSetAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(WorkoutTemplateAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(WorkoutSessionAdapter());

    templateRepository = WorkoutTemplateRepository(
      remoteDataSource: _FakeWorkoutTemplateRemoteDataSource(),
      uidOverride: () => 'test-uid',
    );
    sessionRepository = WorkoutSessionRepository(
      remoteDataSource: _FakeWorkoutSessionRemoteDataSource(),
      uidOverride: () => 'test-uid',
    );
    setRepository = SessionExerciseRepository(
      remoteDataSource: _FakeWorkoutRemoteDataSource(),
      uidOverride: () => 'test-uid',
    );
    cubit = ProgramAnalyticsCubit(
      templateRepository: templateRepository,
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

  test('a program with no templates yet loads an empty day list', () async {
    await cubit.loadAnalytics(programA);

    final state = cubit.state as ProgramAnalyticsLoaded;
    expect(state.summary.days, isEmpty);
  });

  test('builds a full Program -> Day -> Exercise summary from real stored data', () async {
    final template = await templateRepository.createTemplate(programId: programA, name: 'Push 1');

    final session = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: template.id,
      workoutNameSnapshot: 'Push 1',
    );
    await setRepository.addSet(
      programId: programA,
      workoutTemplateId: template.id,
      workoutSessionId: session.id,
      exerciseName: 'Bench Press',
      weight: 60,
      reps: 8,
    );
    await sessionRepository.completeWorkoutSession(sessionId: session.id, totalVolume: 480);

    await cubit.loadAnalytics(programA);

    final state = cubit.state as ProgramAnalyticsLoaded;
    expect(state.summary.days, hasLength(1));
    final day = state.summary.days.single;
    expect(day.workoutTemplateId, equals(template.id));
    expect(day.completedSessionsCount, equals(1));
    expect(day.exercises.single.exerciseName, equals('Bench Press'));
    expect(day.exercises.single.bestWeight, equals(60));
  });

  test('an archived template is excluded, matching the Workout Days screen', () async {
    final template = await templateRepository.createTemplate(programId: programA, name: 'Push 1');
    await templateRepository.archiveTemplate(template.id);

    await cubit.loadAnalytics(programA);

    final state = cubit.state as ProgramAnalyticsLoaded;
    expect(state.summary.days, isEmpty);
  });
}
