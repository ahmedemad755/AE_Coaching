import 'dart:async';

import 'package:ae_coaching/core/feedback/feedback_host.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_catalog_item.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_library.dart';
import 'package:ae_coaching/features/workout/domain/workout_features.dart';
import 'package:ae_coaching/features/workout/presentation/screens/cardio_library_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_picker_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/template_exercise_manager.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/layout/keyboard_phone.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/cardio_config_sheet.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_exercise_targets_dialog.dart';

/// The day in memory: the repository's own rules (limits, duplicates,
/// sync) are covered by cardio_library_test.dart; here, the screens.
class MemoryDays extends WorkoutTemplateRepository {
  MemoryDays(this.template)
    : super(storageManager: UserStorageManager(), uidOverride: () => 'flow');

  WorkoutTemplate template;
  var _next = 0;
  var adds = 0;

  /// Holds an addition until completed (to tap twice meanwhile).
  Completer<void>? hold;

  @override
  Future<WorkoutTemplate> addExerciseAssignment({
    required String templateId,
    required String exerciseId,
    required String exerciseNameSnapshot,
    required WorkoutExerciseReferenceType referenceType,
    CardioPlan? cardio,
  }) async {
    adds++;
    await hold?.future;
    final added = WorkoutTemplateExerciseAssignment(
      assignmentId: 'a${_next++}',
      exerciseId: exerciseId,
      exerciseNameSnapshot: exerciseNameSnapshot,
      referenceType: referenceType.name,
    );
    template = template.copyWith(
      exerciseAssignments: [
        ...template.exerciseAssignments,
        cardio == null
            ? added
            : added.withActivity(type: ActivityType.cardio, cardio: cardio),
      ],
    );
    return template;
  }

  final reorders = <List<String>>[];

  @override
  Future<WorkoutTemplate> reorderExerciseAssignments({
    required String templateId,
    required List<String> orderedAssignmentIds,
  }) async {
    reorders.add(orderedAssignmentIds);
    final byId = {
      for (final a in template.exerciseAssignments) a.assignmentId: a,
    };
    template = template.copyWith(
      exerciseAssignments: [for (final id in orderedAssignmentIds) byId[id]!],
    );
    return template;
  }

  @override
  Future<WorkoutTemplate> removeExerciseAssignment({
    required String templateId,
    required String assignmentId,
  }) async {
    template = template.copyWith(
      exerciseAssignments: [
        for (final a in template.exerciseAssignments)
          if (a.assignmentId != assignmentId) a,
      ],
    );
    return template;
  }

  @override
  Future<WorkoutTemplate> restoreExerciseAssignment({
    required String templateId,
    required WorkoutTemplateExerciseAssignment assignment,
    required int index,
  }) async {
    final list = [...template.exerciseAssignments];
    list.insert(index.clamp(0, list.length), assignment);
    template = template.copyWith(exerciseAssignments: list);
    return template;
  }

  @override
  Future<WorkoutTemplate> updateCardioPlan({
    required String templateId,
    required String assignmentId,
    required CardioPlan plan,
  }) async {
    plan.validate();
    template = template.copyWith(
      exerciseAssignments: [
        for (final a in template.exerciseAssignments)
          a.assignmentId == assignmentId
              ? a.withActivity(type: ActivityType.cardio, cardio: plan)
              : a,
      ],
    );
    return template;
  }

  @override
  Future<WorkoutTemplate> addExerciseAssignments({
    required String templateId,
    required List<ExerciseLibraryItem> exercises,
    required String languageCode,
  }) async {
    adds++;
    template = template.copyWith(
      exerciseAssignments: [
        ...template.exerciseAssignments,
        for (final exercise in exercises)
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'a${_next++}',
            exerciseId: exercise.id,
            exerciseNameSnapshot: exercise.nameForLanguage(languageCode),
            referenceType: exercise.source.name,
          ),
      ],
    );
    return template;
  }
}

class MemoryCustoms extends CustomExerciseRepository {
  MemoryCustoms([List<CustomExercise>? initial])
    : exercises = [...?initial],
      super(storageManager: UserStorageManager(), uidOverride: () => 'flow');

  final List<CustomExercise> exercises;

  @override
  Future<List<CustomExercise>> getAllExercises() async =>
      List.unmodifiable(exercises);

