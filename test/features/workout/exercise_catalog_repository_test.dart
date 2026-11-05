import 'dart:convert';

import 'package:ae_coaching/features/workout/data/models/exercise_catalog_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled catalog loads all approved records with unique IDs', () async {
    final catalog = await ExerciseCatalogRepository().loadCatalog();

    expect(catalog, hasLength(701));
    expect(catalog.map((exercise) => exercise.id).toSet(), hasLength(701));
    expect(
      catalog.every((exercise) => exercise.id.startsWith('repdb:')),
      isTrue,
    );
    final bench = catalog.singleWhere(
      (exercise) => exercise.id == 'repdb:bench-press',
    );
    expect(bench.nameEn, 'Barbell Bench Press');
    expect(
      bench.nameAr,
      '\u0628\u0646\u0634 \u0628\u0627\u0631 \u0645\u0633\u062a\u0648\u064a',
    );
    expect(bench.muscleGroup, 'chest');
    expect(bench.equipment, 'barbell');
  });

  test(
    'search matches English and Arabic names with Arabic normalization',
    () async {
      final repository = _repository(_sampleCatalog);

      expect(
        (await repository.search(query: 'incline bench')).map((e) => e.id),
        ['incline_press'],
      );
      expect(
        (await repository.search(
          query: '\u0628\u0646\u0634 \u0645\u0627\u0626\u0644',
        )).map((e) => e.id),
        ['incline_press'],
      );
      expect(
        (await repository.search(
          query:
              '\u0628\u064e\u0646\u0652\u0634 \u0645\u0627\u0626\u0650\u0644',
        )).map((e) => e.id),
        ['incline_press'],
      );
    },
  );

  test('muscle and equipment filters are combined', () async {
    final repository = _repository(_sampleCatalog);

    expect(
      (await repository.search(
        muscleGroups: {'chest'},
        equipment: {'dumbbell'},
      )).map((e) => e.id),
      ['incline_press'],
    );
    expect(
      await repository.search(muscleGroups: {'back'}, equipment: {'barbell'}),
      isEmpty,
    );
  });

  test(
    'bundled Back exercises remain searchable with muscle and equipment filters',
    () async {
      final repository = ExerciseCatalogRepository();

      final unfiltered = await repository.search(query: 'Lat Pulldown');
      expect(
        unfiltered.map((exercise) => exercise.id),
        contains('repdb:lat-pulldown'),
      );

      final filteredEnglish = await repository.search(
        query: 'Lat Pulldown',
        muscleGroups: {' BACK '},
        equipment: {' CABLE '},
      );
      expect(
        filteredEnglish.map((exercise) => exercise.id),
        contains('repdb:lat-pulldown'),
      );

      final filteredArabic = await repository.search(
        query: '\u0633\u062d\u0628 \u0623\u0645\u0627\u0645\u064a',
        muscleGroups: {'back'},
        equipment: {'cable'},
      );
      expect(
        filteredArabic.map((exercise) => exercise.id),
        contains('repdb:lat-pulldown'),
      );
      expect(
        await repository.search(
          query: 'Lat Pulldown',
          muscleGroups: {'biceps'},
        ),
        isEmpty,
      );

      final clearedSearch = await repository.search(muscleGroups: {'back'});
      expect(clearedSearch, isNotEmpty);
      expect(
        clearedSearch.every((exercise) => exercise.muscleGroup == 'back'),
        isTrue,
      );
    },
  );

  test('localized name follows requested language', () {
    final item = ExerciseCatalogItem.fromJson(_sampleExercise);
    expect(
      item.nameForLanguage('ar'),
      '\u0628\u0646\u0634 \u0645\u0627\u0626\u0644',
    );
    expect(item.nameForLanguage('en'), item.nameEn);
  });

  test('rejects unsupported schema and duplicate IDs', () async {
    final unsupported = _repository(
      jsonEncode({
        'schema_version': 2,
        'exercises': [_sampleExercise],
      }),
    );
    await expectLater(unsupported.loadCatalog(), throwsFormatException);

    final duplicate = _repository(
      jsonEncode({
        'schema_version': 1,
        'exercises': [_sampleExercise, _sampleExercise],
      }),
    );
    await expectLater(duplicate.loadCatalog(), throwsFormatException);
  });

  test('rejects missing required fields and invalid catalog shape', () async {
    final missingEquipment = Map<String, dynamic>.from(_sampleExercise)
      ..remove('equipment');
    final missingField = _repository(
      jsonEncode({
        'schema_version': 1,
        'exercises': [missingEquipment],
      }),
    );
    await expectLater(missingField.loadCatalog(), throwsFormatException);

    final invalidShape = _repository(
      jsonEncode({'schema_version': 1, 'exercises': {}}),
    );
    await expectLater(invalidShape.loadCatalog(), throwsFormatException);
  });
}

ExerciseCatalogRepository _repository(String json) =>
    ExerciseCatalogRepository(loadAsset: (_) async => json);

const _sampleExercise = <String, dynamic>{
  'id': 'incline_press',
  'name_en': 'Incline Bench Press',
  'name_ar': '\u0628\u0646\u0634 \u0645\u0627\u0626\u0644',
  'muscle_group': 'chest',
  'equipment': 'dumbbell',
};

final _sampleCatalog = jsonEncode({
  'schema_version': 1,
  'exercises': [
    _sampleExercise,
    {
      'id': 'row',
      'name_en': 'Dumbbell Row',
      'name_ar': '\u0633\u062d\u0628 \u062f\u0645\u0628\u0644',
      'muscle_group': 'back',
      'equipment': 'dumbbell',
    },
    {
      'id': 'barbell_press',
      'name_en': 'Barbell Bench Press',
      'name_ar': '\u0628\u0646\u0634 \u0628\u0627\u0631',
      'muscle_group': 'chest',
      'equipment': 'barbell',
    },
  ],
});
