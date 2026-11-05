import 'dart:io';
import 'dart:ui' as ui;
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program_draft.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/standard_workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/presentation/screens/standard_workout_templates_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_program_draft_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_template_layout.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_exercise_targets_dialog.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/standard_template_fixtures.dart';

class _Custom extends CustomExerciseRepository {
  _Custom()
    : super(
        storageManager: UserStorageManager(),
        uidOverride: () => 'widget-owner',
      );
  @override
  Future<List<CustomExercise>> getAllExercises() async => [];
}

class _Importer extends WorkoutTemplateImportService {
  WorkoutProgramDraft? saved;
  _Importer()
    : super(
        programs: WorkoutProgramRepository(
          storageManager: UserStorageManager(),
          remoteDataSource: TemplateProgramRemote(),
        ),
        templates: WorkoutTemplateRepository(
          storageManager: UserStorageManager(),
          remoteDataSource: TemplateDayRemote(),
        ),
        currentUserId: () => 'widget-owner',
      );
  @override
  Future<WorkoutTemplateImportResult> save(WorkoutProgramDraft draft) async {
    saved = draft;
    return WorkoutTemplateImportResult(
      WorkoutProgram(
        id: draft.programId,
        name: draft.name,
        createdAt: DateTime.now(),
      ),
      cloudSyncIncomplete: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'Roboto': 'C:/Windows/Fonts/arial.ttf',
      'MaterialIcons':
          'C:/flutter/src/flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(font.value);
      if (file.existsSync()) {
        await (FontLoader(font.key)
              ..addFont(file.readAsBytes().then((b) => b.buffer.asByteData())))
            .load();
      }
    }
  });
  late StandardWorkoutTemplateRepository templates;
  late _Importer importer;
  late _Custom custom;
  late CombinedExerciseLibraryCatalog exercises;
  setUp(() async {
    templates = standardTemplateCatalog();
    await templates.loadTemplates();
    importer = _Importer();
    custom = _Custom();
    exercises = CombinedExerciseLibraryCatalog(
      builtInCatalog: templates.catalog,
      customExercises: custom,
    );
  });
  Widget app(
    String language, {
    ThemeMode theme = ThemeMode.dark,
    StandardWorkoutTemplateRepository? source,
    Widget? child,
  }) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: theme,
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) =>
        RepaintBoundary(key: const ValueKey('templates-preview'), child: child),
    home:
        child ??
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open-templates'),
                child: const Text('Open templates'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StandardWorkoutTemplatesScreen(
                      templates: source ?? templates,
                      importer: importer,
                      exercises: exercises,
                      customExercises: custom,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
  );
  Future<void> open(
    WidgetTester tester,
    String lang, {
    ThemeMode theme = ThemeMode.dark,
  }) async {
    await tester.pumpWidget(app(lang, theme: theme));
    await tester.tap(find.byKey(const ValueKey('open-templates')));
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('split-push_pull_legs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('variant-ppl_3')));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('templates-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final dir = Directory('build/standard-template-previews');
      await dir.create(recursive: true);
      await File(
        '${dir.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language browse, preview, customize targets and save independent program',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(
          tester,
          language,
          theme: language == 'ar' ? ThemeMode.light : ThemeMode.dark,
        );
        expect(
          find.text(language == 'ar' ? 'قوالب التمارين' : 'Workout Templates'),
          findsOneWidget,
        );
        expect(
          Directionality.of(
            tester.element(find.byKey(const ValueKey('split-push_pull_legs'))),
          ),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        await capture(tester, '$language-library');
        await preview(tester);
        expect(
          find.text(language == 'ar' ? 'استخدم القالب' : 'Use Template'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('preview-day-push')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(const ValueKey('preview-day-push')));
        await tester.pumpAndSettle();
        expect(find.textContaining('180'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('use-workout-template')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('draft-program-name')),
          'My custom program',
        );
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(1), 'My push day');
        await tester.pump();
        // Tap the first assignment's visible target summary to open the shared editor.
        final firstAssignment = find
            .byWidgetPredicate(
              (w) =>
                  w is ListTile &&
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith(
                    'draft-assignment-',
                  ),
            )
            .first;
        await tester.ensureVisible(firstAssignment);
        await tester.tap(firstAssignment);
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const ValueKey('target-0')), '0');
        final saveLabel = language == 'ar' ? 'حفظ' : 'Save';
        await tester.tap(find.widgetWithText(FilledButton, saveLabel));
        await tester.pump();
        expect(
          find.textContaining(language == 'ar' ? 'استخدم ١' : 'Use 1'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('target-0')),
          language == 'ar' ? '٤' : '4',
        );
        await tester.enterText(
          find.byKey(const ValueKey('target-1')),
          language == 'ar' ? '٨' : '8',
        );
        await tester.enterText(
          find.byKey(const ValueKey('target-2')),
          language == 'ar' ? '١٢' : '12',
        );
        await tester.enterText(
          find.byKey(const ValueKey('target-3')),
          language == 'ar' ? '١٢٠' : '120',
        );
        await tester.tap(find.widgetWithText(FilledButton, saveLabel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, '$language-draft');
        await tester.tap(find.byKey(const ValueKey('save-template-copy')));
        await tester.pumpAndSettle();
        expect(importer.saved!.name, 'My custom program');
        expect(importer.saved!.days.first.name, 'My push day');
        expect(
          importer.saved!.days.first.exerciseAssignments.first.workingSets,
          4,
        );
        expect(
          importer.saved!.days.first.exerciseAssignments.first.restSeconds,
          120,
        );
        expect(find.byKey(const ValueKey('open-templates')), findsOneWidget);
      },
    );
  }
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void nameTargetGap(WidgetTester tester, Finder row, String name) {
    final title = find.descendant(of: row, matching: find.text(name));
    final targets = find.descendant(
      of: row,
      matching: find.byType(ExerciseTargetsSummary),
    );
    expect(
      tester.getTopLeft(targets).dy - tester.getBottomLeft(title).dy,
      closeTo(WorkoutTemplateSpacing.nameToTargets, 0.01),
    );
    expect(
      tester.getSize(row).height,
      greaterThanOrEqualTo(WorkoutTemplateSpacing.tapTarget),
    );
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language narrow browser/preview spacing survives expansion and collapse',
      (tester) async {
        phone(tester);
        final split = (await templates.loadTemplates()).first;
        await open(
          tester,
          language,
          theme: language == 'ar' ? ThemeMode.light : ThemeMode.dark,
        );
        final firstCard = find.byKey(
          const ValueKey('split-card-push_pull_legs'),
        );
        final secondCard = find.byKey(const ValueKey('split-card-upper_lower'));
        expect(tester.getTopLeft(firstCard).dx, WorkoutTemplateSpacing.screen);
        expect(
          tester.getTopLeft(secondCard).dy - tester.getBottomLeft(firstCard).dy,
          closeTo(WorkoutTemplateSpacing.programCard, 0.01),
        );
        expect(tester.widget<Card>(firstCard).margin, EdgeInsets.zero);
        final splitTile = find.byKey(const ValueKey('split-push_pull_legs'));
        final splitHeading = find.descendant(
          of: splitTile,
          matching: find.text(split.nameForLanguage(language)),
        );
        expect(find.byKey(const ValueKey('variant-ppl_3')), findsNothing);
        await tester.tap(splitHeading);
        await tester.pumpAndSettle();
        final firstVariant = find.byKey(const ValueKey('variant-ppl_3'));
        final secondVariant = find.byKey(const ValueKey('variant-ppl_6'));
        expect(
          tester.getSize(firstVariant).height,
          greaterThanOrEqualTo(WorkoutTemplateSpacing.tapTarget),
        );
        expect(
          tester.getTopLeft(secondVariant).dy -
              tester.getBottomLeft(firstVariant).dy,
          closeTo(WorkoutTemplateSpacing.variant, 0.01),
        );
        await tester.tap(splitHeading);
        await tester.pumpAndSettle();
        expect(firstVariant, findsNothing);
        await tester.tap(splitHeading);
        await tester.pumpAndSettle();
        await tester.tap(firstVariant);
        await tester.pumpAndSettle();
        final day = split.variants.first.days.first;
        final dayCard = find.byKey(ValueKey('preview-day-card-${day.id}'));
        await tester.scrollUntilVisible(
          dayCard,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final nextDayCard = find.byKey(
          ValueKey('preview-day-card-${split.variants.first.days[1].id}'),
        );
        expect(tester.getTopLeft(dayCard).dx, WorkoutTemplateSpacing.screen);
        expect(
          tester.getTopLeft(nextDayCard).dy - tester.getBottomLeft(dayCard).dy,
          closeTo(WorkoutTemplateSpacing.dayCard, 0.01),
        );
        final heading = find.descendant(
          of: find.byKey(ValueKey('preview-day-${day.id}')),
          matching: find.text(day.nameForLanguage(language)),
        );
        await tester.tap(heading);
        await tester.pumpAndSettle();
        final first = find.byKey(ValueKey('preview-exercise-${day.id}-0'));
        final second = find.byKey(ValueKey('preview-exercise-${day.id}-1'));
        expect(
          tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy,
          closeTo(WorkoutTemplateSpacing.exercise, 0.01),
        );
        nameTargetGap(
          tester,
          first,
          day.exercises.first.exercise.nameForLanguage(language),
        );
        await tester.ensureVisible(heading);
        await tester.pumpAndSettle();
        await tester.tap(heading);
        await tester.pumpAndSettle();
        expect(first, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language long draft names wrap and editing stays visible above keyboard',
      (tester) async {
        phone(tester);
        final split = (await templates.loadTemplates()).first;
        final original = WorkoutProgramDraft.fromTemplate(
          split: split,
          variant: split.variants.first,
          languageCode: language,
          ownerUid: 'widget-owner',
        );
        final longName = language == 'ar'
            ? 'تمرين ضغط الصدر باستخدام الدمبل بالتبادل مع تثبيت وضع الجسم على المقعد المائل'
            : 'Alternating dumbbell chest press with controlled movement on an inclined bench';
        final firstDay = original.days.first.copyWith(
          exerciseAssignments: [
            for (final assignment in original.days.first.exerciseAssignments)
              assignment.copyWith(exerciseNameSnapshot: longName),
          ],
        );
        final draft = original.copyWith(
          days: [firstDay, ...original.days.skip(1)],
        );
        await tester.pumpWidget(
          app(
            language,
            theme: language == 'ar' ? ThemeMode.light : ThemeMode.dark,
            child: WorkoutProgramDraftScreen(
              draft: draft,
              importer: importer,
              exercises: exercises,
              customExercises: custom,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = find.byKey(
          ValueKey(
            'draft-assignment-${firstDay.exerciseAssignments.first.assignmentId}',
          ),
        );
        final second = find.byKey(
          ValueKey(
            'draft-assignment-${firstDay.exerciseAssignments[1].assignmentId}',
          ),
        );
        expect(
          tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy,
          closeTo(WorkoutTemplateSpacing.exercise, 0.01),
        );
        nameTargetGap(tester, first, longName);
        expect(
          tester
              .getSize(
                find.descendant(
                  of: first,
                  matching: find.byType(PopupMenuButton<String>),
                ),
              )
              .height,
          greaterThanOrEqualTo(WorkoutTemplateSpacing.tapTarget),
        );
        expect(
          tester
              .widget<Card>(
                find.byKey(ValueKey('draft-day-card-${firstDay.id}')),
              )
              .margin,
          EdgeInsets.zero,
        );
        final name = find.byKey(const ValueKey('draft-program-name'));
        await tester.ensureVisible(name);
        await tester.pumpAndSettle();
        await tester.tap(name);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await tester.enterText(
          name,
          language == 'ar' ? 'برنامجي المعدل' : 'My adjusted plan',
        );
        await tester.pumpAndSettle();
        expect(tester.getBottomRight(name).dy, lessThanOrEqualTo(480));
        final save = find.byKey(const ValueKey('save-template-copy'));
        expect(
          tester.getSize(save).height,
          greaterThanOrEqualTo(WorkoutTemplateSpacing.tapTarget),
        );
        expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(480));
        expect(importer.saved, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('discard draft never calls persistence', (tester) async {
    await open(tester, 'en');
    await preview(tester);
    await tester.tap(find.byKey(const ValueKey('use-workout-template')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard this draft?'), findsOneWidget);
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(importer.saved, isNull);
    expect(find.byKey(const ValueKey('use-workout-template')), findsOneWidget);
  });
  testWidgets('library load error offers retry', (tester) async {
    final source = StandardWorkoutTemplateRepository(
      catalog: ExerciseCatalogRepository(
        loadAsset: (_) async => '{"schema_version":1,"exercises":[]}',
      ),
      loadAsset: (_) async => throw const FormatException('bad data'),
    );
    await tester.pumpWidget(app('en', source: source));
    await tester.tap(find.byKey(const ValueKey('open-templates')));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load workout templates.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
