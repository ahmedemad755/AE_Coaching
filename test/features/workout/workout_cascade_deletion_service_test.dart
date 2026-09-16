import 'dart:io';

import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_program_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_cascade_deletion_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
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
  late WorkoutProgramRepository programRepository;
  late WorkoutTemplateRepository templateRepository;
  late WorkoutSessionRepository sessionRepository;
  late SessionExerciseRepository setRepository;
  late WorkoutCascadeDeletionService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cascade_delete_test_');
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

    service = WorkoutCascadeDeletionService(
      programRepository: programRepository,
      templateRepository: templateRepository,
      sessionRepository: sessionRepository,
      setRepository: setRepository,
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('deleteTemplateCascade', () {
    test('deletes the template, its sessions, and their linked sets', () async {
      final program = await programRepository.createProgram(name: 'PPL');
      final template = await templateRepository.createTemplate(programId: program.id, name: 'Push');

      final session = await sessionRepository.startWorkoutSession(
        programId: program.id,
        workoutTemplateId: template.id,
        workoutNameSnapshot: 'Push',
      );
      await setRepository.addSet(
        programId: program.id,
        workoutTemplateId: template.id,
        workoutSessionId: session.id,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );
      await sessionRepository.completeWorkoutSession(sessionId: session.id, totalVolume: 480);

      await service.deleteTemplateCascade(template.id);

      final templateBox = await templateRepository.getUserBox();
      final sessionBox = await sessionRepository.getUserBox();
      final setBox = await setRepository.getUserBox();

      expect(templateBox.get(template.id), isNull);
      expect(sessionBox.get(session.id), isNull);
      expect(setBox.values.where((s) => s.workoutSessionId == session.id), isEmpty);
    });

    test('never touches a DIFFERENT template\'s sessions/sets (Push 1 vs Push 2)', () async {
      final program = await programRepository.createProgram(name: 'PPL');
      final push1 = await templateRepository.createTemplate(programId: program.id, name: 'Push 1');
      final push2 = await templateRepository.createTemplate(programId: program.id, name: 'Push 2');

      final push1Session = await sessionRepository.startWorkoutSession(
        programId: program.id,
        workoutTemplateId: push1.id,
        workoutNameSnapshot: 'Push 1',
      );
      await sessionRepository.completeWorkoutSession(sessionId: push1Session.id, totalVolume: 100);

      final push2Session = await sessionRepository.startWorkoutSession(
        programId: program.id,
        workoutTemplateId: push2.id,
        workoutNameSnapshot: 'Push 2',
      );
      await sessionRepository.completeWorkoutSession(sessionId: push2Session.id, totalVolume: 200);

      await service.deleteTemplateCascade(push1.id);

      final templateBox = await templateRepository.getUserBox();
      final sessionBox = await sessionRepository.getUserBox();

      expect(templateBox.get(push1.id), isNull);
      expect(templateBox.get(push2.id), isNotNull);
      expect(sessionBox.get(push1Session.id), isNull);
      expect(sessionBox.get(push2Session.id), isNotNull);
    });

    test('a template with no sessions at all is simply deleted, no error', () async {
      final program = await programRepository.createProgram(name: 'PPL');
      final template = await templateRepository.createTemplate(programId: program.id, name: 'Push');

      await service.deleteTemplateCascade(template.id);

      final templateBox = await templateRepository.getUserBox();
      expect(templateBox.get(template.id), isNull);
    });
  });

  group('deleteProgramCascade', () {
    test('deletes the program, every one of its templates (Push AND Pull), and their sessions/sets', () async {
      final program = await programRepository.createProgram(name: 'PPL');
      final push = await templateRepository.createTemplate(programId: program.id, name: 'Push');
      final pull = await templateRepository.createTemplate(programId: program.id, name: 'Pull');

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
        weight: 60,
        reps: 8,
      );
      await sessionRepository.completeWorkoutSession(sessionId: pushSession.id, totalVolume: 480);

      final pullSession = await sessionRepository.startWorkoutSession(
        programId: program.id,
        workoutTemplateId: pull.id,
        workoutNameSnapshot: 'Pull',
      );
      await sessionRepository.completeWorkoutSession(sessionId: pullSession.id, totalVolume: 300);

      await service.deleteProgramCascade(program.id);

      final programBox = await programRepository.getUserBox();
      final templateBox = await templateRepository.getUserBox();
      final sessionBox = await sessionRepository.getUserBox();
      final setBox = await setRepository.getUserBox();

      expect(programBox.get(program.id), isNull);
      expect(templateBox.get(push.id), isNull);
      expect(templateBox.get(pull.id), isNull);
      expect(sessionBox.get(pushSession.id), isNull);
      expect(sessionBox.get(pullSession.id), isNull);
      expect(setBox.values.where((s) => s.workoutSessionId == pushSession.id), isEmpty);
    });

    test('includes ARCHIVED templates in the cascade — an archived day must not survive as an orphan', () async {
      final program = await programRepository.createProgram(name: 'PPL');
      final oldTemplate = await templateRepository.createTemplate(programId: program.id, name: 'Old Day');
      await templateRepository.archiveTemplate(oldTemplate.id);

      await service.deleteProgramCascade(program.id);

      final templateBox = await templateRepository.getUserBox();
      expect(templateBox.get(oldTemplate.id), isNull);
    });

    test('never touches a DIFFERENT program\'s templates/sessions', () async {
      final programA = await programRepository.createProgram(name: 'PPL');
      final programB = await programRepository.createProgram(name: 'Other');

      final templateA = await templateRepository.createTemplate(programId: programA.id, name: 'Push');
      final templateB = await templateRepository.createTemplate(programId: programB.id, name: 'Legs');

      await service.deleteProgramCascade(programA.id);

      final programBox = await programRepository.getUserBox();
      final templateBox = await templateRepository.getUserBox();

      expect(programBox.get(programA.id), isNull);
      expect(programBox.get(programB.id), isNotNull);
      expect(templateBox.get(templateA.id), isNull);
      expect(templateBox.get(templateB.id), isNotNull);
    });

    test('a program with no templates at all is simply deleted, no error', () async {
      final program = await programRepository.createProgram(name: 'Empty');
      await service.deleteProgramCascade(program.id);

      final programBox = await programRepository.getUserBox();
      expect(programBox.get(program.id), isNull);
    });
  });
}
