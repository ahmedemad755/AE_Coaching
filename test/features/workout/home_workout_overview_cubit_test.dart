import 'dart:io';

import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_program_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/home_workout_overview_cubit.dart';
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

class _FakeWorkoutProgramRemoteDataSource implements WorkoutProgramRemoteDataSource {
  @override
  Future<void> syncProgram(String id, WorkoutProgram program) async {}
  @override
  Future<void> deleteProgram(String id) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemotePrograms() async => const [];
}

void main() {
  late Directory tempDir;
  late HomeWorkoutOverviewCubit cubit;
  late WorkoutProgramRepository programRepository;
  late WorkoutTemplateRepository templateRepository;
  late WorkoutSessionRepository sessionRepository;
  late SessionExerciseRepository setRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('home_overview_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ExerciseSetAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WorkoutProgramAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(WorkoutTemplateAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(WorkoutSessionAdapter());

    programRepository = WorkoutProgramRepository(
      remoteDataSource: _FakeWorkoutProgramRemoteDataSource(),
      uidOverride: () => 'test-uid',
    );
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

    cubit = HomeWorkoutOverviewCubit(
      sessionRepository: sessionRepository,
      programRepository: programRepository,
      templateRepository: templateRepository,
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

  test('no active program and no completed workouts: both empty states load correctly', () async {
    await cubit.loadOverview();

    final state = cubit.state as HomeWorkoutOverviewLoaded;
    expect(state.overview.activeSession, isNull);
    expect(state.overview.activeProgram, isNull);
    expect(state.overview.recentSessions, isEmpty);
  });

  test('an in-progress session takes priority and is surfaced regardless of completed history', () async {
    final program = await programRepository.createProgram(name: 'PPL', makeActive: true);
    final push = await templateRepository.createTemplate(programId: program.id, name: 'Push');
    final pull = await templateRepository.createTemplate(programId: program.id, name: 'Pull');

    // An older completed Pull session...
    final pullSession = await sessionRepository.startWorkoutSession(
      programId: program.id,
      workoutTemplateId: pull.id,
      workoutNameSnapshot: 'Pull',
    );
    await sessionRepository.completeWorkoutSession(sessionId: pullSession.id, totalVolume: 5110);

    // ...then a currently in-progress Push session.
    final activePush = await sessionRepository.startWorkoutSession(
      programId: program.id,
      workoutTemplateId: push.id,
      workoutNameSnapshot: 'Push',
    );

    await cubit.loadOverview();

    final state = cubit.state as HomeWorkoutOverviewLoaded;
    expect(state.overview.activeSession?.id, equals(activePush.id));
    expect(state.overview.activeSession?.workoutNameSnapshot, equals('Push'));
  });

  test('Push and Pull completed sessions stay separate, newest first, with correct per-session counts', () async {
    final program = await programRepository.createProgram(name: 'PPL', makeActive: true);
    final push = await templateRepository.createTemplate(programId: program.id, name: 'Push');
    final pull = await templateRepository.createTemplate(programId: program.id, name: 'Pull');

    final pullSession = await sessionRepository.startWorkoutSession(
      programId: program.id,
      workoutTemplateId: pull.id,
      workoutNameSnapshot: 'Pull',
    );
    await setRepository.addSet(
      programId: program.id,
      workoutTemplateId: pull.id,
      workoutSessionId: pullSession.id,
      exerciseName: 'Lat Pulldown',
      weight: 60,
      reps: 10,
    );
    await sessionRepository.completeWorkoutSession(sessionId: pullSession.id, totalVolume: 5110);

    final pushSession = await sessionRepository.startWorkoutSession(
      programId: program.id,
      workoutTemplateId: push.id,
      workoutNameSnapshot: 'Push',
    );
    await setRepository.addSet(
      programId: program.id,
      workoutTemplateId: push.id,
      workoutSessionId: pushSession.id,
      exerciseName: 'Bench Press',
      weight: 80,
      reps: 8,
    );
    await setRepository.addSet(
      programId: program.id,
      workoutTemplateId: push.id,
      workoutSessionId: pushSession.id,
      exerciseName: 'Incline Press',
      weight: 60,
      reps: 8,
    );
    await sessionRepository.completeWorkoutSession(sessionId: pushSession.id, totalVolume: 4820);

    await cubit.loadOverview();

    final state = cubit.state as HomeWorkoutOverviewLoaded;
    expect(state.overview.recentSessions, hasLength(2));

    // Newest first — Push was completed after Pull.
    final newest = state.overview.recentSessions.first;
    final oldest = state.overview.recentSessions.last;
    expect(newest.session.workoutNameSnapshot, equals('Push'));
    expect(newest.exerciseCount, equals(2));
    expect(newest.setCount, equals(2));
    expect(newest.session.totalVolume, equals(4820));
    expect(newest.template?.name, equals('Push'));

    expect(oldest.session.workoutNameSnapshot, equals('Pull'));
    expect(oldest.exerciseCount, equals(1));
    expect(oldest.setCount, equals(1));
    expect(oldest.session.totalVolume, equals(5110));
  });

  test('a legacy (unlinked) ExerciseSet never appears as a recent session or affects counts', () async {
    // A pre-Phase-4 legacy set with no session/program/template link.
    final setBox = await setRepository.getUserBox();
    await setBox.add(ExerciseSet(exerciseName: 'Old Bench', weight: 50, reps: 10, date: DateTime(2020, 1, 1)));

    final program = await programRepository.createProgram(name: 'PPL', makeActive: true);
    final push = await templateRepository.createTemplate(programId: program.id, name: 'Push');
    final session = await sessionRepository.startWorkoutSession(
      programId: program.id,
      workoutTemplateId: push.id,
      workoutNameSnapshot: 'Push',
    );
    await setRepository.addSet(
      programId: program.id,
      workoutTemplateId: push.id,
      workoutSessionId: session.id,
      exerciseName: 'Bench Press',
      weight: 80,
      reps: 8,
    );
    await sessionRepository.completeWorkoutSession(sessionId: session.id, totalVolume: 640);

    await cubit.loadOverview();

    final state = cubit.state as HomeWorkoutOverviewLoaded;
    expect(state.overview.recentSessions, hasLength(1));
    expect(state.overview.recentSessions.single.exerciseCount, equals(1));
    expect(state.overview.recentSessions.single.exerciseNames, equals(['Bench Press']));
  });

  test('the active program summary reflects a real "this week" count, scoped to that program only', () async {
    final activeProgram = await programRepository.createProgram(name: 'PPL', makeActive: true);
    final otherProgram = await programRepository.createProgram(name: 'Old Split');

    final push = await templateRepository.createTemplate(programId: activeProgram.id, name: 'Push');
    final pushSession = await sessionRepository.startWorkoutSession(
      programId: activeProgram.id,
      workoutTemplateId: push.id,
      workoutNameSnapshot: 'Push',
    );
    await sessionRepository.completeWorkoutSession(sessionId: pushSession.id, totalVolume: 100);

    final otherTemplate = await templateRepository.createTemplate(programId: otherProgram.id, name: 'Legs');
    final otherSession = await sessionRepository.startWorkoutSession(
      programId: otherProgram.id,
      workoutTemplateId: otherTemplate.id,
      workoutNameSnapshot: 'Legs',
    );
    await sessionRepository.completeWorkoutSession(sessionId: otherSession.id, totalVolume: 999);

    await cubit.loadOverview();

    final state = cubit.state as HomeWorkoutOverviewLoaded;
    expect(state.overview.activeProgram?.program.id, equals(activeProgram.id));
    // Only the ACTIVE program's own session counts toward its "this
    // week" figure — the other program's session must not leak in.
    expect(state.overview.activeProgram?.sessionsCompletedThisWeek, equals(1));
  });
}
