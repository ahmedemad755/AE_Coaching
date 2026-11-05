import 'dart:io';
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
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/active_workout_session_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'active_workout_edit_service_test.dart' show ActiveEditSetsRemote;
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
  Future<void> editActiveExercises({
    required WorkoutSession session,
    required ActiveWorkoutEditAction action,
    ActiveWorkoutEditScope scope = ActiveWorkoutEditScope.sessionOnly,
    String? exerciseName,
    List<ExerciseLibraryItem> exercises = const [],
    String languageCode = 'en',
    List<String> orderedNames = const [],
    WorkoutTemplateExerciseAssignment? targets,
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
          items.add(
            WorkoutTemplateExerciseAssignment(
              assignmentId: item.id,
              exerciseId: item.id,
              exerciseNameSnapshot: item.nameForLanguage(languageCode),
              referenceType: 'builtIn',
            ),
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
  });
  tearDown(() async {
    await exercises.close();
    await lifecycle.close();
    await rest.close();
    await sl.reset();
  });

  Widget app(String language) => MaterialApp(
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
        expect(rowActions(), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

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
}
