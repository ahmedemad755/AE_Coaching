import 'dart:io';

import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
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
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeWorkoutProgramRemoteDataSource implements WorkoutProgramRemoteDataSource {
  final Map<String, Map<String, dynamic>> store = {};

  @override
  Future<void> syncProgram(String id, WorkoutProgram program) async {
    store[id] = program.toJson();
  }

  @override
  Future<void> deleteProgram(String id) async {
    store.remove(id);
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemotePrograms() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

class _FakeWorkoutTemplateRemoteDataSource implements WorkoutTemplateRemoteDataSource {
  @override
  Future<void> syncTemplate(String id, WorkoutTemplate template) async {}
  @override
  Future<void> deleteTemplate(String id) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteTemplates() async => const [];
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
  late WorkoutProgramCubit cubit;
  late WorkoutProgramRepository programRepository;
  late WorkoutTemplateRepository templateRepository;
  late WorkoutSessionRepository sessionRepository;
  late SessionExerciseRepository setRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('workout_program_cubit_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ExerciseSetAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WorkoutProgramAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(WorkoutTemplateAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(WorkoutSessionAdapter());

    final storageManager = UserStorageManager();
    programRepository = WorkoutProgramRepository(
      remoteDataSource: _FakeWorkoutProgramRemoteDataSource(),
      storageManager: storageManager,
      uidOverride: () => 'test-uid',
    );
    templateRepository = WorkoutTemplateRepository(
      remoteDataSource: _FakeWorkoutTemplateRemoteDataSource(),
      storageManager: storageManager,
      uidOverride: () => 'test-uid',
    );
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

    cubit = WorkoutProgramCubit(
      repository: programRepository,
      deletionService: WorkoutCascadeDeletionService(
        programRepository: programRepository,
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

  test('loadPrograms transitions to Loaded with an empty box when nothing exists yet', () async {
    await cubit.loadPrograms();

    expect(cubit.state, isA<WorkoutProgramLoaded>());
    expect((cubit.state as WorkoutProgramLoaded).box.values, isEmpty);
  });

  test('createProgram updates state — the new program appears in the loaded box', () async {
    await cubit.loadPrograms();
    await cubit.createProgram(name: 'Push Pull Legs V1');

    expect(cubit.state, isA<WorkoutProgramLoaded>());
    final box = (cubit.state as WorkoutProgramLoaded).box;
    expect(box.values.map((p) => p.name), contains('Push Pull Legs V1'));
  });

  test('making a program active refreshes the active/previous grouping', () async {
    await cubit.loadPrograms();
    await cubit.createProgram(name: 'Program A', makeActive: true);
    var box = (cubit.state as WorkoutProgramLoaded).box;
    final programA = box.values.firstWhere((p) => p.name == 'Program A');

    await cubit.createProgram(name: 'Program B', makeActive: true);
    box = (cubit.state as WorkoutProgramLoaded).box;
    final programB = box.values.firstWhere((p) => p.name == 'Program B');

    expect(box.get(programA.id)!.isActive, isFalse);
    expect(box.get(programB.id)!.isActive, isTrue);

    await cubit.setActiveProgram(programA.id);
    box = (cubit.state as WorkoutProgramLoaded).box;
    expect(box.get(programA.id)!.isActive, isTrue);
    expect(box.get(programB.id)!.isActive, isFalse);
  });

  test('archiving keeps the program visible (as previous), never deleted', () async {
    await cubit.loadPrograms();
    await cubit.createProgram(name: 'Program A', makeActive: true);
    var box = (cubit.state as WorkoutProgramLoaded).box;
    final programA = box.values.first;

    await cubit.archiveProgram(programA.id);
    box = (cubit.state as WorkoutProgramLoaded).box;

    final archived = box.get(programA.id);
    expect(archived, isNotNull);
    expect(archived!.isActive, isFalse);
    expect(archived.endedAt, isNotNull);
  });

  test('renameProgram updates only the displayed name', () async {
    await cubit.loadPrograms();
    await cubit.createProgram(name: 'Old Name');
    var box = (cubit.state as WorkoutProgramLoaded).box;
    final program = box.values.first;
    final originalId = program.id;
    final originalCreatedAt = program.createdAt;

    await cubit.renameProgram(programId: program.id, newName: 'New Name');
    box = (cubit.state as WorkoutProgramLoaded).box;
    final renamed = box.get(originalId);

    expect(renamed!.name, equals('New Name'));
    expect(renamed.id, equals(originalId));
    expect(renamed.createdAt, equals(originalCreatedAt));
  });

  test('an error is emitted safely (not thrown) when renaming a program that does not exist', () async {
    await cubit.loadPrograms();

    await cubit.renameProgram(programId: 'does-not-exist', newName: 'X');

    expect(cubit.state, isA<WorkoutProgramError>());
    expect((cubit.state as WorkoutProgramError).operation, equals(WorkoutProgramOperation.rename));
  });

  test('deleteProgram permanently removes the program and refreshes the loaded box', () async {
    await cubit.loadPrograms();
    await cubit.createProgram(name: 'Program A');
    final box = (cubit.state as WorkoutProgramLoaded).box;
    final program = box.values.first;

    await cubit.deleteProgram(program.id);

    expect(cubit.state, isA<WorkoutProgramLoaded>());
    expect((cubit.state as WorkoutProgramLoaded).box.get(program.id), isNull);
  });

  test('deleteProgram cascades to its templates, sessions, and sets — nothing is left orphaned', () async {
    await cubit.loadPrograms();
    await cubit.createProgram(name: 'PPL');
    final program = (cubit.state as WorkoutProgramLoaded).box.values.first;

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

    await cubit.deleteProgram(program.id);

    final templateBox = await templateRepository.getUserBox();
    final sessionBox = await sessionRepository.getUserBox();
    final setBox = await setRepository.getUserBox();

    expect(templateBox.get(template.id), isNull);
    expect(sessionBox.get(session.id), isNull);
    expect(setBox.values.where((s) => s.workoutSessionId == session.id), isEmpty);
  });
}