  @override
  Future<CustomExercise> createExercise({
    required String name,
    String? muscleGroup,
    String? equipment,
    ActivityType activityType = ActivityType.strength,
  }) async {
    final exercise = CustomExercise(
      id: 'custom-${exercises.length}',
      name: name,
      createdAt: DateTime.utc(2026, 11, 18),
      activityType: activityType == ActivityType.strength
          ? null
          : activityType.name,
    );
    exercises.add(exercise);
    return exercise;
  }
}

/// A few bundled-catalog entries (RepDB ids, both names).
class MemoryCatalog implements ExerciseLibraryCatalog {
  static const items = [
    ExerciseCatalogItem(
      id: 'repdb:bench-press',
      nameEn: 'Bench Press',
      nameAr: 'ضغط البنش',
      muscleGroup: 'chest',
      equipment: 'barbell',
    ),
    ExerciseCatalogItem(
      id: 'repdb:treadmill-running',
      nameEn: 'Treadmill Running',
      nameAr: 'الجري على السير',
      muscleGroup: 'cardio',
      equipment: 'treadmill',
    ),
    ExerciseCatalogItem(
      id: CardioLibrary.airBike,
      nameEn: 'Air Bike',
      nameAr: 'دراجة الهواء',
      muscleGroup: 'cardio',
      equipment: 'air_bike',
    ),
    ExerciseCatalogItem(
      id: 'repdb:running',
      nameEn: 'Running',
      nameAr: 'الجري',
      muscleGroup: 'cardio',
      equipment: 'none',
    ),
  ];

  @override
  Future<List<ExerciseLibraryItem>> search({
    String query = '',
    Set<String> muscleGroups = const {},
    Set<String> equipment = const {},
  }) async => [
    for (final item in items)
      if (query.isEmpty ||
          item.nameEn.toLowerCase().contains(query.toLowerCase()))
        ExerciseLibraryItem.fromBuiltIn(item),
  ];
}

