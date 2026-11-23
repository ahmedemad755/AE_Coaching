import 'dart:convert';

import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/standard_workout_template_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/standard_workout_templates_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'production bundle registers every input required for template loading',
    () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(
        manifest.listAssets(),
        containsAll([
          StandardWorkoutTemplateRepository.assetPath,
          ExerciseCatalogRepository.assetPath,
          ExerciseCatalogRepository.arabicAssetPath,
        ]),
      );
    },
  );

  test(
    'production rootBundle, parser and cubit load all canonical templates',
    () async {
      // No File loader, mocked asset channel, preloaded catalog or Hive fixture:
      // exercise the same constructors and packaged keys as production DI.
      final catalog = ExerciseCatalogRepository();
      final repository = StandardWorkoutTemplateRepository(catalog: catalog);
      final cubit = StandardWorkoutTemplatesCubit(repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.failed, isFalse);
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.splits, hasLength(7));
      final variants = cubit.state.splits.expand((s) => s.variants).toList();
      final days = variants.expand((v) => v.days).toList();
      final exercises = days.expand((d) => d.exercises).toList();
      expect(variants, hasLength(9));
      expect(days, hasLength(39));
      expect(exercises, hasLength(214));
      expect(exercises.map((e) => e.exercise.id).toSet(), hasLength(38));
      final activeIds = (await catalog.loadCatalog()).map((e) => e.id).toSet();
      for (final exercise in exercises) {
        expect(exercise.exercise.id, startsWith('repdb:'));
        expect(activeIds, contains(exercise.exercise.id));
        expect(exercise.exercise.isRepDb, isTrue);
      }
    },
  );

  test(
    'stale legacy asset fails explicitly without weakening canonical validation',
    () async {
      final data = jsonDecode(
        await rootBundle.loadString(
          StandardWorkoutTemplateRepository.assetPath,
        ),
      );
      data['splits'][0]['variants'][0]['days'][0]['exercises'][0]['exercise_id'] =
          'ex_barbell_bench_press';
      final repository = StandardWorkoutTemplateRepository(
        catalog: ExerciseCatalogRepository(),
        loadAsset: (_) async => jsonEncode(data),
      );
      await expectLater(
        repository.loadTemplates(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'reason',
            'Invalid or duplicate canonical exercise ID: ppl_3/push/ex_barbell_bench_press',
          ),
        ),
      );
    },
  );

  test(
    'debug failure logs the asset, actual parser reason and stack; retry loads valid bundle',
    () async {
      final source = await rootBundle.loadString(
        StandardWorkoutTemplateRepository.assetPath,
      );
      var broken = true;
      final output = <String>[];
      final originalPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) =>
          output.add(message ?? '');
      addTearDown(() => debugPrint = originalPrint);
      final cubit = StandardWorkoutTemplatesCubit(
        StandardWorkoutTemplateRepository(
          catalog: ExerciseCatalogRepository(),
          loadAsset: (_) async => broken ? '{"schema_version":999}' : source,
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.failed, isTrue);
      final logged = output.join('\n');
      expect(logged, contains('[WorkoutTemplates] Load failed'));
      expect(logged, contains(StandardWorkoutTemplateRepository.assetPath));
      expect(logged, contains('Unsupported template catalog.'));
      expect(
        logged,
        contains('StandardWorkoutTemplateRepository.loadTemplates'),
      );
      broken = false;
      await cubit.load();
      expect(cubit.state.failed, isFalse);
      expect(cubit.state.splits, hasLength(7));
    },
  );

  test(
    'unexpected exception diagnostics omit arbitrary payloads and retain stack',
    () async {
      final output = <String>[];
      final originalPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) =>
          output.add(message ?? '');
      addTearDown(() => debugPrint = originalPrint);
      final cubit = StandardWorkoutTemplatesCubit(
        StandardWorkoutTemplateRepository(
          catalog: ExerciseCatalogRepository(),
          loadAsset: (_) async =>
              throw StateError('sensitive-unexpected-payload'),
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.failed, isTrue);
      final logged = output.join('\n');
      expect(logged, contains('StateError'));
      expect(logged, contains('StandardWorkoutTemplatesCubit.load'));
      expect(logged, isNot(contains('sensitive-unexpected-payload')));
    },
  );
}
