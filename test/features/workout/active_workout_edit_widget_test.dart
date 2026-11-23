import 'dart:io';
import 'package:ae_coaching/core/feedback/feedback_host.dart';
import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/active_workout_edit_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_reference_resolver.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/active_workout_session_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_detail_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/workout_features.dart';
import 'package:ae_coaching/features/workout/presentation/screens/cardio_library_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_workout_edit_service_test.dart' show ActiveEditSetsRemote;
import '../../core/layout/keyboard_phone.dart';
import 'support/standard_template_fixtures.dart';

class WidgetCustomExercises extends CustomExerciseRepository {
  WidgetCustomExercises()
    : super(
        storageManager: UserStorageManager(),
        uidOverride: () => 'widget-owner',
      );
  @override
  Future<List<CustomExercise>> getAllExercises() async => [];
}

/// Deterministic UI seam. The service tests separately use actual Hive files,
/// failures and disk reopen. This fake records exactly the UI's chosen scope.
class WidgetActiveExercises extends SessionExerciseCubit {
  WorkoutSession current;
  ActiveWorkoutEditScope? lastScope;
  int mutations = 0;
  bool fail = false;
  List<ExerciseSet> logged = [];
  WidgetActiveExercises(this.current)
    : super(
        repository: SessionExerciseRepository(
          storageManager: UserStorageManager(),
          remoteDataSource: ActiveEditSetsRemote(),
        ),
        sessionRepository: WorkoutSessionRepository(
          storageManager: UserStorageManager(),
          remoteDataSource: TemplateSessionRemote(),
        ),
      );
  void show() => emit(
    SessionExerciseLoaded(
      session: current,
      hasReferenceSession: false,
      rows: current.templateExerciseAssignmentsSnapshot
          .map(
            (a) => SessionExerciseRow(
              exerciseName: a.exerciseNameSnapshot,
              assignmentId: a.assignmentId,
              assignment: a,
              sets: logged
                  .where((s) => s.exerciseName == a.exerciseNameSnapshot)
                  .toList(),
              isReferenceOnly: false,
            ),
          )
          .toList(),
    ),
  );
  @override
  Future<void> loadForSession(WorkoutSession session) async => show();
  @override
  Future<void> refreshForSession(WorkoutSession session) async => show();
  @override
  Future<void> logSet({
    required WorkoutSession session,
    required String exerciseName,
    required double weight,
    required int reps,
    String? notes,
  }) async {
    logged.add(
      ExerciseSet(
        exerciseName: exerciseName,
        weight: weight,
        reps: reps,
        date: DateTime.now().add(Duration(microseconds: logged.length)),
        notes: notes,
        programId: session.programId,
        workoutTemplateId: session.workoutTemplateId,
        workoutSessionId: session.id,
      ),
    );
    show();
  }

