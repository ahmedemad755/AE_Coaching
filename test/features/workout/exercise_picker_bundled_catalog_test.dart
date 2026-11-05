import 'dart:io';
import 'dart:ui' as ui;

import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_picker_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_illustrations.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnavailableCustomRepository extends CustomExerciseRepository {
  _UnavailableCustomRepository()
    : super(storageManager: UserStorageManager(), uidOverride: () => 'test');

  @override
  Future<List<CustomExercise>> getAllExercises() async {
    throw StateError('Test custom storage failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CombinedExerciseLibraryCatalog catalog;
  late CustomExerciseRepository customExercises;
  late Map<String, String> bundledAssets;

  setUpAll(() async {
    bundledAssets = {
      for (final path in [
        ExerciseCatalogRepository.assetPath,
        ExerciseCatalogRepository.arabicAssetPath,
        ExerciseCatalogRepository.mappingAssetPath,
      ])
        path: await rootBundle.loadString(path),
    };
  });

  setUp(() {
    customExercises = _UnavailableCustomRepository();
    catalog = CombinedExerciseLibraryCatalog(
      builtInCatalog: ExerciseCatalogRepository(
        loadAsset: (path) async => bundledAssets[path]!,
      ),
      customExercises: customExercises,
    );
  });

  Future<void> openPicker(
    WidgetTester tester,
    String languageCode, {
    ThemeMode mode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(languageCode),
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RepaintBoundary(
          key: const ValueKey('picker-preview'),
          child: Scaffold(
            body: ExercisePickerDialog(
              catalog: catalog,
              customExercises: customExercises,
              languageCode: languageCode,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> revealExercise(WidgetTester tester, Finder target) async {
    final scrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      100,
      maxScrolls: 200,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('real bundled catalog is visible with default filters', (
    tester,
  ) async {
    await openPicker(tester, 'en');

    expect(
      find.byKey(const ValueKey('exercise-card-repdb:90-90-hold')),
      findsOneWidget,
    );
    expect(find.text('Could not load the exercise library.'), findsNothing);
    expect(find.text('No exercises match your search.'), findsNothing);
    expect(find.textContaining('results found'), findsNothing);
    expect(find.textContaining('180'), findsNothing);
  });

  testWidgets('built-ins remain visible when custom storage fails', (
    tester,
  ) async {
    await openPicker(tester, 'en');

    expect(
      find.byKey(const ValueKey('exercise-card-repdb:90-90-hold')),
      findsOneWidget,
    );
  });

  testWidgets('Arabic names render and Arabic and English search work', (
    tester,
  ) async {
    await openPicker(tester, 'ar');
    await tester.enterText(find.byType(TextField).first, 'Barbell Bench Press');
    await tester.pumpAndSettle();

    expect(
      find.text(
        '\u0628\u0646\u0634 \u0628\u0627\u0631 \u0645\u0633\u062a\u0648\u064a',
      ),
      findsOneWidget,
    );
    expect(
      Directionality.of(tester.element(find.byType(ExercisePickerDialog))),
      TextDirection.rtl,
    );

    final search = find.byType(TextField).first;
    await tester.enterText(
      search,
      '\u0628\u0646\u0634 \u0628\u0627\u0631 \u0645\u0633\u062a\u0648\u064a',
    );
    await tester.pumpAndSettle();
    expect(
      find
          .text(
            '\u0628\u0646\u0634 \u0628\u0627\u0631 \u0645\u0633\u062a\u0648\u064a',
          )
          .last,
      findsOneWidget,
    );
    expect(find.text('No exercises match your search.'), findsNothing);

    await tester.enterText(search, 'Barbell Bench Press');
    await tester.pumpAndSettle();
    expect(
      find
          .text(
            '\u0628\u0646\u0634 \u0628\u0627\u0631 \u0645\u0633\u062a\u0648\u064a',
          )
          .last,
      findsOneWidget,
    );
  });

  testWidgets(
    'Back muscle filter keeps Lat Pulldown searchable and clears independently',
    (tester) async {
      await openPicker(tester, 'en');
      final search = find.byType(TextField).first;
      Finder shownExercise(String name) =>
          find.descendant(of: find.byType(ListView), matching: find.text(name));

      await tester.enterText(search, 'Lat Pulldown');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        shownExercise('Lat Pulldown'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(shownExercise('Lat Pulldown'), findsOneWidget);

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('muscle-filter-back')));
      await tester.pumpAndSettle();
      await revealExercise(tester, shownExercise('Lat Pulldown'));
      expect(shownExercise('Lat Pulldown'), findsOneWidget);

      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        shownExercise('Lat Pulldown'),
        // Illustrated cards include credits and can be taller. Small drags
        // keep the target inside the narrow viewport below expanded filters.
        100,
        maxScrolls: 200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(shownExercise('Lat Pulldown'), findsOneWidget);

      await tester.enterText(search, 'Hammer Curl');
      await tester.pumpAndSettle();
      expect(shownExercise('Dumbbell Hammer Curl'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('muscle-filter-back')));
      await tester.ensureVisible(
        find.byKey(const ValueKey('muscle-filter-brachialis')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('muscle-filter-brachialis')));
      await tester.pumpAndSettle();
      await revealExercise(tester, shownExercise('Dumbbell Hammer Curl'));
      expect(shownExercise('Dumbbell Hammer Curl'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('muscle-filter-brachialis')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('muscle-filter-brachialis')));
      await tester.pumpAndSettle();
      await revealExercise(tester, shownExercise('Dumbbell Hammer Curl'));
      expect(shownExercise('Dumbbell Hammer Curl'), findsOneWidget);
    },
  );

  testWidgets('muscle, equipment and Arabic search compose on real catalog', (
    tester,
  ) async {
    await openPicker(tester, 'ar');
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExercisePickerDialog)),
    )!;
    await tester.tap(find.text(l10n.exerciseFiltersTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('muscle-filter-back')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('equipment-filter-cable')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment-filter-cable')));
    await tester.pumpAndSettle();

    final search = find.byType(TextField).first;
    await tester.enterText(search, 'سحب أمامي');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('exercise-card-repdb:lat-pulldown')),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('سحب أمامي'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('equipment-filter-cable')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment-filter-cable')));
    await tester.pumpAndSettle();
    await revealExercise(
      tester,
      find.byKey(const ValueKey('exercise-card-repdb:lat-pulldown')),
    );
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('سحب أمامي'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('empty state appears only when the query has no matches', (
    tester,
  ) async {
    await openPicker(tester, 'en');
    expect(find.text('No exercises match your search.'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'no-such-exercise');
    await tester.pumpAndSettle();
    expect(find.text('No exercises match your search.'), findsOneWidget);
  });

  testWidgets('default filter chips are all unselected', (tester) async {
    await openPicker(tester, 'en');
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();

    final chips = tester.widgetList<FilterChip>(
      find.byWidgetPredicate(
        (widget) => widget is FilterChip && widget.key != null,
      ),
    );
    expect(chips, isNotEmpty);
    expect(chips.every((chip) => !chip.selected), isTrue);
  });

  testWidgets('export complete dark LTR and light RTL picker previews', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(620, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final font in {
        'Roboto': 'C:/Windows/Fonts/arial.ttf',
        'MaterialIcons':
            'C:/flutter/src/flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final file = File(font.value);
        if (file.existsSync()) {
          final loader = FontLoader(font.key)
            ..addFont(
              file.readAsBytes().then((bytes) => bytes.buffer.asByteData()),
            );
          await loader.load();
        }
      }
    });
    for (final preview in [('en', ThemeMode.dark), ('ar', ThemeMode.light)]) {
      await openPicker(tester, preview.$1, mode: preview.$2);
      final context = tester.element(find.byType(ExercisePickerDialog));
      await tester.runAsync(() async {
        for (final illustration
            in ExerciseIllustrations.verifiedByExerciseId.values) {
          await precacheImage(
            ResizeImage(
              AssetImage(illustration.assetPath),
              width: 336,
              height: 336,
              policy: ResizeImagePolicy.fit,
            ),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('picker-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(
          'build/exercise-picker-previews',
        ).create(recursive: true);
        await File(
          'build/exercise-picker-previews/picker-${preview.$1}.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
