import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Hand-rolled in-memory fake — no mocking package, same pattern as
/// workout_program_repository_test.dart.
class _FakeWorkoutTemplateRemoteDataSource
    implements WorkoutTemplateRemoteDataSource {
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
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteTemplates() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

void main() {
  late Directory tempDir;
  late WorkoutTemplateRepository repository;
  late UserStorageManager storageManager;

  const programA = 'program_A';
  const programB = 'program_B';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('workout_template_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ExerciseSetAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(WorkoutTemplateAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
    }

    storageManager = UserStorageManager();
    repository = WorkoutTemplateRepository(
      remoteDataSource: _FakeWorkoutTemplateRemoteDataSource(),
      storageManager: storageManager,
      uidOverride: () => 'test-uid',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('createTemplate stores the template under the given program', () async {
    final template = await repository.createTemplate(
      programId: programA,
      name: 'Push 1',
    );

    final box = await repository.getUserBox();
    final stored = box.get(template.id);

    expect(stored, isNotNull);
    expect(stored!.programId, equals(programA));
    expect(stored.name, equals('Push 1'));
    expect(stored.isArchived, isFalse);
  });

  test(
    'assignments support built-in/custom references, order, and duplicates',
    () async {
      final template = await repository.createTemplate(
        programId: programA,
        name: 'Push A',
      );
      final builtIn = await repository.addExerciseAssignment(
        templateId: template.id,
        exerciseId: 'ex_bench_press',
        exerciseNameSnapshot: 'Bench Press',
        referenceType: WorkoutExerciseReferenceType.builtIn,
      );
      final custom = await repository.addExerciseAssignment(
        templateId: template.id,
        exerciseId: 'custom_exercise_1',
        exerciseNameSnapshot: 'Single Arm Row',
        referenceType: WorkoutExerciseReferenceType.custom,
      );

      await expectLater(
        repository.addExerciseAssignment(
          templateId: template.id,
          exerciseId: 'other_id',
          exerciseNameSnapshot: ' bench   press ',
          referenceType: WorkoutExerciseReferenceType.builtIn,
        ),
        throwsA(isA<DuplicateTemplateExerciseException>()),
      );

      final reordered = await repository.reorderExerciseAssignments(
        templateId: template.id,
        orderedAssignmentIds: [
          custom.exerciseAssignments.last.assignmentId,
          builtIn.exerciseAssignments.first.assignmentId,
        ],
      );
      expect(
        reordered.exerciseAssignments.map(
          (assignment) => assignment.exerciseId,
        ),
        ['custom_exercise_1', 'ex_bench_press'],
      );
      expect(
        reordered.exerciseAssignments.first.referenceTypeValue,
        WorkoutExerciseReferenceType.custom,
      );
    },
  );

  test(
    'picker batch addition preserves order and rejects duplicates',
    () async {
      final template = await repository.createTemplate(
        programId: programA,
        name: 'Push A',
      );
      const selected = [
        ExerciseLibraryItem(
          id: 'bench',
          nameEn: 'Bench Press',
          nameAr: 'بنش',
          muscleGroup: 'chest',
          equipment: 'barbell',
          source: ExerciseLibraryItemSource.builtIn,
        ),
        ExerciseLibraryItem(
          id: 'custom-row',
          nameEn: 'My Row',
          muscleGroup: null,
          equipment: null,
          source: ExerciseLibraryItemSource.custom,
        ),
      ];
      final updated = await repository.addExerciseAssignments(
        templateId: template.id,
        exercises: selected,
        languageCode: 'en',
      );
      expect(updated.exerciseAssignments.map((item) => item.exerciseId), [
        'bench',
        'custom-row',
      ]);
      expect(updated.exerciseAssignments.last.referenceType, 'custom');
      await expectLater(
        repository.addExerciseAssignments(
          templateId: template.id,
          exercises: [selected.first],
          languageCode: 'en',
        ),
        throwsA(isA<DuplicateTemplateExerciseException>()),
      );
    },
  );

  test('concurrent picker batches do not overwrite one another', () async {
    final template = await repository.createTemplate(
      programId: programA,
      name: 'Push A',
    );
    const bench = ExerciseLibraryItem(
      id: 'bench',
      nameEn: 'Bench Press',
      nameAr: 'بنش',
      muscleGroup: 'chest',
      equipment: 'barbell',
      source: ExerciseLibraryItemSource.builtIn,
    );
    const row = ExerciseLibraryItem(
      id: 'row',
      nameEn: 'Cable Row',
      nameAr: 'سحب',
      muscleGroup: 'back',
      equipment: 'cable',
      source: ExerciseLibraryItemSource.builtIn,
    );

    await Future.wait([
      repository.addExerciseAssignments(
        templateId: template.id,
        exercises: [bench],
        languageCode: 'en',
      ),
      repository.addExerciseAssignments(
        templateId: template.id,
        exercises: [row],
        languageCode: 'en',
      ),
    ]);

    final stored = (await repository.getUserBox()).get(template.id)!;
    expect(stored.exerciseAssignments.map((item) => item.exerciseId).toSet(), {
      'bench',
      'row',
    });
  });

  test('replacement preserves assignment identity and ordering', () async {
    final template = await repository.createTemplate(
      programId: programA,
      name: 'Push A',
    );
    final first = await repository.addExerciseAssignment(
      templateId: template.id,
      exerciseId: 'bench',
      exerciseNameSnapshot: 'Bench Press',
      referenceType: WorkoutExerciseReferenceType.builtIn,
    );
    await repository.addExerciseAssignment(
      templateId: template.id,
      exerciseId: 'row',
      exerciseNameSnapshot: 'Cable Row',
      referenceType: WorkoutExerciseReferenceType.builtIn,
    );
    const replacement = ExerciseLibraryItem(
      id: 'custom-incline',
      nameEn: 'Incline Press',
      nameAr: 'ضغط مائل',
      source: ExerciseLibraryItemSource.custom,
    );

    final updated = await repository.replaceExerciseAssignment(
      templateId: template.id,
      assignmentId: first.exerciseAssignments.first.assignmentId,
      exercise: replacement,
      languageCode: 'en',
    );

    expect(updated.exerciseAssignments.map((item) => item.exerciseId), [
      'custom-incline',
      'row',
    ]);
    expect(
      updated.exerciseAssignments.first.assignmentId,
      first.exerciseAssignments.first.assignmentId,
    );
    expect(
      updated.exerciseAssignments.first.referenceTypeValue,
      WorkoutExerciseReferenceType.custom,
    );
  });

  test('assignments persist after closing storage and reopening', () async {
    final template = await repository.createTemplate(
      programId: programA,
      name: 'Pull A',
    );
    final assigned = await repository.addExerciseAssignment(
      templateId: template.id,
      exerciseId: 'ex_row',
      exerciseNameSnapshot: 'Cable Row',
      referenceType: WorkoutExerciseReferenceType.builtIn,
    );

    await storageManager.closeForUser('test-uid');
    storageManager = UserStorageManager();
    repository = WorkoutTemplateRepository(
      remoteDataSource: _FakeWorkoutTemplateRemoteDataSource(),
      storageManager: storageManager,
      uidOverride: () => 'test-uid',
    );
    final box = await repository.getUserBox();
    final restored = box.get(template.id)!;

    expect(
      restored.exerciseAssignments.single.assignmentId,
      assigned.exerciseAssignments.single.assignmentId,
    );
    expect(
      restored.exerciseAssignments.single.exerciseNameSnapshot,
      'Cable Row',
    );
    expect(restored.exerciseAssignments.single.exerciseId, 'ex_row');
  });

  test('assignment lists stay scoped to their template and program', () async {
    final push = await repository.createTemplate(
      programId: programA,
      name: 'Push',
    );
    final pull = await repository.createTemplate(
      programId: programA,
      name: 'Pull',
    );
    final otherProgram = await repository.createTemplate(
      programId: programB,
      name: 'Push',
    );
    await repository.addExerciseAssignment(
      templateId: push.id,
      exerciseId: 'ex_press',
      exerciseNameSnapshot: 'Press',
      referenceType: WorkoutExerciseReferenceType.builtIn,
    );

    final box = await repository.getUserBox();
    expect(box.get(push.id)!.exerciseAssignments, hasLength(1));
    expect(box.get(pull.id)!.exerciseAssignments, isEmpty);
    expect(box.get(otherProgram.id)!.exerciseAssignments, isEmpty);
  });

  test(
    'removing a template assignment leaves historical sets untouched',
    () async {
      final template = await repository.createTemplate(
        programId: programA,
        name: 'Push A',
      );
      final assignment = await repository.addExerciseAssignment(
        templateId: template.id,
        exerciseId: 'ex_press',
        exerciseNameSnapshot: 'Press',
        referenceType: WorkoutExerciseReferenceType.builtIn,
      );
      final setBox = await storageManager.getUserBox<ExerciseSet>(
        'sets',
        'test-uid',
      );
      await setBox.add(
        ExerciseSet(
          exerciseName: 'Press',
          weight: 50,
          reps: 8,
          date: DateTime(2025),
          programId: programA,
          workoutTemplateId: template.id,
          workoutSessionId: 'completed-session',
        ),
      );

      await repository.removeExerciseAssignment(
        templateId: template.id,
        assignmentId: assignment.exerciseAssignments.single.assignmentId,
      );

      expect(setBox.values, hasLength(1));
      expect(setBox.values.single.exerciseName, 'Press');
      expect(setBox.values.single.workoutSessionId, 'completed-session');
    },
  );

  test('legacy JSON templates load with no assignments', () {
    final legacy = WorkoutTemplate.fromJson({
      'id': 'legacy',
      'programId': programA,
      'name': 'Legacy day',
      'createdAt': DateTime(2024).toIso8601String(),
    });
    expect(legacy.exerciseAssignments, isEmpty);
  });

  test('getTemplatesForProgram returns only that program\'s templates — '
      'Program B templates never leak into Program A\'s list', () async {
    await repository.createTemplate(programId: programA, name: 'Push 1');
    await repository.createTemplate(programId: programA, name: 'Pull 1');
    await repository.createTemplate(programId: programB, name: 'Full Body A');

    final box = await repository.getUserBox();

    final aTemplates = repository.getTemplatesForProgram(box, programA);
    final bTemplates = repository.getTemplatesForProgram(box, programB);

    expect(aTemplates, hasLength(2));
    expect(aTemplates.map((t) => t.name), containsAll(['Push 1', 'Pull 1']));
    expect(aTemplates.every((t) => t.programId == programA), isTrue);

    expect(bTemplates, hasLength(1));
    expect(bTemplates.single.name, equals('Full Body A'));

    // Explicit cross-contamination guard.
    expect(aTemplates.any((t) => t.programId == programB), isFalse);
    expect(bTemplates.any((t) => t.programId == programA), isFalse);
  });

  test(
    'archiving a template keeps its record but removes it from the '
    'normal (active) list, while still being visible with includeArchived',
    () async {
      final template = await repository.createTemplate(
        programId: programA,
        name: 'Legs',
      );

      await repository.archiveTemplate(template.id);

      final box = await repository.getUserBox();

      // Still exists as a record.
      final stored = box.get(template.id);
      expect(stored, isNotNull);
      expect(stored!.isArchived, isTrue);

      // Excluded from the normal active list.
      final activeOnly = repository.getTemplatesForProgram(box, programA);
      expect(activeOnly, isEmpty);

      // Still retrievable when explicitly asked for.
      final withArchived = repository.getTemplatesForProgram(
        box,
        programA,
        includeArchived: true,
      );
      expect(withArchived, hasLength(1));
      expect(withArchived.single.id, equals(template.id));
    },
  );

  test(
    'restoreTemplate reverses archiveTemplate, bringing it back into the active list',
    () async {
      final template = await repository.createTemplate(
        programId: programA,
        name: 'Legs',
      );
      await repository.archiveTemplate(template.id);

      await repository.restoreTemplate(template.id);

      final box = await repository.getUserBox();
      final stored = box.get(template.id);
      expect(stored!.isArchived, isFalse);
      expect(
        repository.getTemplatesForProgram(box, programA).map((t) => t.id),
        contains(template.id),
      );
    },
  );

  test(
    'deleteTemplate removes the record entirely — not archived, gone',
    () async {
      final template = await repository.createTemplate(
        programId: programA,
        name: 'Legs',
      );

      await repository.deleteTemplate(template.id);

      final box = await repository.getUserBox();
      expect(box.get(template.id), isNull);
    },
  );

  test(
    'updateTemplate can never change programId — its signature has no such parameter',
    () async {
      final template = await repository.createTemplate(
        programId: programA,
        name: 'Push 1',
      );

      final updated = await repository.updateTemplate(
        templateId: template.id,
        name: 'Push 1 (renamed)',
        orderIndex: 2,
      );

      expect(updated.programId, equals(programA)); // unchanged
      expect(updated.name, equals('Push 1 (renamed)'));
      expect(updated.orderIndex, equals(2));

      final box = await repository.getUserBox();
      final stored = box.get(template.id);
      expect(stored!.programId, equals(programA));
    },
  );
}
