import 'dart:io';
import 'dart:ui' as ui;

import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_illustrations.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_library_card.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const bench = ExerciseLibraryItem(
  id: 'ex_barbell_bench_press',
  nameEn: 'Barbell Bench Press',
  nameAr: 'بنش بار مستوي',
  muscleGroup: 'chest',
  equipment: 'barbell',
  source: ExerciseLibraryItemSource.builtIn,
);

Widget app(
  Widget card, {
  String language = 'en',
  ThemeMode mode = ThemeMode.dark,
}) => MaterialApp(
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: mode,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(12), child: card),
  ),
);

void main() {
  test(
    'only exact approved catalog IDs may have licensed local artwork',
    () async {
      final catalog = await ExerciseCatalogRepository(
        loadAsset: (path) => File(path).readAsString(),
      ).loadLegacyCatalog();
      expect(catalog, hasLength(180));
      final ids = catalog.map((item) => item.id).toSet();
      for (final entry in ExerciseIllustrations.verifiedByExerciseId.entries) {
        expect(ids, contains(entry.key));
        expect(entry.value.assetPath, startsWith('lib/assets/'));
        expect(File(entry.value.assetPath).existsSync(), isTrue);
        expect(entry.value.author, isNotEmpty);
        expect(entry.value.license, isNotEmpty);
        expect(Uri.parse(entry.value.sourceUrl).hasScheme, isTrue);
      }
      expect(
        ExerciseIllustrations.forExercise(
          const ExerciseLibraryItem(
            id: 'unknown',
            nameEn: 'Barbell Bench Press',
            source: ExerciseLibraryItemSource.builtIn,
          ),
        ),
        isNull,
      );
      expect(
        ExerciseIllustrations.forExercise(
          const ExerciseLibraryItem(
            id: 'ex_barbell_bench_press',
            nameEn: 'Custom bench',
            source: ExerciseLibraryItemSource.custom,
          ),
        ),
        isNull,
      );
    },
  );

  testWidgets('bilingual card shows metadata, fallback and toggles selection', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) => ExerciseLibraryCard(
            exercise: bench,
            selected: selected,
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      ),
    );
    expect(find.text(bench.nameEn), findsOneWidget);
    expect(find.text(bench.nameAr!), findsOneWidget);
    expect(find.textContaining('Chest', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('بار · Barbell', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('exercise-artwork-placeholder')),
      findsOneWidget,
    );
    await tester.tap(find.text(bench.nameEn));
    await tester.pump();
    expect(selected, isTrue);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(selected, isFalse);
  });

  testWidgets('preview does not select the exercise and closes independently', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      app(
        ExerciseLibraryCard(
          exercise: const ExerciseLibraryItem(
            id: 'unmapped-preview',
            nameEn: 'Custom preview',
            source: ExerciseLibraryItemSource.custom,
          ),
          selected: false,
          onChanged: (value) => selected = value,
        ),
      ),
    );
    await tester.tap(find.byType(ExerciseArtwork));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(selected, isFalse);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(selected, isFalse);
  });

  testWidgets('unavailable local image falls back without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        ExerciseLibraryCard(
          exercise: bench,
          selected: false,
          onChanged: (_) {},
          illustration: const ExerciseIllustration(
            assetPath: 'lib/assets/missing-exercise.png',
            author: 'Test',
            sourceUrl: 'https://example.org/test',
            license: 'Test fixture',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('exercise-artwork-placeholder')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('already assigned exercise stays selected and disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const ExerciseLibraryCard(
          exercise: bench,
          selected: true,
          onChanged: null,
        ),
      ),
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
  });

  for (final language in ['ar', 'en']) {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('small card mirrors artwork in $language / $mode', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            ExerciseLibraryCard(
              exercise: bench,
              selected: false,
              onChanged: (_) {},
            ),
            language: language,
            mode: mode,
          ),
        );
        final imageX = tester.getCenter(find.byType(ExerciseArtwork)).dx;
        final checkboxX = tester.getCenter(find.byType(Checkbox)).dx;
        expect(imageX < checkboxX, language == 'en');
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('export light and dark card previews for visual review', (
    tester,
  ) async {
    // Optional local preview font. Assertions remain platform independent;
    // this only replaces Flutter tests' block-shaped Ahem preview glyphs.
    final font = File('C:/Windows/Fonts/arial.ttf');
    if (font.existsSync()) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto')
          ..addFont(
            font.readAsBytes().then((bytes) => bytes.buffer.asByteData()),
          );
        await loader.load();
      });
    }
    tester.view.physicalSize = const Size(620, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      await tester.pumpWidget(
        app(
          RepaintBoundary(
            key: const ValueKey('preview'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExerciseLibraryCard(
                  exercise: bench,
                  selected: false,
                  onChanged: (_) {},
                ),
                const SizedBox(height: 10),
                const ExerciseLibraryCard(
                  exercise: bench,
                  selected: true,
                  onChanged: null,
                ),
              ],
            ),
          ),
          mode: mode,
        ),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(
          'build/exercise-picker-previews',
        ).create(recursive: true);
        await File(
          'build/exercise-picker-previews/${mode.name}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
