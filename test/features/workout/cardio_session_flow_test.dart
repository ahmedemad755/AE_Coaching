import 'package:ae_coaching/core/feedback/feedback_host.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_run.dart';
import 'package:ae_coaching/features/workout/domain/services/workout_progress_comparison_service.dart';
import 'package:ae_coaching/features/workout/domain/workout_features.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/active_workout_session_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/cardio_session_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoSessions implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSessions() async => [];
}

class _NoSets implements WorkoutRemoteDataSource {
  @override
  Future<void> syncSet(String key, ExerciseSet set) async {}

  @override
  Future<void> deleteSet(String key) async {}

  @override
  Future<void> deleteMultipleSets(List<String> keys) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSets() async => [];
}

/// The session in memory; timers are saved the way the real one saves them.
class _Sessions extends WorkoutSessionRepository {
  _Sessions(this.session)
    : super(
        remoteDataSource: _NoSessions(),
        storageManager: UserStorageManager(),
        uidOverride: () => 'cardio-flow-user',
      );

  WorkoutSession session;
  int cancelled = 0;

  @override
  Future<WorkoutSession> saveActivityRun({
    required String sessionId,
    required String assignmentId,
    required CardioRun run,
  }) async {
    session = session.copyWith(
      activityRuns: {...session.activityRuns, assignmentId: run.toMap()},
    );
    return session;
  }

  @override
  Future<WorkoutSession> cancelWorkoutSession(String sessionId) async {
    cancelled++;
    session = session.copyWith(status: WorkoutSessionStatus.cancelled.value);
    return session;
  }

  @override
  Future<WorkoutSession> completeWorkoutSession({
    required String sessionId,
    required double totalVolume,
  }) async {
    session = session.copyWith(
      status: WorkoutSessionStatus.completed.value,
      completedAt: DateTime.now(),
      totalVolume: totalVolume,
    );
    return session;
  }
}

/// Rows straight from the session's day, in its saved order.
class _Rows extends SessionExerciseCubit {
  _Rows({
    required super.repository,
    required _Sessions super.sessionRepository,
    required this.sets,
  }) : sessions = sessionRepository;

  final _Sessions sessions;
  final List<ExerciseSet> sets;

  void _show() => emit(
    SessionExerciseLoaded(
      rows: [
        for (final a in sessions.session.templateExerciseAssignmentsSnapshot)
          SessionExerciseRow(
            exerciseName: a.exerciseNameSnapshot,
            assignmentId: a.assignmentId,
            assignment: a,
            sets: sets
                .where((s) => s.exerciseName == a.exerciseNameSnapshot)
                .toList(),
            isReferenceOnly: false,
          ),
      ],
      hasReferenceSession: false,
      session: sessions.session,
    ),
  );

  @override
  Future<void> loadForSession(WorkoutSession session) async => _show();

  @override
  Future<void> refreshForSession(WorkoutSession session) async => _show();

  @override
  Future<List<ExerciseSet>> getValidSetsForSession(
    WorkoutSession session,
  ) async => sets;

  @override
  Future<WorkoutCompletionResult> buildCompletionSummary(
    WorkoutSession finished,
  ) async => WorkoutCompletionResult(
    progressSummary: WorkoutProgressSummary(
      sessionId: finished.id,
      previousSessionId: null,
      currentTotalVolume: finished.totalVolume,
      previousTotalVolume: null,
      volumeDeltaPercent: null,
      exerciseResults: const [],
    ),
    personalRecords: const [],
  );
}