  @override
  Future<void> editActiveExercises({
    required WorkoutSession session,
    required ActiveWorkoutEditAction action,
    ActiveWorkoutEditScope scope = ActiveWorkoutEditScope.sessionOnly,
    String? exerciseName,
    List<ExerciseLibraryItem> exercises = const [],
    String languageCode = 'en',
    List<String> orderedNames = const [],
    WorkoutTemplateExerciseAssignment? targets,
    CardioPlan? cardio,
  }) async {
    lastScope = scope;
    if (fail) throw StateError('write failed');
    mutations++;
    final items = [...current.templateExerciseAssignmentsSnapshot];
    final index = items.indexWhere(
      (a) => a.exerciseNameSnapshot == exerciseName,
    );
    switch (action) {
      case ActiveWorkoutEditAction.add:
        for (final item in exercises) {
          final added = WorkoutTemplateExerciseAssignment(
            assignmentId: item.id,
            exerciseId: item.id,
            exerciseNameSnapshot: item.nameForLanguage(languageCode),
            referenceType: 'builtIn',
          );
          items.add(
            cardio == null
                ? added
                : added.withActivity(type: ActivityType.cardio, cardio: cardio),
          );
        }
      case ActiveWorkoutEditAction.replace:
        items[index] = items[index].copyWith(
          exerciseId: exercises.single.id,
          exerciseNameSnapshot: exercises.single.nameForLanguage(languageCode),
        );
      case ActiveWorkoutEditAction.remove:
        items.removeAt(index);
      case ActiveWorkoutEditAction.reorder:
        final byName = {for (final a in items) a.exerciseNameSnapshot: a};
        items
          ..clear()
          ..addAll(orderedNames.map((n) => byName[n]!));
      case ActiveWorkoutEditAction.targets:
        items[index] = targets!;
      case ActiveWorkoutEditAction.applyProgram:
        break;
    }
    current = current.copyWith(templateExerciseAssignmentsSnapshot: items);
    show();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late WidgetActiveExercises exercises;
  late WorkoutSession session;
  late WorkoutSessionCubit lifecycle;
  late RestTimerCubit rest;
  late CombinedExerciseLibraryCatalog catalog;
  setUp(() async {
    WorkoutFeatures.debugCardioOverride = false;
    final templates = standardTemplateCatalog();
    final split = (await templates.loadTemplates()).first;
    final first = split.variants.first.days.first.exercises.first;
    final a = WorkoutTemplateExerciseAssignment(
      assignmentId: 'first',
      exerciseId: first.exercise.id,
      exerciseNameSnapshot: first.exercise.nameEn,
      referenceType: 'builtIn',
      workingSets: 2,
      targetRepsMin: 8,
      targetRepsMax: 12,
      restSeconds: 90,
    );
    session = WorkoutSession(
      id: 'active-widget',
      programId: 'program',
      workoutTemplateId: 'day',
      workoutNameSnapshot: 'Today',
      date: DateTime.now(),
      startedAt: DateTime.now(),
      status: 'inProgress',
      templateExerciseAssignmentsSnapshot: [a],
    );
    exercises = WidgetActiveExercises(session);
    lifecycle = WorkoutSessionCubit(repository: exercises.sessionRepository);
    rest = RestTimerCubit();
    final custom = WidgetCustomExercises();
    catalog = CombinedExerciseLibraryCatalog(
      builtInCatalog: ExerciseCatalogRepository(
        loadAsset: (path) async => File(path).readAsStringSync(),
      ),
      customExercises: custom,
    );
    await sl.reset();
    sl.registerSingleton<CombinedExerciseLibraryCatalog>(catalog);
    sl.registerSingleton<CustomExerciseRepository>(custom);
    sl.registerSingleton(
      ExerciseReferenceResolver(
        catalog: ExerciseCatalogRepository(
          loadAsset: (path) async => File(path).readAsStringSync(),
        ),
        customExercises: custom,
      ),
    );
  });
  tearDown(() async {
    await exercises.close();
    await lifecycle.close();
    await rest.close();
    await sl.reset();
    WorkoutFeatures.debugCardioOverride = null;
  });

  Widget app(String language) => MaterialApp(
    builder: AppFeedbackHost.builder,
    theme: language == 'ar' ? AppTheme.light : AppTheme.dark,
    locale: Locale(language),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Builder(
      builder: (ctx) => Scaffold(
        body: TextButton(
          key: const ValueKey('open'),
          onPressed: () => Navigator.push(
            ctx,
            MaterialPageRoute<void>(
              builder: (_) => MultiBlocProvider(
                providers: [
                  BlocProvider<SessionExerciseCubit>.value(value: exercises),
                  BlocProvider<WorkoutSessionCubit>.value(value: lifecycle),
                  BlocProvider<RestTimerCubit>.value(value: rest),
                ],
                child: ActiveWorkoutSessionScreen(session: session),
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  Future<void> open(WidgetTester tester, String language) async {
    await tester.pumpWidget(app(language));
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  AppLocalizations strings(WidgetTester tester) => AppLocalizations.of(
    tester.element(find.byType(ActiveWorkoutSessionScreen)),
  )!;
  Finder rowActions() => find.byWidgetPredicate(
    (w) =>
        w is PopupMenuButton<String> &&
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith(
          'session-exercise-actions-',
        ),
  );
  Future<void> menu(WidgetTester tester, String label) async {
    await tester.ensureVisible(rowActions().first);
    await tester.pumpAndSettle();
    await tester.tap(rowActions().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> scope(WidgetTester tester, {bool program = false}) async {
    final l10n = strings(tester);
    final group = tester.widget<RadioGroup<ActiveWorkoutEditScope>>(
      find.byType(RadioGroup<ActiveWorkoutEditScope>),
    );
    expect(group.groupValue, ActiveWorkoutEditScope.sessionOnly);
    if (program) await tester.tap(find.text(l10n.activeSessionAndProgram));
    await tester.tap(find.text(l10n.activeApplyEdit));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
  }

  Future<void> selectExercise(WidgetTester tester, String query) async {
    final l10n = strings(tester);
    final search = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.hintText == l10n.searchExerciseLibraryHint,
    );
    await tester.enterText(search, query);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    final checkbox = find
        .byWidgetPredicate((w) => w is Checkbox && w.onChanged != null)
        .first;
    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.addSelectedExercisesButton(1)));
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language: scopes default to session, picker adds in place, targets update stale route, navigation/resume',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 780));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await open(tester, language);
        final l10n = strings(tester);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('active-add-exercise')))
              .overlaps(
                tester.getRect(
                  find.byWidgetPredicate((w) => w is OutlinedButton).last,
                ),
              ),
          isFalse,
          reason: 'Add Exercise must not overlap the Cancel Workout action.',
        );
        expect(
          Directionality.of(
            tester.element(find.byType(ActiveWorkoutSessionScreen)),
          ),
          language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        await tester.tap(find.byKey(const ValueKey('active-add-exercise')));
        await tester.pumpAndSettle();
        await scope(tester);
        await selectExercise(tester, 'incline barbell');
        expect(exercises.mutations, 1);
        expect(exercises.lastScope, ActiveWorkoutEditScope.sessionOnly);
        expect(find.byType(ActiveWorkoutSessionScreen), findsOneWidget);
        expect(
          exercises.current.templateExerciseAssignmentsSnapshot,
          hasLength(2),
        );
        final originalId = exercises
            .current
            .templateExerciseAssignmentsSnapshot
            .first
            .assignmentId;
        await menu(tester, l10n.replaceExerciseAction);
        await scope(tester);
        await selectExercise(tester, 'barbell squat');
        expect(exercises.mutations, 2);
        expect(
          exercises
              .current
              .templateExerciseAssignmentsSnapshot
              .first
              .assignmentId,
          originalId,
        );
        expect(find.byType(ActiveWorkoutSessionScreen), findsOneWidget);
        await menu(tester, l10n.editExerciseTargets);
        await scope(tester, program: true);
        await tester.enterText(find.byKey(const ValueKey('target-0')), '4');
        await tester.tap(find.text(l10n.save));
        await tester.pumpAndSettle();
        expect(exercises.lastScope, ActiveWorkoutEditScope.sessionAndProgram);
        expect(
          exercises
              .current
              .templateExerciseAssignmentsSnapshot
              .first
              .workingSets,
          4,
        );
        expect(find.textContaining(language == 'ar' ? '4' : '4'), findsWidgets);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
        expect(
          exercises
              .current
              .templateExerciseAssignmentsSnapshot
              .first
              .workingSets,
          4,
        );
        // Template exercises now show their planned set rows, so both cards
        // may not fit on screen at once; scroll through and count them.
        final rowKeys = <Key>{};
        for (var i = 0; i < 6; i++) {
          rowKeys.addAll(tester.widgetList(rowActions()).map((w) => w.key!));
          await tester.drag(
            find.byKey(const PageStorageKey('active-exercises')),
            const Offset(0, -300),
          );
          await tester.pumpAndSettle();
        }
        expect(rowKeys, hasLength(2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'template sets are ready to fill: weight + reps, one tap saves and marks done',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await open(tester, 'en');
      final l10n = strings(tester);
      final name = session
          .templateExerciseAssignmentsSnapshot
          .first
          .exerciseNameSnapshot;
      Finder planned(int n) => find.byKey(ValueKey('planned-set-$name-$n'));

      // workingSets: 2 → both sets are ready, with the 8–12 target shown.
      expect(planned(1), findsOneWidget);
      expect(planned(2), findsOneWidget);
      expect(planned(3), findsNothing);
      expect(find.textContaining('8–12'), findsWidgets);

      await tester.enterText(
        find.byKey(const ValueKey('planned-weight-1')),
        '62.5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('planned-reps-1')),
        '10',
      );
      await tester.tap(find.byKey(const ValueKey('planned-save-1')));
      await tester.pump();
      await tester.pump();

      expect(exercises.logged, hasLength(1));
      expect(exercises.logged.single.weight, 62.5);
      expect(exercises.logged.single.reps, 10);
      // The filled slot became a real set, already marked done.
      expect(planned(1), findsNothing);
      expect(planned(2), findsOneWidget);
      final done = tester.widget<Checkbox>(find.byType(Checkbox).first);
      expect(done.value, isTrue);
      expect(rest.state.isRunning, isTrue);

      // Same rest rule as "+": set 2 can't be saved until the rest is over.
      await tester.enterText(
        find.byKey(const ValueKey('planned-weight-2')),
        '62.5',
      );
      await tester.enterText(find.byKey(const ValueKey('planned-reps-2')), '9');
      await tester.tap(find.byKey(const ValueKey('planned-save-2')));
      await tester.pump();
      expect(exercises.logged, hasLength(1));
      expect(find.text(l10n.waitForRestTimerLabel), findsOneWidget);

      // Extra sets beyond the plan are still available.
      expect(find.byIcon(Icons.hourglass_top), findsWidgets);
      rest.stop();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a planned set rejects missing reps without logging', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await open(tester, 'ar');
    await tester.enterText(
      find.byKey(const ValueKey('planned-weight-1')),
      '40',
    );
    await tester.tap(find.byKey(const ValueKey('planned-save-1')));
    await tester.pump();
    expect(exercises.logged, isEmpty);
    expect(find.text(strings(tester).unableToLogSetError), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'logged exercise removal is blocked before picker/scope and shows localized explanation',
    (tester) async {
      exercises.logged = [
        ExerciseSet(
          exerciseName: session
              .templateExerciseAssignmentsSnapshot
              .first
              .exerciseNameSnapshot,
          weight: 30,
          reps: 8,
          date: DateTime.now(),
        ),
      ];
      await open(tester, 'en');
      final l10n = strings(tester);
      await menu(tester, l10n.removeExerciseAction);
      expect(find.text(l10n.activeLoggedExerciseProtected), findsOneWidget);
      expect(find.byType(RadioGroup<ActiveWorkoutEditScope>), findsNothing);
      expect(exercises.mutations, 0);
      expect(find.textContaining('30'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed mutation keeps exercise visible and permits retry', (
    tester,
  ) async {
    await open(tester, 'en');
    final l10n = strings(tester);
    exercises.fail = true;
    await menu(tester, l10n.removeExerciseAction);
    await scope(tester);
    expect(find.text(l10n.exerciseLibrarySaveError), findsOneWidget);
    expect(exercises.current.templateExerciseAssignmentsSnapshot, hasLength(1));
    exercises.fail = false;
    await menu(tester, l10n.removeExerciseAction);
    await scope(tester);
    expect(exercises.current.templateExerciseAssignmentsSnapshot, isEmpty);
    expect(exercises.mutations, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final language in ['en', 'ar']) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        '$language · text ×$scale: logging a set on a small phone with the keyboard open',
        (tester) async {
          useSmallPhone(tester, textScale: scale);
          await open(tester, language);
          expectNoOverflow(tester);

          final screen = find.byKey(const PageStorageKey('active-exercises'));
          final weight = find.byKey(const ValueKey('planned-weight-1'));
          await tester.dragUntilVisible(weight, screen, const Offset(0, -80));
          await tester.pumpAndSettle();
          await tester.showKeyboard(weight);
          await setKeyboard(tester, open: true);
          expectNoOverflow(tester);
          // The field being typed into is visible above the keyboard.
          final field = tester.getRect(weight);
          expect(
            field.bottom,
            lessThanOrEqualTo(smallPhone.height - keyboardHeight),
          );
          expect(field.top, greaterThan(statusBar + kToolbarHeight - 1));

          // Rest-timer fields too.
          await setKeyboard(tester, open: false);
          final minutes = find.byKey(const ValueKey('rest-minutes-input'));
          await tester.dragUntilVisible(minutes, screen, const Offset(0, 80));
          await tester.pumpAndSettle();
          await tester.showKeyboard(minutes);
          await setKeyboard(tester, open: true);
          expectNoOverflow(tester);
          await setKeyboard(tester, open: false);
          expectNoOverflow(tester);

          // Session note dialog with the keyboard open.
          await setKeyboard(tester, open: false);
          await tester.tap(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(PopupMenuButton<String>),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(strings(tester).sessionNoteTooltip));
          await tester.pumpAndSettle();
          await setKeyboard(tester, open: true);
          expectNoOverflow(tester);
          expectActionsAboveKeyboard(tester);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets('each exercise shows its library picture; tapping it opens the details', (
    tester,
  ) async {
    await open(tester, 'en');
    // The catalog is read from disk: let the lookup finish.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    final name = session.templateExerciseAssignmentsSnapshot.first.exerciseNameSnapshot;
    final thumbnail = find.byKey(ValueKey('session-exercise-thumbnail-$name'));
    expect(thumbnail, findsOneWidget);
    expect(
      find.descendant(
        of: thumbnail,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'exercise-thumbnail-lib/assets/',
              ),
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(thumbnail);
    await tester.pumpAndSettle();
    final detail = tester.widget<ExerciseDetailScreen>(
      find.byType(ExerciseDetailScreen),
    );
    expect(
      detail.exercise.id,
      session.templateExerciseAssignmentsSnapshot.first.exerciseId,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'drag-reordering an exercise: no errors while dragging, then saved',
    (tester) async {
      // Regression: the dragged copy is built in the navigator's overlay,
      // above this route's providers; its rest-timer button threw on every
      // frame, which in debug froze the app until Android killed it.
      tester.view
        ..physicalSize = const Size(412, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final first = exercises.current.templateExerciseAssignmentsSnapshot.single;
      exercises.current = exercises.current.copyWith(
        templateExerciseAssignmentsSnapshot: [
          first,
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'second',
            exerciseId: 'repdb:close-grip-lat-pulldown',
            exerciseNameSnapshot: 'Close-grip pulldown',
            referenceType: 'builtIn',
            workingSets: 2,
            targetRepsMin: 8,
            targetRepsMax: 12,
            restSeconds: 90,
          ),
        ],
      );
      await open(tester, 'en');
      final l10n = strings(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.drag_indicator).first),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(0, 15));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: 'frame $i of the drag');
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Dropping asks where the new order applies, then saves it.
      await tester.tap(find.text(l10n.activeApplyEdit));
      await tester.pumpAndSettle();
      expect(exercises.lastScope, ActiveWorkoutEditScope.sessionOnly);
      expect(
        exercises.current.templateExerciseAssignmentsSnapshot.map(
          (a) => a.exerciseNameSnapshot,
        ),
        ['Close-grip pulldown', first.exerciseNameSnapshot],
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the workout clock still ticks every second', (tester) async {
    await open(tester, 'en');
    String clock() => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((text) => RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(text));
    final before = clock();
    // The clock reads the wall time; let a real second pass, then tick.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(clock(), isNot(before));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('Add activity during a workout (cardio on)', () {
    setUp(() => WorkoutFeatures.debugCardioOverride = true);

    Future<void> openCardioLibrary(WidgetTester tester, {bool program = false}) async {
      await tester.tap(find.byKey(const ValueKey('active-add-exercise')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-activity-cardio')));
      await tester.pumpAndSettle();
      await scope(tester, program: program);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.byType(CardioLibraryScreen), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(CardioLibraryScreen),
          matching: find.byType(TextField),
        ),
        'shadow',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('cardio-item-cardio:shadow-boxing')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('en: the button offers strength, cardio and My library; cardio '
        'is added with its saved settings and gets its timer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await open(tester, 'en');
      final l10n = strings(tester);
      expect(find.text(l10n.addActivityButton), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('active-add-exercise')));
      await tester.pumpAndSettle();
      for (final key in [
        'add-activity-strength',
        'add-activity-cardio',
        'add-activity-library',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      await tester.tapAt(const Offset(5, 5)); // close the sheet
      await tester.pumpAndSettle();

      await openCardioLibrary(tester, program: true);
      final save = find.byKey(const ValueKey('cardio-config-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(exercises.mutations, 1);
      expect(exercises.lastScope, ActiveWorkoutEditScope.sessionAndProgram);
      final added = exercises.current.templateExerciseAssignmentsSnapshot.last;
      expect(added.exerciseId, 'cardio:shadow-boxing');
      expect(added.type, ActivityType.cardio);
      expect(added.cardio!.durationSeconds, 1200);
      expect(
        find.byKey(const ValueKey('cardio-open-cardio:shadow-boxing')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('ar: Cancel in the settings adds nothing; strength through the '
        'sheet works as before', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await open(tester, 'ar');
      await openCardioLibrary(tester);
      final cancel = find.byKey(const ValueKey('cardio-config-cancel'));
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(exercises.mutations, 0);
      expect(exercises.current.templateExerciseAssignmentsSnapshot, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('active-add-exercise')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-activity-strength')));
      await tester.pumpAndSettle();
      await scope(tester);
      await selectExercise(tester, 'incline barbell');
      expect(exercises.mutations, 1);
      expect(exercises.current.templateExerciseAssignmentsSnapshot, hasLength(2));
      expect(
        exercises.current.templateExerciseAssignmentsSnapshot.last.type,
        ActivityType.strength,
      );
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
