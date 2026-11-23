import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_reference_resolver.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_detail_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_media_resolver.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_thumbnail.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Customs extends CustomExerciseRepository {
  _Customs()
    : super(storageManager: UserStorageManager(), uidOverride: () => 'u');

  final Map<String, CustomExercise> byId = {
    'my-curl': CustomExercise(
      id: 'my-curl',
      name: 'Cable curl 21s',
      createdAt: DateTime(2026, 1, 1),
    ),
  };
  bool fail = false;

  @override
  Future<CustomExercise?> getById(String id) async {
    if (fail) throw StateError('storage closed');
    return byId[id];
  }
}

WorkoutTemplateExerciseAssignment _assignment(
  String id,
  String type,
  String name,
) => WorkoutTemplateExerciseAssignment(
  assignmentId: 'a-$id',
  exerciseId: id,
  exerciseNameSnapshot: name,
  referenceType: type,
);

const _latPulldownPeak =
    'lib/assets/repdb/images/flat/close-grip-lat-pulldown-peak.webp';

void main() {
  late int catalogLoads;
  late _Customs customs;
  late ExerciseReferenceResolver resolver;

  setUp(() {
    catalogLoads = 0;
    customs = _Customs();
    resolver = ExerciseReferenceResolver(
      catalog: ExerciseCatalogRepository(
        loadAsset: (path) async {
          if (path == ExerciseCatalogRepository.assetPath) catalogLoads++;
          return File(path).readAsStringSync();
        },
      ),
      customExercises: customs,
    );
  });

  group('ExerciseReferenceResolver (by id, never by name)', () {
    test('a RepDB exercise resolves to its own pictures', () async {
      final item = await resolver.resolve(
        exerciseId: 'repdb:close-grip-lat-pulldown',
        referenceType: 'builtIn',
      );
      expect(item!.id, 'repdb:close-grip-lat-pulldown');
      expect(
        ExerciseMediaResolver.resolve(item).thumbnail!.assetPath,
        _latPulldownPeak,
      );
      expect(File(_latPulldownPeak).existsSync(), isTrue);
    });

    test(
      'an older program id mapped to RepDB gets the RepDB pictures',
      () async {
        final item = await resolver.resolve(
          exerciseId: 'ex_barbell_bench_press',
          referenceType: 'builtIn',
        );
        expect(item!.id, 'repdb:bench-press');
        expect(item.legacyIds, {'ex_barbell_bench_press'});
        final path = ExerciseMediaResolver.resolve(item).thumbnail!.assetPath;
        expect(path, startsWith('lib/assets/repdb/images/'));
        expect(File(path).existsSync(), isTrue);
      },
    );

    test(
      'an older id without a RepDB match keeps its verified illustration',
      () async {
        final item = await resolver.resolve(
          exerciseId: 'ex_decline_barbell_bench_press',
          referenceType: 'builtIn',
        );
        final path = ExerciseMediaResolver.resolve(item!).thumbnail!.assetPath;
        expect(
          path,
          'lib/assets/exercise_illustrations/ex_decline_barbell_bench_press.webp',
        );
        expect(File(path).existsSync(), isTrue);
      },
    );

    test(
      'custom exercises resolve (no picture); manual, unknown and empty ids do not',
      () async {
        final custom = await resolver.resolve(
          exerciseId: 'my-curl',
          referenceType: 'custom',
        );
        expect(custom!.nameEn, 'Cable curl 21s');
        expect(ExerciseMediaResolver.resolve(custom).thumbnail, isNull);
        expect(
          await resolver.resolve(exerciseId: 'gone', referenceType: 'custom'),
          isNull,
        );
        expect(
          await resolver.resolve(exerciseId: 'Bench', referenceType: 'manual'),
          isNull,
        );
        expect(
          await resolver.resolve(
            exerciseId: 'repdb:nope',
            referenceType: 'builtIn',
          ),
          isNull,
        );
        expect(
          await resolver.resolve(exerciseId: '', referenceType: 'builtIn'),
          isNull,
        );
      },
    );

    test('the catalog is read once, however many rows ask', () async {
      await Future.wait([
        for (var i = 0; i < 20; i++)
          resolver.resolve(
            exerciseId: 'repdb:close-grip-lat-pulldown',
            referenceType: 'builtIn',
          ),
        resolver.resolve(
          exerciseId: 'ex_barbell_bench_press',
          referenceType: 'builtIn',
        ),
      ]);
      expect(catalogLoads, 1);
    });

    test('failures mean "no picture", never an error', () async {
      final broken = ExerciseReferenceResolver(
        catalog: ExerciseCatalogRepository(
          loadAsset: (_) async => throw const FileSystemException('x'),
        ),
        customExercises: customs..fail = true,
      );
      expect(
        await broken.resolve(
          exerciseId: 'repdb:bench-press',
          referenceType: 'builtIn',
        ),
        isNull,
      );
      expect(
        await broken.resolve(exerciseId: 'my-curl', referenceType: 'custom'),
        isNull,
      );
    });
  });

  group('ExerciseThumbnail', () {
    Future<void> pump(
      WidgetTester tester,
      Widget child, {
      String language = 'en',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark,
          home: Scaffold(body: Center(child: child)),
        ),
      );
      // Resolution reads real files: let it finish outside fake time.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
    }

    testWidgets(
      'a library exercise shows its picture; tapping opens its details',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(
          tester,
          ExerciseThumbnail(
            name: 'Close-grip lat pulldown',
            assignment: _assignment(
              'repdb:close-grip-lat-pulldown',
              'builtIn',
              'Close-grip lat pulldown',
            ),
            index: 2,
            resolver: resolver,
          ),
        );
        expect(
          find.byKey(const ValueKey('exercise-thumbnail-$_latPulldownPeak')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('exercise-thumbnail-monogram')),
          findsNothing,
        );
        expect(find.text('2'), findsOneWidget); // position badge
        expect(
          find.bySemanticsLabel('2. Preview exercise: Close-grip lat pulldown'),
          findsOneWidget,
        );

        await tester.tap(find.byType(ExerciseThumbnail));
        await tester.pumpAndSettle();
        final detail = tester.widget<ExerciseDetailScreen>(
          find.byType(ExerciseDetailScreen),
        );
        expect(detail.exercise.id, 'repdb:close-grip-lat-pulldown');
        semantics.dispose();
      },
    );

    testWidgets('a custom exercise shows a monogram of its name', (
      tester,
    ) async {
      await pump(
        tester,
        ExerciseThumbnail(
          name: 'Cable curl 21s',
          assignment: _assignment('my-curl', 'custom', 'Cable curl 21s'),
          resolver: resolver,
        ),
      );
      expect(
        find.byKey(const ValueKey('exercise-thumbnail-monogram')),
        findsOneWidget,
      );
      expect(find.text('C'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets(
      'Arabic names and unresolvable entries get a monogram, not a broken image',
      (tester) async {
        await pump(
          tester,
          ExerciseThumbnail(
            name: 'تمرين يدوي',
            assignment: _assignment('تمرين يدوي', 'manual', 'تمرين يدوي'),
            resolver: resolver,
          ),
          language: 'ar',
        );
        expect(find.text('ت'), findsOneWidget);
        await tester.tap(find.byType(ExerciseThumbnail));
        await tester.pumpAndSettle();
        expect(
          find.byType(ExerciseDetailScreen),
          findsNothing,
        ); // nothing to open
      },
    );

    testWidgets('without a registered resolver it still renders (monogram)', (
      tester,
    ) async {
      await pump(
        tester,
        ExerciseThumbnail(
          name: 'Bench press',
          assignment: _assignment(
            'repdb:bench-press',
            'builtIn',
            'Bench press',
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('exercise-thumbnail-monogram')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the exercise (replace) updates the picture', (
      tester,
    ) async {
      Widget thumb(String id) => ExerciseThumbnail(
        name: id,
        assignment: _assignment(id, 'builtIn', id),
        resolver: resolver,
      );
      await pump(tester, thumb('repdb:close-grip-lat-pulldown'));
      expect(
        find.byKey(const ValueKey('exercise-thumbnail-$_latPulldownPeak')),
        findsOneWidget,
      );
      await pump(tester, thumb('ex_decline_barbell_bench_press'));
      expect(
        find.byKey(
          const ValueKey(
            'exercise-thumbnail-lib/assets/exercise_illustrations/ex_decline_barbell_bench_press.webp',
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
