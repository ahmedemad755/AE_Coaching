import 'dart:io';

import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Hand-rolled in-memory fake — no mocking package, same pattern as
/// workout_program_repository_test.dart.
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

void main() {
  late Directory tempDir;
  late WorkoutTemplateRepository repository;

  const programA = 'program_A';
  const programB = 'program_B';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('workout_template_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(WorkoutTemplateAdapter());
    }

    repository = WorkoutTemplateRepository(
      remoteDataSource: _FakeWorkoutTemplateRemoteDataSource(),
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
    final template = await repository.createTemplate(programId: programA, name: 'Push 1');

    final box = await repository.getUserBox();
    final stored = box.get(template.id);

    expect(stored, isNotNull);
    expect(stored!.programId, equals(programA));
    expect(stored.name, equals('Push 1'));
    expect(stored.isArchived, isFalse);
  });

  test(
    'getTemplatesForProgram returns only that program\'s templates — '
    'Program B templates never leak into Program A\'s list',
    () async {
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
    },
  );

  test(
    'archiving a template keeps its record but removes it from the '
    'normal (active) list, while still being visible with includeArchived',
    () async {
      final template = await repository.createTemplate(programId: programA, name: 'Legs');

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
      final withArchived = repository.getTemplatesForProgram(box, programA, includeArchived: true);
      expect(withArchived, hasLength(1));
      expect(withArchived.single.id, equals(template.id));
    },
  );

  test('restoreTemplate reverses archiveTemplate, bringing it back into the active list', () async {
    final template = await repository.createTemplate(programId: programA, name: 'Legs');
    await repository.archiveTemplate(template.id);

    await repository.restoreTemplate(template.id);

    final box = await repository.getUserBox();
    final stored = box.get(template.id);
    expect(stored!.isArchived, isFalse);
    expect(repository.getTemplatesForProgram(box, programA).map((t) => t.id), contains(template.id));
  });

  test('deleteTemplate removes the record entirely — not archived, gone', () async {
    final template = await repository.createTemplate(programId: programA, name: 'Legs');

    await repository.deleteTemplate(template.id);

    final box = await repository.getUserBox();
    expect(box.get(template.id), isNull);
  });

  test('updateTemplate can never change programId — its signature has no such parameter', () async {
    final template = await repository.createTemplate(programId: programA, name: 'Push 1');

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
  });
}