void main() {
  late MemoryDays days;
  late MemoryCustoms customs;

  setUp(() {
    WorkoutFeatures.debugCardioOverride = null; // debug: cardio paths on
    days = MemoryDays(
      WorkoutTemplate(
        id: 'day',
        programId: 'p1',
        name: 'Push',
        createdAt: DateTime.utc(2026, 11),
      ),
    );
    customs = MemoryCustoms();
  });

  tearDown(() => WorkoutFeatures.debugCardioOverride = null);

  Future<AppLocalizations> pumpDay(
    WidgetTester tester, {
    String language = 'en',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        builder: AppFeedbackHost.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TemplateExerciseManager(
              template: days.template,
              repository: days,
              catalog: MemoryCatalog(),
              customExercises: customs,
              languageCode: language,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(TemplateExerciseManager)),
    )!;
  }

  /// Lets any confirmation toast finish before the test ends.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  }

  /// The category chips scroll sideways (small screens): scrolls to one first.
  Future<void> tapFilter(WidgetTester tester, String name) async {
    final chip = find.byKey(ValueKey('cardio-filter-$name'));
    await tester.scrollUntilVisible(
      chip,
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('cardio-filters')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  /// Closes the settings sheet that opens after a cardio activity is added.
  Future<void> cancelConfig(WidgetTester tester) async {
    final cancel = find.byKey(const ValueKey('cardio-config-cancel'));
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('template-add-activity')));
    await tester.pumpAndSettle();
  }

  testWidgets('Add activity offers strength, cardio and my library (timed '
      'not yet); strength opens the same exercise library', (tester) async {
    final l10n = await pumpDay(tester);
    expect(find.text(l10n.addActivityButton), findsOneWidget);
    await openSheet(tester);
    expect(find.text(l10n.addActivityStrengthTitle), findsOneWidget);
    expect(find.text(l10n.addActivityCardioTitle), findsOneWidget);
    expect(find.text(l10n.addActivityLibraryTitle), findsOneWidget);
    expect(find.textContaining('Timed'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-activity-strength')));
    await tester.pumpAndSettle();
    expect(find.byType(ExercisePickerDialog), findsOneWidget);
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.addSelectedExercisesButton(1)));
    await tester.pumpAndSettle();
    final added = days.template.exerciseAssignments.single;
    expect(added.exerciseId, 'repdb:bench-press');
    expect(added.type, ActivityType.strength);
    expect(added.activityType, isNull);
    await finish(tester);
  });

  testWidgets('cardio: found by its other name, added once with 20 minutes, '
      'shown as cardio; already in the day it is not selectable', (
    tester,
  ) async {
    final l10n = await pumpDay(tester);
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('add-activity-cardio')));
    await tester.pumpAndSettle();
    expect(find.byType(CardioLibraryScreen), findsOneWidget);
    expect(find.text(l10n.cardioLibraryTitle), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('cardio-search')),
      'assault',
    );
    await tester.pumpAndSettle();
    expect(find.text('Air Bike'), findsOneWidget);
    expect(find.text('Running'), findsNothing);
    expect(find.text(l10n.cardioAirBikeAlsoKnown), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('cardio-item-${CardioLibrary.airBike}')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CardioConfigSheet), findsOneWidget); // opens itself
    await cancelConfig(tester);

    expect(find.byType(CardioLibraryScreen), findsNothing);
    final added = days.template.exerciseAssignments.single;
    expect(added.exerciseId, CardioLibrary.airBike);
    expect(added.exerciseNameSnapshot, 'Air Bike');
    expect(added.type, ActivityType.cardio);
    expect(added.cardio!.durationSeconds, 1200);
    expect(
      find.byKey(ValueKey('cardio-summary-${added.assignmentId}')),
      findsOneWidget,
    );
    expect(
      find.text('${l10n.activityTypeCardio} · Countdown · 20 min'),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('template-cardio-avatar-${added.assignmentId}')),
      findsOneWidget,
    );

    // Again: it is in the day, so it can't be picked twice.
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('add-activity-cardio')));
    await tester.pumpAndSettle();
    final tile = find.byKey(
      const ValueKey('cardio-item-${CardioLibrary.airBike}'),
    );
    expect(
      find.descendant(of: tile, matching: find.text(l10n.cardioAlreadyInDay)),
      findsOneWidget,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(days.adds, 1);
    expect(find.byType(CardioLibraryScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('categories filter the library; my cardio is empty at first', (
    tester,
  ) async {
    final l10n = await pumpDay(tester);
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('add-activity-cardio')));
    await tester.pumpAndSettle();
    await tapFilter(tester, 'outdoor');
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Swimming'), findsOneWidget); // app-defined
    expect(find.text('Treadmill Running'), findsNothing);
    await tapFilter(tester, 'machines');
    expect(find.text('Treadmill Running'), findsOneWidget);
    expect(find.text('Running'), findsNothing);
    await tapFilter(tester, 'mine');
    expect(find.text(l10n.cardioMineEmpty), findsOneWidget);
    await finish(tester);
  });

  testWidgets(
    'a custom cardio activity is created as cardio and added to the day',
    (tester) async {
      final l10n = await pumpDay(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('add-activity-cardio')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cardio-create-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Hill sprints');
      await tester.tap(find.text(l10n.cardioCreateAndAdd));
      await tester.pumpAndSettle();
      expect(customs.exercises.single.activityType, 'cardio');
      final added = days.template.exerciseAssignments.single;
      expect(added.exerciseId, customs.exercises.single.id);
      expect(added.referenceType, 'custom');
      expect(added.type, ActivityType.cardio);
      await finish(tester);
    },
  );

  testWidgets('my library: own strength and cardio, each added its own way', (
    tester,
  ) async {
    customs = MemoryCustoms([
      CustomExercise(
        id: 'own-strength',
        name: 'Sled drag',
        createdAt: DateTime.utc(2026),
      ),
      CustomExercise(
        id: 'own-cardio',
        name: 'Hill sprints',
        createdAt: DateTime.utc(2026),
        activityType: 'cardio',
      ),
    ]);
    final l10n = await pumpDay(tester);
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('add-activity-library')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.myLibraryStrengthSection), findsOneWidget);
    expect(find.text(l10n.myLibraryCardioSection), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('my-library-item-own-cardio')));
    await tester.pumpAndSettle();
    await cancelConfig(tester);
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('add-activity-library')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('my-library-item-own-strength')),
    );
    await tester.pumpAndSettle();
    final [cardio, strength] = days.template.exerciseAssignments;
    expect(cardio.exerciseId, 'own-cardio');
    expect(cardio.type, ActivityType.cardio);
    expect(cardio.cardio!.durationSeconds, 1200);
    expect(strength.exerciseId, 'own-strength');
    expect(strength.type, ActivityType.strength);
    await finish(tester);
  });

  testWidgets('a double tap adds the activity once', (tester) async {
    await pumpDay(tester);
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('add-activity-cardio')));
    await tester.pumpAndSettle();
    days.hold = Completer<void>();
    final tile = find.byKey(const ValueKey('cardio-item-repdb:running'));
    await tester.tap(tile);
    await tester.pump();
    await tester.tap(tile, warnIfMissed: false);
    await tester.pump();
    days.hold!.complete();
    await tester.pumpAndSettle();
    expect(days.adds, 1);
    expect(days.template.exerciseAssignments, hasLength(1));
    await finish(tester);
  });

  testWidgets('release builds (cardio paths off): "Add exercise" opens the '
      'exercise library directly, as before', (tester) async {
    WorkoutFeatures.debugCardioOverride = false;
    final l10n = await pumpDay(tester);
    expect(find.text(l10n.addExerciseButton), findsOneWidget);
    expect(find.text(l10n.addActivityButton), findsNothing);
    await tester.tap(find.byKey(const ValueKey('template-add-activity')));
    await tester.pumpAndSettle();
    expect(find.byType(ExercisePickerDialog), findsOneWidget);
    expect(find.text(l10n.addActivityCardioTitle), findsNothing);
    await finish(tester);
  });

  testWidgets('saved cardio still shows safely with the cardio paths off; '
      'its menu offers no sets/reps editing', (tester) async {
    WorkoutFeatures.debugCardioOverride = false;
    days.template = days.template.copyWith(
      exerciseAssignments: [
        WorkoutTemplateExerciseAssignment(
          assignmentId: 'synced',
          exerciseId: 'repdb:running',
          exerciseNameSnapshot: 'Running',
          referenceType: 'builtIn',
        ).withActivity(
          type: ActivityType.cardio,
          cardio: CardioLibrary.defaultPlan,
        ),
      ],
    );
    final l10n = await pumpDay(tester);
    expect(find.byKey(const ValueKey('cardio-summary-synced')), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text(l10n.editExerciseTargets), findsNothing);
    expect(find.text(l10n.replaceExerciseAction), findsNothing);
    expect(find.text(l10n.removeExerciseAction), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await finish(tester);
  });

  testWidgets('Arabic: right-to-left, Arabic names and labels', (tester) async {
    final l10n = await pumpDay(tester, language: 'ar');
    expect(l10n.addActivityButton, 'إضافة نشاط');
    await openSheet(tester);
    expect(find.text('كارديو'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-activity-cardio')));
    await tester.pumpAndSettle();
    expect(find.text('مكتبة الكارديو'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(CardioLibraryScreen))),
      TextDirection.rtl,
    );
    expect(find.text('الجري على السير'), findsOneWidget);
    expect(find.text('Treadmill Running'), findsOneWidget); // English name
    await tester.enterText(find.byKey(const ValueKey('cardio-search')), 'الظل');
    await tester.pumpAndSettle();
    expect(find.text('ملاكمة الظل'), findsOneWidget);
    await tester.tap(find.text('ملاكمة الظل'));
    await tester.pumpAndSettle();
    final added = days.template.exerciseAssignments.single;
    expect(added.exerciseNameSnapshot, 'ملاكمة الظل');
    expect(find.text('كارديو · عد تنازلي · 20 دقيقة'), findsOneWidget);
    await finish(tester);
  });

  for (final language in ['en', 'ar']) {
    testWidgets('$language · small phone, text ×1.3: the sheet and the '
        'library fit', (tester) async {
      useSmallPhone(tester, textScale: 1.3);
      await pumpDay(tester, language: language);
      await openSheet(tester);
      expectNoOverflow(tester);
      await tester.tap(find.byKey(const ValueKey('add-activity-cardio')));
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
      await tapFilter(tester, 'mine');
      expectNoOverflow(tester);
      await finish(tester);
    });
  }

  for (final cardioOn in [true, false]) {
    testWidgets('cardio paths ${cardioOn ? 'on' : 'off'}: old, new, malformed '
        'and unknown activities are all shown safely', (tester) async {
      WorkoutFeatures.debugCardioOverride = cardioOn;
      days.template = days.template.copyWith(
        exerciseAssignments: [
          // Saved by builds before Stage 2: no type, no schema fields.
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'old',
            exerciseId: 'repdb:bench-press',
            exerciseNameSnapshot: 'Bench Press',
            referenceType: 'builtIn',
            workingSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 12,
            restSeconds: 90,
          ),
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'new',
            exerciseId: 'repdb:running',
            exerciseNameSnapshot: 'Running',
            referenceType: 'builtIn',
          ).withActivity(
            type: ActivityType.cardio,
            cardio: CardioLibrary.defaultPlan,
          ),
          WorkoutTemplateExerciseAssignment.fromActivityMap({
            'id': 'malformed',
            'type': 'cardio',
            'exerciseId': 'repdb:walking',
            'referenceType': 'builtIn',
            'name': 'Walking',
            'cardio': {'mode': 'countdown', 'durationSeconds': 'twenty'},
          }),
          WorkoutTemplateExerciseAssignment.fromActivityMap({
            'id': 'unknown',
            'type': 'yoga',
            'exerciseId': 'future:yoga',
            'referenceType': 'builtIn',
            'name': 'Future activity',
          }),
        ],
      );
      final l10n = await pumpDay(tester);
      expect(tester.takeException(), isNull);
      for (final name in [
        'Bench Press',
        'Running',
        'Walking',
        'Future activity',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(
        find.text('${l10n.activityTypeCardio} · Countdown · 20 min'),
        findsOneWidget,
      );
      expect(
        find.text('${l10n.activityTypeCardio} · ${l10n.cardioModeCountdown}'),
        findsOneWidget,
      ); // malformed duration: the mode alone
      expect(
        find.text(cardioOn ? l10n.addActivityButton : l10n.addExerciseButton),
        findsOneWidget,
      );
      await finish(tester);
    });
  }

  group('cardio settings and the estimated duration (Stage 4)', () {
    WorkoutTemplateExerciseAssignment cardioRow(
      String id,
      String exerciseId,
      String name,
    ) =>
        WorkoutTemplateExerciseAssignment(
          assignmentId: id,
          exerciseId: exerciseId,
          exerciseNameSnapshot: name,
          referenceType: 'builtIn',
        ).withActivity(
          type: ActivityType.cardio,
          cardio: CardioLibrary.defaultPlan,
        );

    void mixedDay() {
      days.template = days.template.copyWith(
        exerciseAssignments: [
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'bench',
            exerciseId: 'repdb:bench-press',
            exerciseNameSnapshot: 'Bench Press',
            referenceType: 'builtIn',
            workingSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 12,
            restSeconds: 90,
          ),
          cardioRow('tread', 'repdb:treadmill-running', 'Treadmill Running'),
        ],
      );
    }

    testWidgets('a mixed day shows its estimate (labelled as one)', (
      tester,
    ) async {
      mixedDay();
      final l10n = await pumpDay(tester);
      // 3 × 10 × 3 s + 2 × 90 s rest + 20 min = 1470 s → 25 min.
      expect(find.text(l10n.estimatedDuration('25 min')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('tap a cardio activity: change mode and rounds, save; the day '
        'and its estimate follow; strength keeps its own editor', (
      tester,
    ) async {
      mixedDay();
      final l10n = await pumpDay(tester);
      await tester.tap(find.text('Treadmill Running'));
      await tester.pumpAndSettle();
      expect(find.byType(CardioConfigSheet), findsOneWidget);
      // Treadmill: speed, incline and distance are offered.
      expect(find.byKey(const ValueKey('cardio-detail-speed')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cardio-detail-incline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cardio-detail-distance')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cardio-detail-resistance')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('cardio-mode-intervals')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('cardio-rounds-plus')),
      );
      await tester.tap(find.byKey(const ValueKey('cardio-rounds-plus')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('cardio-config-save')),
      );
      await tester.tap(find.byKey(const ValueKey('cardio-config-save')));
      await tester.pumpAndSettle();

      final plan = days.template.exerciseAssignments[1].cardio!;
      expect(plan.mode, CardioMode.intervals);
      expect(
        (plan.workSeconds, plan.intervalRestSeconds, plan.rounds),
        (30, 30, 9),
      );
      // 9 × 30 + 8 × 30 = 510 s → 9 min.
      expect(
        find.text('${l10n.activityTypeCardio} · Intervals · 9 min'),
        findsOneWidget,
      );
      // 270 + 510 = 780 s → 13 min.
      expect(find.text(l10n.estimatedDuration('13 min')), findsOneWidget);

      // Strength rows keep their sets/reps editor (after the confirmation
      // has gone).
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.cardioSettingsTitle), findsNothing);
      await tester.tap(find.text(l10n.editExerciseTargets));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutExerciseTargetsDialog), findsOneWidget);
      await tester.tap(find.text(l10n.cancel).last);
      await finish(tester);
    });

    testWidgets('invalid details block saving; Arabic digits and comma are '
        'read; cancel changes nothing', (tester) async {
      mixedDay();
      final l10n = await pumpDay(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cardioSettingsTitle));
      await tester.pumpAndSettle();
      final speed = find.byKey(const ValueKey('cardio-detail-speed'));
      await tester.enterText(speed, '99');
      await tester.pumpAndSettle();
      expect(find.text(l10n.cardioValueRange('0.5', '40')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('cardio-config-save')),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('cardio-config-save')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(speed, '١٢٫٥'); // 12.5 typed in Arabic
      await tester.pumpAndSettle();
      expect(find.text(l10n.cardioValueRange('0.5', '40')), findsNothing);
      await tester.tap(find.text(l10n.cancel).last);
      await tester.pumpAndSettle();
      expect(days.template.exerciseAssignments[1].cardio!.speedKmh, isNull);

      // Saved this time.
      await tester.tap(find.text('Treadmill Running'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('cardio-detail-speed')),
        '١٢٫٥',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('cardio-config-save')),
      );
      await tester.tap(find.byKey(const ValueKey('cardio-config-save')));
      await tester.pumpAndSettle();
      expect(days.template.exerciseAssignments[1].cardio!.speedKmh, 12.5);
      await finish(tester);
    });

    testWidgets('a stopwatch without a target: saved with no duration; the '
        'day estimate becomes "at least"', (tester) async {
      mixedDay();
      final l10n = await pumpDay(tester);
      await tester.tap(find.text('Treadmill Running'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cardio-mode-stopwatch')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cardio-duration-value')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('cardio-config-save')),
      );
      await tester.tap(find.byKey(const ValueKey('cardio-config-save')));
      await tester.pumpAndSettle();
      final plan = days.template.exerciseAssignments[1].cardio!;
      expect((plan.mode, plan.durationSeconds), (CardioMode.stopwatch, null));
      expect(
        find.text('${l10n.activityTypeCardio} · Stopwatch'),
        findsOneWidget,
      );
      expect(find.text(l10n.estimatedDurationAtLeast('5 min')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('only the details that fit the activity are offered', (
      tester,
    ) async {
      days.template = days.template.copyWith(
        exerciseAssignments: [
          cardioRow('walk', 'repdb:walking', 'Walking'),
          cardioRow('burpees', 'repdb:burpees', 'Burpees'),
        ],
      );
      await pumpDay(tester);
      await tester.tap(find.text('Walking'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cardio-detail-distance')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('cardio-detail-speed')), findsNothing);
      await tester.tap(
        find.text(lookupAppLocalizations(const Locale('en')).cancel).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Burpees'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cardio-detail-distance')),
        findsNothing,
      );
      await finish(tester);
    });

    testWidgets('cardio paths off: no cardio settings (no menu entry, tapping '
        'does nothing); the estimate is still shown', (tester) async {
      WorkoutFeatures.debugCardioOverride = false;
      mixedDay();
      final l10n = await pumpDay(tester);
      await tester.tap(find.text('Treadmill Running'));
      await tester.pumpAndSettle();
      expect(find.byType(CardioConfigSheet), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      expect(find.text(l10n.cardioSettingsTitle), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text(l10n.estimatedDuration('25 min')), findsOneWidget);
      await finish(tester);
    });

    for (final language in ['en', 'ar']) {
      testWidgets('$language · small phone, text ×1.3, keyboard open: the '
          'settings fit and Save stays reachable', (tester) async {
        useSmallPhone(tester, textScale: 1.3);
        mixedDay();
        await pumpDay(tester, language: language);
        await tester.tap(
          find.byKey(const ValueKey('template-cardio-avatar-tread')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CardioConfigSheet), findsOneWidget);
        expectNoOverflow(tester);
        await tester.tap(find.byKey(const ValueKey('cardio-mode-intervals')));
        await tester.pumpAndSettle();
        await tester.showKeyboard(
          find.byKey(const ValueKey('cardio-detail-speed')),
        );
        await setKeyboard(tester, open: true);
        expectNoOverflow(tester);
        await tester.ensureVisible(
          find.byKey(const ValueKey('cardio-config-save')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('cardio-config-save')).hitTestable(),
          findsOneWidget,
        );
        await setKeyboard(tester, open: false);
        await finish(tester);
      });
    }
  });

  group('after adding: settings open; removing: Undo', () {
    testWidgets('cardio just added: its settings open; Cancel keeps it with '
        '20 minutes and says so', (tester) async {
      final l10n = await pumpDay(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('add-activity-cardio')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cardio-item-repdb:running')));
      await tester.pumpAndSettle();
      expect(find.byType(CardioConfigSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('cardio-just-added')), findsOneWidget);
      expect(find.text(l10n.cardioJustAddedHint), findsOneWidget);
      await cancelConfig(tester);
      final kept = days.template.exerciseAssignments.single;
      expect(kept.exerciseId, 'repdb:running');
      expect(kept.cardio!.durationSeconds, 1200);
      expect(
        find.text(l10n.cardioAddedToDay('Running', '20 min')),
        findsOneWidget,
      );
      await finish(tester);
    });

    testWidgets('cardio just added: settings saved right away', (tester) async {
      final l10n = await pumpDay(tester);
      await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey('add-activity-cardio')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cardio-item-repdb:running')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('cardio-duration-plus')));
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('cardio-config-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        days.template.exerciseAssignments.single.cardio!.durationSeconds,
        21 * 60,
      );
      expect(find.text(l10n.cardioSettingsSaved), findsOneWidget);
      await finish(tester);
    });

    testWidgets('replacing a cardio activity does not open its settings', (
      tester,
    ) async {
      days.template = days.template.copyWith(
        exerciseAssignments: [
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'run',
            exerciseId: 'repdb:running',
            exerciseNameSnapshot: 'Running',
            referenceType: 'builtIn',
          ).withActivity(
            type: ActivityType.cardio,
            cardio: CardioLibrary.defaultPlan,
          ),
        ],
      );
      final l10n = await pumpDay(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.replaceExerciseAction));
      await tester.pumpAndSettle();
      expect(find.byType(CardioLibraryScreen), findsOneWidget);
      await finish(tester);
    });

    for (final cardio in [false, true]) {
      testWidgets(
        'removed ${cardio ? 'cardio' : 'strength'} activity: Undo puts the '
        'same entry back at its place',
        (tester) async {
          final strengthRow = WorkoutTemplateExerciseAssignment(
            assignmentId: 'bench',
            exerciseId: 'repdb:bench-press',
            exerciseNameSnapshot: 'Bench Press',
            referenceType: 'builtIn',
            workingSets: 4,
            targetRepsMin: 6,
            targetRepsMax: 8,
            restSeconds: 120,
          );
          final cardioRow =
              WorkoutTemplateExerciseAssignment(
                assignmentId: 'run',
                exerciseId: 'repdb:running',
                exerciseNameSnapshot: 'Running',
                referenceType: 'builtIn',
              ).withActivity(
                type: ActivityType.cardio,
                cardio: const CardioPlan(
                  mode: CardioMode.countdown,
                  durationSeconds: 900,
                ),
              );
          final last = WorkoutTemplateExerciseAssignment(
            assignmentId: 'squat',
            exerciseId: 'repdb:squat',
            exerciseNameSnapshot: 'Squat',
            referenceType: 'builtIn',
          );
          days.template = days.template.copyWith(
            exerciseAssignments: [strengthRow, cardioRow, last],
          );
          final removed = cardio ? cardioRow : strengthRow;
          final l10n = await pumpDay(tester);
          await tester.tap(
            find.byType(PopupMenuButton<String>).at(cardio ? 1 : 0),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.removeExerciseAction));
          await tester.pumpAndSettle();
          expect(
            days.template.exerciseAssignments.map((a) => a.assignmentId),
            isNot(contains(removed.assignmentId)),
          );
          expect(
            find.text(l10n.activityRemoved(removed.exerciseNameSnapshot)),
            findsOneWidget,
          );
          await tester.tap(find.text(l10n.undoAction));
          await tester.pumpAndSettle();
          expect(days.template.exerciseAssignments.map((a) => a.assignmentId), [
            'bench',
            'run',
            'squat',
          ]);
          expect(
            days.template.exerciseAssignments[cardio ? 1 : 0].toActivityMap(),
            removed.toActivityMap(),
          );
          await finish(tester);
        },
      );
    }
  });

  group('reordering without dragging, and haptics (Stage 5)', () {
    void threeActivities() {
      days.template = days.template.copyWith(
        exerciseAssignments: [
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'bench',
            exerciseId: 'repdb:bench-press',
            exerciseNameSnapshot: 'Bench Press',
            referenceType: 'builtIn',
          ),
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'run',
            exerciseId: 'repdb:running',
            exerciseNameSnapshot: 'Running',
            referenceType: 'builtIn',
          ).withActivity(
            type: ActivityType.cardio,
            cardio: CardioLibrary.defaultPlan,
          ),
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'squat',
            exerciseId: 'repdb:squat',
            exerciseNameSnapshot: 'Squat',
            referenceType: 'builtIn',
          ),
        ],
      );
    }

    List<String> order() => [
      for (final a in days.template.exerciseAssignments) a.assignmentId,
    ];

    Future<void> openMenu(WidgetTester tester, String id) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey(id)),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Move up / Move down in the menu: not offered at the ends; '
        'strength and cardio move through the same reorder path', (
      tester,
    ) async {
      threeActivities();
      final l10n = await pumpDay(tester);
      await openMenu(tester, 'bench');
      expect(find.text(l10n.moveUpTooltip), findsNothing);
      expect(find.text(l10n.moveDownTooltip), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await openMenu(tester, 'squat');
      expect(find.text(l10n.moveUpTooltip), findsOneWidget);
      expect(find.text(l10n.moveDownTooltip), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await openMenu(tester, 'run'); // cardio, in the middle
      await tester.tap(find.text(l10n.moveUpTooltip));
      await tester.pumpAndSettle();
      expect(order(), ['run', 'bench', 'squat']);
      await openMenu(tester, 'bench'); // strength
      await tester.tap(find.text(l10n.moveDownTooltip));
      await tester.pumpAndSettle();
      expect(order(), ['run', 'squat', 'bench']);
      expect(days.reorders, [
        ['run', 'bench', 'squat'],
        ['run', 'squat', 'bench'],
      ]);
      await finish(tester);
    });

    for (final language in ['en', 'ar']) {
      testWidgets(
        '$language: screen readers move an activity without dragging',
        (tester) async {
          final semantics = tester.ensureSemantics();
          threeActivities();
          final l10n = await pumpDay(tester, language: language);
          SemanticsNode node(String id) => tester.getSemantics(
            find.descendant(
              of: find.byKey(ValueKey(id)),
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Semantics &&
                    w.properties.customSemanticsActions != null,
              ),
            ),
          );
          int action(String label) => CustomSemanticsAction.getIdentifier(
            CustomSemanticsAction(label: label),
          );
          final up = action(l10n.moveUpTooltip);
          final down = action(l10n.moveDownTooltip);
          expect(node('bench').getSemanticsData().customSemanticsActionIds, [
            down,
          ]);
          expect(node('squat').getSemanticsData().customSemanticsActionIds, [
            up,
          ]);
          expect(
            node('run').getSemanticsData().customSemanticsActionIds,
            containsAll([up, down]),
          );

          final run = node('run');
          run.owner!.performAction(run.id, SemanticsAction.customAction, down);
          await tester.pumpAndSettle();
          expect(order(), ['bench', 'squat', 'run']);
          semantics.dispose();
          await finish(tester);
        },
      );
    }

    for (final language in ['en', 'ar']) {
      for (final id in ['run', 'squat']) {
        testWidgets('$language: dragging the "$id" row draws its moving copy '
            'without errors', (tester) async {
          threeActivities();
          await pumpDay(tester, language: language);
          final handle = find.descendant(
            of: find.byKey(ValueKey(id)),
            matching: find.byIcon(Icons.drag_handle),
          );
          final gesture = await tester.startGesture(tester.getCenter(handle));
          await tester.pump(const Duration(milliseconds: 50));
          for (var step = 0; step < 6; step++) {
            await gesture.moveBy(const Offset(0, -12));
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.takeException(), isNull);
          }
          await gesture.up();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await finish(tester);
        });
      }
    }

    testWidgets('a light haptic tick when an activity is lifted and dropped', (
      tester,
    ) async {
      final haptics = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      threeActivities();
      await pumpDay(tester);
      final handle = find.descendant(
        of: find.byKey(const ValueKey('bench')),
        matching: find.byIcon(Icons.drag_handle),
      );
      await tester.timedDrag(
        handle,
        const Offset(0, 90),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();
      expect(haptics, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.selectionClick',
      ]);
      expect(order().first, isNot('bench')); // the drag itself still works
      await finish(tester);
    });
  });
}
