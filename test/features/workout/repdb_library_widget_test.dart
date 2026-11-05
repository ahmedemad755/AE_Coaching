import 'dart:io';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_catalog_item.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_detail_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_library_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_sources_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_library_card.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Custom extends CustomExerciseRepository {
  _Custom()
    : super(
        storageManager: UserStorageManager(),
        uidOverride: () => 'widget-only',
      );
  @override
  Future<List<CustomExercise>> getAllExercises() async => [
    CustomExercise(
      id: 'custom_own_id',
      name: 'My custom exercise',
      createdAt: DateTime(2025),
    ),
  ];
}

void main() {
  late ExerciseCatalogRepository builtIn;
  late CombinedExerciseLibraryCatalog catalog;
  late _Custom custom;
  late List<ExerciseLibraryItem> saved;
  setUp(() async {
    builtIn = ExerciseCatalogRepository(
      loadAsset: (path) async => File(path).readAsStringSync(),
    );
    custom = _Custom();
    catalog = CombinedExerciseLibraryCatalog(
      builtInCatalog: builtIn,
      customExercises: custom,
    );
    saved = [];
  });
  Widget app(
    String language, {
    Set<String> excluded = const {},
    Widget? child,
    double scale = 1,
  }) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: language == 'ar' ? ThemeMode.dark : ThemeMode.light,
    locale: Locale(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home:
        child ??
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open library'),
              onPressed: () => showDialog<List<ExerciseLibraryItem>>(
                context: context,
                builder: (_) => ExerciseLibraryScreen(
                  catalog: catalog,
                  customExercises: custom,
                  languageCode: language,
                  excludedIds: excluded,
                  onAddSelected: (items) async {
                    saved = items;
                  },
                ),
              ),
            ),
          ),
        ),
  );
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> open(
    WidgetTester tester,
    String language, {
    Set<String> excluded = const {},
  }) async {
    await tester.pumpWidget(app(language, excluded: excluded));
    await tester.tap(find.text('Open library'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Barbell Bench Press');
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language: every one of the 701 catalog cards renders at narrow width',
      (tester) async {
        phone(tester);
        final items = await tester.runAsync(() => builtIn.loadCatalog());
        expect(items, hasLength(701));
        final current = ValueNotifier(
          ExerciseLibraryItem.fromBuiltIn(items!.first),
        );
        addTearDown(current.dispose);
        await tester.pumpWidget(
          app(
            language,
            scale: 1.4,
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ValueListenableBuilder<ExerciseLibraryItem>(
                    valueListenable: current,
                    builder: (_, exercise, _) => ExerciseLibraryCard(
                      exercise: exercise,
                      selected: false,
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final item in items) {
          current.value = ExerciseLibraryItem.fromBuiltIn(item);
          await tester.pump();
          expect(find.text(item.nameEn), findsOneWidget, reason: item.id);
          expect(find.text(item.nameAr), findsOneWidget, reason: item.id);
          expect(
            tester
                .widget<ExerciseLibraryCard>(find.byType(ExerciseLibraryCard))
                .exercise
                .id,
            item.id,
          );
          expect(
            tester
                .widget<ExerciseArtwork>(find.byType(ExerciseArtwork))
                .illustration,
            isNotNull,
            reason: item.id,
          );
          expect(tester.takeException(), isNull, reason: item.id);
        }
      },
    );
    testWidgets(
      '$language detail preview keeps selection separate and returns canonical ID',
      (tester) async {
        phone(tester);
        await open(tester, language);
        final card = find.byKey(
          const ValueKey('exercise-card-repdb:bench-press'),
        );
        expect(card, findsOneWidget);
        await tester.tap(
          find.descendant(of: card, matching: find.byType(ExerciseArtwork)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseDetailScreen), findsOneWidget);
        final images = tester
            .widgetList<ExerciseArtwork>(find.byType(ExerciseArtwork))
            .toList();
        expect(images, hasLength(2));
        expect(
          images[0].illustration!.assetPath,
          endsWith('bench-press-start.webp'),
        );
        expect(
          images[1].illustration!.assetPath,
          endsWith('bench-press-peak.webp'),
        );
        expect(saved, isEmpty);
        expect(
          Directionality.of(tester.element(find.byType(ExerciseDetailScreen))),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        await tester.tap(find.byKey(const ValueKey('detail-add-to-workout')));
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseDetailScreen), findsNothing);
        expect(tester.widget<ExerciseLibraryCard>(card).selected, isTrue);
        expect(saved, isEmpty); // Only the picker Save/Add action persists.
        final add = find.byWidgetPredicate(
          (w) => w is FilledButton && w.onPressed != null,
        );
        await tester.tap(add);
        await tester.pumpAndSettle();
        expect(saved.single.id, 'repdb:bench-press');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('a legacy assignment excludes its exact canonical equivalent', (
    tester,
  ) async {
    phone(tester);
    await open(tester, 'en', excluded: {'ex_barbell_bench_press'});
    final card = tester.widget<ExerciseLibraryCard>(
      find.byKey(const ValueKey('exercise-card-repdb:bench-press')),
    );
    expect(card.selected, isTrue);
    expect(card.onChanged, isNull);
    expect(saved, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'visible credits include exact attribution, pinned version and bundled full license',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(app('ar', child: const ExerciseSourcesScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Exercise data by RepDB (repdb.co)'), findsOneWidget);
      expect(
        find.textContaining(ExerciseCatalogRepository.datasetCommit),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byWidgetPredicate(
          (w) =>
              w is SelectableText &&
              (w.data?.contains('No generative-AI derivation') ?? false),
        ),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SelectableText &&
              (w.data?.contains('No redistribution as a dataset') ?? false),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('custom exercises keep their own ID and no inferred media', (
    tester,
  ) async {
    phone(tester);
    await open(tester, 'en');
    await tester.enterText(find.byType(TextField).first, 'My custom exercise');
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('exercise-card-custom_own_id'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('exercise-artwork-placeholder')),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is FilledButton && w.onPressed != null),
    );
    await tester.pumpAndSettle();
    expect(saved.single.id, 'custom_own_id');
    expect(saved.single.source, ExerciseLibraryItemSource.custom);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Arabic detail supports long names, large text and missing metadata/media',
    (tester) async {
      phone(tester);
      const item = ExerciseCatalogItem(
        id: 'repdb:test',
        sourceId: 'test',
        nameEn: 'An intentionally long exact exercise variation name',
        nameAr: 'تمرين باسم طويل للتحقق من وضوح العرض في الشاشات الصغيرة',
        muscleGroup: 'core',
        equipment: '',
        instructionsEn: ['Original English instruction.'],
      );
      await tester.pumpWidget(
        app(
          'ar',
          scale: 2,
          child: ExerciseDetailScreen(
            exercise: ExerciseLibraryItem.fromBuiltIn(item),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('exercise-artwork-placeholder')),
        200,
      );
      expect(
        find.byKey(const ValueKey('exercise-artwork-placeholder')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('1. Original English instruction.'),
        300,
      );
      await tester.pumpAndSettle();
      expect(find.text('1. Original English instruction.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
