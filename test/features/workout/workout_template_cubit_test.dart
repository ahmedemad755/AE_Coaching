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
import 'package:ae_coaching/features/workout/presentation/cubit/workout_template_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeWorkoutTemplateRemoteDataSource implements WorkoutTemplateRemoteDataSource {
  final Map<String, Map<String, dynamic>> store = {};

  @override
  Future<void> syncTemplate(String id, WorkoutTemplate template) async {
    store[id] = template.toJson();
  }

  @override
  Future<void> deleteTemplate(String id) async {
    store.remove(id);
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteTemplates() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

class _FakeWorkoutProgramRemoteDataSource implements WorkoutProgramRemoteDataSource {
  @override
  Future<void> syncProgram(String id, WorkoutProgram program) async {}
  @override
  Future<void> deleteProgram(String id) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemotePrograms() async => const [];
}

class _FakeWorkoutSessionRemoteDataSource implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}
  @override
  Future<void> deleteSession(String id) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSessions() async => const [];
}

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

void main() {
  late Directory tempDir;
  late WorkoutTemplateCubit cubit;
  late WorkoutTemplateRepository templateRepository;
  late WorkoutSessionRepository sessionRepository;
  late SessionExerciseRepository setRepository;

  const programA = 'program_A';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('workout_template_cubit_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ExerciseSetAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WorkoutProgramAdapter());
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

    cubit = WorkoutTemplateCubit(
      repository: templateRepository,
      deletionService: WorkoutCascadeDeletionService(
        programRepository: WorkoutProgramRepository(
          remoteDataSource: _FakeWorkoutProgramRemoteDataSource(),
          uidOverride: () => 'test-uid',
        ),
        templateRepository: templateRepository,
        sessionRepository: sessionRepository,
        setRepository: setRepository,
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

  test('loadTemplates transitions to Loaded with an empty box when nothing exists yet', () async {
    await cubit.loadTemplates();
    expect(cubit.state, isA<WorkoutTemplateLoaded>());
    expect((cubit.state as WorkoutTemplateLoaded).box.values, isEmpty);
  });

  test('createTemplate appends new templates in creation order via orderIndex', () async {
    await cubit.loadTemplates();
    await cubit.createTemplate(programId: programA, name: 'Push 1');
    await cubit.createTemplate(programId: programA, name: 'Pull 1');
    await cubit.createTemplate(programId: programA, name: 'Legs');

    final box = (cubit.state as WorkoutTemplateLoaded).box;
    final ordered = cubit.repository.getTemplatesForProgram(box, programA);

    expect(ordered.map((t) => t.name).toList(), equals(['Push 1', 'Pull 1', 'Legs']));
  });

  test('renameTemplate updates only the name', () async {
    await cubit.loadTemplates();
    await cubit.createTemplate(programId: programA, name: 'Push 1');
    final box = (cubit.state as WorkoutTemplateLoaded).box;
    final template = box.values.first;

    await cubit.renameTemplate(templateId: template.id, newName: 'Push A');

    final renamed = box.get(template.id);
    expect(renamed!.name, equals('Push A'));
    expect(renamed.programId, equals(programA));
    expect(renamed.id, equals(template.id));
  });

  test('archiveTemplate removes it from the normal ordered list but keeps the record', () async {
    await cubit.loadTemplates();
    await cubit.createTemplate(programId: programA, name: 'Push 1');
    final box = (cubit.state as WorkoutTemplateLoaded).box;
    final template = box.values.first;

    await cubit.archiveTemplate(template.id);

    expect(box.get(template.id), isNotNull);
    expect(box.get(template.id)!.isArchived, isTrue);
    expect(cubit.repository.getTemplatesForProgram(box, programA), isEmpty);
  });

  test('reorderTemplates re-sequences orderIndex to match the given order', () async {
    await cubit.loadTemplates();
    await cubit.createTemplate(programId: programA, name: 'Push 1');
    await cubit.createTemplate(programId: programA, name: 'Pull 1');
    await cubit.createTemplate(programId: programA, name: 'Legs');

    final box = (cubit.state as WorkoutTemplateLoaded).box;
    final current = cubit.repository.getTemplatesForProgram(box, programA);
    // Reverse the order: Legs, Pull 1, Push 1
    final newOrder = current.reversed.map((t) => t.id).toList();

    await cubit.reorderTemplates(newOrder);

    final reOrdered = cubit.repository.getTemplatesForProgram(box, programA);
    expect(reOrdered.map((t) => t.name).toList(), equals(['Legs', 'Pull 1', 'Push 1']));
  });

  test('an error is emitted safely when renaming a template that does not exist', () async {
    await cubit.loadTemplates();
    await cubit.renameTemplate(templateId: 'does-not-exist', newName: 'X');

    expect(cubit.state, isA<WorkoutTemplateError>());
    expect((cubit.state as WorkoutTemplateError).operation, equals(WorkoutTemplateOperation.rename));
  });

  test('restoreTemplate reverses archiveTemplate — the day is visible in the active list again', () async {
    await cubit.loadTemplates();
    await cubit.createTemplate(programId: programA, name: 'Push 1');
    final box = (cubit.state as WorkoutTemplateLoaded).box;
    final template = box.values.first;

    await cubit.archiveTemplate(template.id);
    expect(cubit.repository.getTemplatesForProgram(box, programA), isEmpty);

    await cubit.restoreTemplate(template.id);

    expect(box.get(template.id)!.isArchived, isFalse);
    expect(cubit.repository.getTemplatesForProgram(box, programA).map((t) => t.id), contains(template.id));
  });

  test('deleteTemplate permanently removes the template and refreshes the loaded box', () async {
    await cubit.loadTemplates();
    await cubit.createTemplate(programId: programA, name: 'Push 1');
    final box = (cubit.state as WorkoutTemplateLoaded).box;
    final template = box.values.first;

    await cubit.deleteTemplate(template.id);

    expect(cubit.state, isA<WorkoutTemplateLoaded>());
    expect((cubit.state as WorkoutTemplateLoaded).box.get(template.id), isNull);
  });

  test('deleteTemplate cascades to its sessions and sets — nothing is left orphaned', () async {
    await cubit.loadTemplates();
    await cubit.createTemplate(programId: programA, name: 'Push 1');
    final template = (cubit.state as WorkoutTemplateLoaded).box.values.first;

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

    await cubit.deleteTemplate(template.id);

    final sessionBox = await sessionRepository.getUserBox();
    final setBox = await setRepository.getUserBox();
    expect(sessionBox.get(session.id), isNull);
    expect(setBox.values.where((s) => s.workoutSessionId == session.id), isEmpty);
  });
}
