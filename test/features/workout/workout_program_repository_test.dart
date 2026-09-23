import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_program_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Hand-rolled in-memory fake — no mocking package needed. Firestore's
/// `QueryDocumentSnapshot` is never constructed here since
/// `fetchAndSyncFromRemote` isn't exercised by these tests; an
/// explicitly-typed empty list satisfies the interface without it.
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

void main() {
  late Directory tempDir;
  late WorkoutProgramRepository repository;

  setUp(() async {
    // Plain `Hive.init` (not `initFlutter`) works fine in `flutter test`
    // without platform channels — the standard pattern for unit
    // testing Hive-backed repositories.
    tempDir = await Directory.systemTemp.createTemp('workout_program_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WorkoutProgramAdapter());
    }

    repository = WorkoutProgramRepository(
      remoteDataSource: _FakeWorkoutProgramRemoteDataSource(),
      storageManager: UserStorageManager(),
      // No Firebase app exists in this test environment — uidOverride
      // is the @visibleForTesting seam added specifically for this.
      uidOverride: () => 'test-uid',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'setActiveProgram keeps the previously active program (deactivated, '
    'never deleted) and preserves its startedAt when reactivated',
    () async {
      final programA = await repository.createProgram(name: 'Program A', makeActive: true);
      final programB = await repository.createProgram(name: 'Program B', makeActive: true);

      final box = await repository.getUserBox();

      // Program A still exists but is no longer active.
      final afterBActivated = box.get(programA.id);
      expect(afterBActivated, isNotNull);
      expect(afterBActivated!.isActive, isFalse);

      // Program B is the only active program.
      final reloadedB = box.get(programB.id);
      expect(reloadedB, isNotNull);
      expect(reloadedB!.isActive, isTrue);

      // Archive Program B.
      await repository.archiveProgram(programB.id);
      final archivedB = box.get(programB.id);
      expect(archivedB, isNotNull);
      expect(archivedB!.isActive, isFalse);
      expect(archivedB.endedAt, isNotNull);

      // Reactivate Program A.
      await repository.setActiveProgram(programA.id);
      final reactivatedA = box.get(programA.id);
      expect(reactivatedA, isNotNull);
      expect(reactivatedA!.isActive, isTrue);
      expect(reactivatedA.startedAt, equals(afterBActivated.startedAt));
      // A was never archived in this flow, so its endedAt was always
      // null — this guards against a future regression where switching
      // active programs starts stamping endedAt on the side.
      expect(reactivatedA.endedAt, isNull);
    },
  );

  test(
    'reactivating a program that was previously archived clears its endedAt',
    () async {
      final program = await repository.createProgram(name: 'Program C', makeActive: true);
      await repository.archiveProgram(program.id);

      final box = await repository.getUserBox();
      final archived = box.get(program.id);
      expect(archived, isNotNull);
      expect(archived!.endedAt, isNotNull);
      expect(archived.isActive, isFalse);

      await repository.setActiveProgram(program.id);
      final reactivated = box.get(program.id);
      expect(reactivated, isNotNull);
      expect(reactivated!.isActive, isTrue);
      expect(reactivated.endedAt, isNull);
    },
  );

  test('deleteProgram removes the record entirely — not archived, gone', () async {
    final program = await repository.createProgram(name: 'Program D');

    await repository.deleteProgram(program.id);

    final box = await repository.getUserBox();
    expect(box.get(program.id), isNull);
  });
}
