import 'dart:io';

import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_overview_cubit.dart';
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
  late ProgramOverviewCubit cubit;
  late WorkoutTemplateRepository templateRepository;
  late WorkoutSessionRepository sessionRepository;

  const programA = 'program_A';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('program_overview_test_');
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
    cubit = ProgramOverviewCubit(templateRepository: templateRepository, sessionRepository: sessionRepository);
  });

  tearDown(() async {
    await cubit.close();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('a program with no templates loads an empty overview', () async {
    await cubit.loadOverview(programA);

    final state = cubit.state as ProgramOverviewLoaded;
    expect(state.overview.templates, isEmpty);
    expect(state.overview.totalSessionsThisWeek, equals(0));
  });

  test('a session completed today (this week) is reflected in the real overview', () async {
    final template = await templateRepository.createTemplate(programId: programA, name: 'Push 1');
    final session = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: template.id,
      workoutNameSnapshot: 'Push 1',
    );
    await sessionRepository.completeWorkoutSession(sessionId: session.id, totalVolume: 480);

    await cubit.loadOverview(programA);

    final state = cubit.state as ProgramOverviewLoaded;
    expect(state.overview.templates, hasLength(1));
    expect(state.overview.templates.single.sessionsThisWeek, equals(1));
    expect(state.overview.totalSessionsThisWeek, equals(1));
  });

  test('a cancelled session never counts toward this week\'s total', () async {
    final template = await templateRepository.createTemplate(programId: programA, name: 'Push 1');
    final session = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: template.id,
      workoutNameSnapshot: 'Push 1',
    );
    await sessionRepository.cancelWorkoutSession(session.id);

    await cubit.loadOverview(programA);

    final state = cubit.state as ProgramOverviewLoaded;
    expect(state.overview.templates.single.sessionsThisWeek, equals(0));
  });
}