void main() {
  const countdown = CardioPlan(
    mode: CardioMode.countdown,
    durationSeconds: 1200,
  );
  final bench = WorkoutTemplateExerciseAssignment(
    assignmentId: 'bench',
    exerciseId: 'repdb:bench-press',
    exerciseNameSnapshot: 'Bench Press',
    referenceType: 'builtIn',
  );
  final running = WorkoutTemplateExerciseAssignment(
    assignmentId: 'run',
    exerciseId: 'repdb:running',
    exerciseNameSnapshot: 'Running',
    referenceType: 'builtIn',
  ).withActivity(type: ActivityType.cardio, cardio: countdown);

  late _Sessions sessions;
  late _Rows rows;
  late WorkoutSessionCubit lifecycle;
  late RestTimerCubit rest;
  late List<ExerciseSet> sets;

  void setUpSession(
    List<WorkoutTemplateExerciseAssignment> day, {
    Map<String, Map<String, Object?>> runs = const {},
  }) {
    sets = [];
    sessions = _Sessions(
      WorkoutSession(
        id: 's1',
        programId: 'p',
        workoutTemplateId: 'd',
        workoutNameSnapshot: 'Push Day',
        date: DateTime.now(),
        startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        status: WorkoutSessionStatus.inProgress.value,
        templateExerciseAssignmentsSnapshot: day,
        activityRuns: runs,
      ),
    );
    lifecycle = WorkoutSessionCubit(repository: sessions);
    rows = _Rows(
      repository: SessionExerciseRepository(
        remoteDataSource: _NoSets(),
        storageManager: UserStorageManager(),
        uidOverride: () => 'cardio-flow-user',
      ),
      sessionRepository: sessions,
      sets: sets,
    );
    rest = RestTimerCubit();
  }

  setUp(() {
    // Sounds and keep-screen-on are best effort; silence them here.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('ae_coaching/rest_timer'),
          (_) async => null,
        );
  });

  tearDown(() async {
    WorkoutFeatures.debugCardioOverride = null;
    await lifecycle.close();
    await rows.close();
    await rest.close();
  });

  Future<AppLocalizations> open(
    WidgetTester tester, {
    String language = 'en',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: AppFeedbackHost.builder,
        theme: AppTheme.dark,
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {AppNavigator.home: (_) => const Scaffold(body: Text('HOME'))},
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider<WorkoutSessionCubit>.value(value: lifecycle),
                      BlocProvider<SessionExerciseCubit>.value(value: rows),
                      BlocProvider<RestTimerCubit>.value(value: rest),
                    ],
                    child: ActiveWorkoutSessionScreen(
                      session: sessions.session,
                    ),
                  ),
                ),
              ),
              child: const Text('Open workout'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open workout'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    return AppLocalizations.of(
      tester.element(find.byType(ActiveWorkoutSessionScreen)),
    )!;
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  testWidgets('in the saved order, cardio gets its timer (no sets), strength '
      'keeps its sets; the timer started in it shows on the workout', (
    tester,
  ) async {
    setUpSession([bench, running]);
    final l10n = await open(tester);
    final cardioRow = find.byKey(const ValueKey('session-exercise-Running'));
    final benchRow = find.byKey(const ValueKey('session-exercise-Bench Press'));
    expect(
      tester.getTopLeft(benchRow).dy,
      lessThan(tester.getTopLeft(cardioRow).dy),
    );
    expect(
      find.descendant(
        of: cardioRow,
        matching: find.byTooltip(l10n.addSetTooltip),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: benchRow,
        matching: find.byTooltip(l10n.addSetTooltip),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.cardioStatusNotStarted), findsOneWidget);

    final openTimer = find.byKey(const ValueKey('cardio-open-run'));
    expect(tester.widget<IconButton>(openTimer).onPressed, isNotNull);
    await tester.ensureVisible(openTimer);
    await tester.pumpAndSettle();
    await tester.tap(openTimer);
    await tester.pumpAndSettle();
    expect(find.byType(CardioSessionScreen), findsOneWidget);
    expect(find.text(l10n.cardioLastActivity), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cardio-start')));
    await tester.pump();
    expect(sessions.session.runFor('run').status, CardioRunStatus.running);
    await tester.pageBack();
    await frames(tester);
    expect(find.byType(CardioSessionScreen), findsNothing);
    expect(
      find.textContaining(l10n.cardioStatusRunning('').trim()),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('a workout of cardio only is finished and kept, with its '
      'result in the summary', (tester) async {
    final done = CardioRun.planned(
      plan: countdown,
      name: 'Running',
      exerciseId: 'repdb:running',
    ).start(0).settle(1200 * 1000, countdown);
    setUpSession([running], runs: {'run': done.toMap()});
    final l10n = await open(tester);
    await tester.tap(find.text(l10n.finishWorkoutButton));
    await frames(tester);
    expect(find.text(l10n.discardEmptyWorkoutTitle), findsNothing);
    expect(find.text(l10n.finishWorkoutConfirmCardioBody), findsOneWidget);
    await tester.tap(
      find.widgetWithText(ElevatedButton, l10n.finishWorkoutButton).last,
    );
    await frames(tester);
    expect(sessions.session.isCompleted, isTrue);
    expect(sessions.cancelled, 0);
    expect(find.text(l10n.completionCardioTitle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('completion-cardio-Running')),
        matching: find.text(l10n.cardioStatusCompleted('20:00')),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('skipped cardio is not a workout: Finish still offers to '
      'discard an empty workout', (tester) async {
    final skipped = const CardioRun().skip(0);
    setUpSession([running], runs: {'run': skipped.toMap()});
    final l10n = await open(tester);
    expect(find.text(l10n.cardioStatusSkipped), findsOneWidget);
    await tester.tap(find.text(l10n.finishWorkoutButton));
    await frames(tester);
    expect(find.text(l10n.discardEmptyWorkoutTitle), findsOneWidget);
    await tester.tap(find.text(l10n.keepTrainingButton));
    await frames(tester);
  });

  testWidgets('cardio off (release builds): the row is shown as before', (
    tester,
  ) async {
    WorkoutFeatures.debugCardioOverride = false;
    setUpSession([running]);
    final l10n = await open(tester);
    expect(find.byKey(const ValueKey('cardio-open-run')), findsNothing);
    expect(find.byTooltip(l10n.addSetTooltip), findsOneWidget);
  });

  // A debug build stops on an error thrown while the dragged copy is drawn
  // (the copy lives in the overlay, outside the screen's providers), and
  // the stopped app then hits "not responding" under the finger.
  for (final language in ['en', 'ar']) {
    for (final name in ['Bench Press', 'Running']) {
      testWidgets('$language: dragging $name in the workout draws its moving '
          'copy without errors', (tester) async {
        setUpSession([bench, running]);
        await open(tester, language: language);
        final handle = find.descendant(
          of: find.byKey(ValueKey('session-exercise-$name')),
          matching: find.byIcon(Icons.drag_indicator),
        );
        await tester.ensureVisible(handle);
        await frames(tester);
        final gesture = await tester.startGesture(tester.getCenter(handle));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        for (var step = 0; step < 6; step++) {
          await gesture.moveBy(Offset(0, name == 'Running' ? -12 : 12));
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull);
        }
        // The moving copy is drawn, with the screen's providers handed over.
        expect(find.byType(MultiBlocProvider), findsNWidgets(2));
        await gesture.cancel();
        await frames(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      });
    }
  }
}
