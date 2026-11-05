import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late UserStorageManager storageManager;

  CustomExerciseRepository repository(String uid) => CustomExerciseRepository(
    storageManager: storageManager,
    uidOverride: () => uid,
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('custom_exercise_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(CustomExerciseAdapter());
    }
    storageManager = UserStorageManager();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'creates and retrieves custom exercise with optional metadata',
    () async {
      final customExercises = repository('user-a');
      final created = await customExercises.createExercise(
        name: 'My Cable Fly',
      );

      expect(created.id, startsWith('custom_exercise_'));
      expect(created.name, 'My Cable Fly');
      expect(created.muscleGroup, isNull);
      expect(created.equipment, isNull);
      expect(await customExercises.getById(created.id), same(created));
      expect((await customExercises.getAllExercises()).single.id, created.id);
    },
  );

  test(
    'records survive closing storage and reopening after app restart',
    () async {
      final firstRepository = repository('restart-user');
      final created = await firstRepository.createExercise(
        name: 'Single Arm Row',
        muscleGroup: 'back',
        equipment: 'cable',
      );

      await storageManager.closeForUser('restart-user');
      storageManager = UserStorageManager();
      final restartedRepository = repository('restart-user');
      final restored = await restartedRepository.getById(created.id);

      expect(restored?.name, 'Single Arm Row');
      expect(restored?.muscleGroup, 'back');
      expect(restored?.equipment, 'cable');
    },
  );

  test('creates and searches locally without any remote service', () async {
    final customExercises = repository('offline-user');
    await customExercises.createExercise(name: 'Floor Press');

    expect((await customExercises.search('floor')).single.name, 'Floor Press');
  });

  test(
    'prevents normalized duplicates including concurrent requests',
    () async {
      final customExercises = repository('duplicate-user');
      await customExercises.createExercise(name: '  Cable   Fly ');

      await expectLater(
        customExercises.createExercise(name: 'cable fly'),
        throwsA(isA<DuplicateCustomExerciseException>()),
      );

      final concurrent = await Future.wait<Object>([
        customExercises
            .createExercise(name: 'Incline Press')
            .then<Object>((value) => value, onError: (Object error) => error),
        customExercises
            .createExercise(name: ' incline   press ')
            .then<Object>((value) => value, onError: (Object error) => error),
      ]);
      expect(concurrent.whereType<CustomExercise>(), hasLength(1));
      expect(
        concurrent.whereType<DuplicateCustomExerciseException>(),
        hasLength(1),
      );
    },
  );

  test('custom exercise boxes and records are isolated by account', () async {
    final first = repository('account-one');
    final second = repository('account-two');
    final exercise = await first.createExercise(name: 'Private Exercise');

    expect(await first.getById(exercise.id), isNotNull);
    expect(await second.getById(exercise.id), isNull);
    expect(await second.getAllExercises(), isEmpty);
  });

  test(
    'combined catalog searches built-in and custom exercises read-only',
    () async {
      final customRepository = repository('combined-user');
      await customRepository.createExercise(
        name: 'Dumbbell Bench Press Custom',
        muscleGroup: 'chest',
        equipment: 'dumbbell',
      );
      final catalog = CombinedExerciseLibraryCatalog(
        builtInCatalog: ExerciseCatalogRepository(),
        customExercises: customRepository,
      );

      final results = await catalog.search(query: 'bench press');
      expect(
        results.any((item) => item.source == ExerciseLibraryItemSource.builtIn),
        isTrue,
      );
      expect(
        results.any((item) => item.source == ExerciseLibraryItemSource.custom),
        isTrue,
      );

      final filtered = await catalog.search(
        query: 'bench press',
        muscleGroups: {'chest'},
        equipment: {'dumbbell'},
      );
      expect(
        filtered.where(
          (item) => item.source == ExerciseLibraryItemSource.custom,
        ),
        hasLength(1),
      );

      final customBack = await customRepository.createExercise(
        name: 'Custom Back Pulldown',
        muscleGroup: ' BACK ',
        equipment: ' Cable ',
      );
      final normalizedMetadata = await catalog.search(
        query: 'Custom Back Pulldown',
        muscleGroups: {'back'},
        equipment: {'cable'},
      );
      expect(
        normalizedMetadata.where((item) => item.id == customBack.id),
        hasLength(1),
      );
      expect(await customRepository.getAllExercises(), hasLength(2));
    },
  );

  test(
    'built-in catalog remains available if custom storage is unavailable',
    () async {
      final catalog = CombinedExerciseLibraryCatalog(
        builtInCatalog: ExerciseCatalogRepository(),
        customExercises: _UnavailableCustomRepository(storageManager),
      );

      final results = await catalog.search(query: 'bench press');
      expect(results, isNotEmpty);
      expect(
        results.every(
          (item) => item.source == ExerciseLibraryItemSource.builtIn,
        ),
        isTrue,
      );
    },
  );
}

class _UnavailableCustomRepository extends CustomExerciseRepository {
  _UnavailableCustomRepository(UserStorageManager storageManager)
    : super(storageManager: storageManager);

  @override
  Future<List<CustomExercise>> getAllExercises() async {
    throw StateError('Custom storage unavailable');
  }
}
