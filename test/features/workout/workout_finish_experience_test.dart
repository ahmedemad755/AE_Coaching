import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/active_workout_session_screen.dart';
import 'package:ae_coaching/features/workout/domain/services/personal_record_detection_service.dart';
import 'package:ae_coaching/features/workout/domain/services/workout_progress_comparison_service.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptySessionRemoteDataSource implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSessions() async => [];
}

class _EmptySetsRemoteDataSource implements WorkoutRemoteDataSource {
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

class _InMemorySessionRepository extends WorkoutSessionRepository {
  WorkoutSession session;
  int cancellationCount = 0;
  int completionCount = 0;
  int inactivitySyncCount = 0;
  bool failCompletion = false;

  _InMemorySessionRepository(this.session)
    : super(
        remoteDataSource: _EmptySessionRemoteDataSource(),
        storageManager: UserStorageManager(),
        uidOverride: () => 'finish-test-user',
      );

  @override
  Future<WorkoutSession> cancelWorkoutSession(String sessionId) async {
    cancellationCount++;
    session = session.copyWith(status: WorkoutSessionStatus.cancelled.value);
    return session;
  }

  @override
  Future<WorkoutSession> completeWorkoutSession({
    required String sessionId,
    required double totalVolume,
  }) async {
    completionCount++;
    if (failCompletion) throw StateError('simulated completion failure');
    session = session.copyWith(
      status: WorkoutSessionStatus.completed.value,
      completedAt: DateTime.now(),
      totalVolume: totalVolume,
    );
    inactivitySyncCount++;
    return session;
  }
}

class _InMemorySessionExerciseCubit extends SessionExerciseCubit {
  final List<ExerciseSet> sets;
  final List<ExerciseSet> previousSets;

  _InMemorySessionExerciseCubit({
    required super.repository,
    required super.sessionRepository,
    required this.sets,
    this.previousSets = const [],
  });

  @override
  Future<void> loadForSession(WorkoutSession session) async {
    final grouped = <String, List<ExerciseSet>>{};
    for (final set in sets) {
      grouped.putIfAbsent(set.exerciseName, () => []).add(set);
    }
    emit(
      SessionExerciseLoaded(
        rows: [
          for (final entry in grouped.entries)
            SessionExerciseRow(
              exerciseName: entry.key,
              sets: entry.value,
              isReferenceOnly: false,
              previousSets: previousSets
                  .where((set) => set.exerciseName == entry.key)
                  .toList(),
            ),
        ],
        hasReferenceSession: false,
      ),
    );
  }

  @override
  Future<List<ExerciseSet>> getValidSetsForSession(
    WorkoutSession session,
  ) async => sets;

  @override
  Future<WorkoutCompletionResult> buildCompletionSummary(
    WorkoutSession finishedSession,
  ) async {
    final summary = WorkoutProgressSummary(
      sessionId: finishedSession.id,
      previousSessionId: null,
      currentTotalVolume: finishedSession.totalVolume,
      previousTotalVolume: null,
      volumeDeltaPercent: null,
      exerciseResults: const [],
    );
    final records = sets.isEmpty
        ? const <PersonalRecordResult>[]
        : [
            PersonalRecordResult(
              exerciseName: sets.first.exerciseName,
              type: PersonalRecordType.heaviestWeight,
              recordSet: sets.first,
              previousBest: 0,
              newBest: sets.first.weight,
            ),
          ];
    return WorkoutCompletionResult(
      progressSummary: summary,
      personalRecords: records,
    );
  }
}

void main() {
  late _InMemorySessionRepository sessionRepository;
  late WorkoutSessionCubit sessionCubit;
  late _InMemorySessionExerciseCubit exerciseCubit;
  late RestTimerCubit restTimerCubit;
  late WorkoutSession session;
  late List<ExerciseSet> sets;
  late ValueNotifier<ThemeMode> themeMode;

  Future<void> pumpFrames(WidgetTester tester) async {
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  setUp(() async {
    sets = [];
    themeMode = ValueNotifier(ThemeMode.light);
    session = WorkoutSession(
      id: 'session-1',
      programId: 'program-a',
      workoutTemplateId: 'day-a',
      workoutNameSnapshot: 'Push Day',
      date: DateTime.now(),
      startedAt: DateTime.now().subtract(const Duration(minutes: 42)),
      status: WorkoutSessionStatus.inProgress.value,
      totalVolume: 0,
    );
    sessionRepository = _InMemorySessionRepository(session);
    sessionCubit = WorkoutSessionCubit(repository: sessionRepository);
    exerciseCubit = _InMemorySessionExerciseCubit(
      repository: SessionExerciseRepository(
        remoteDataSource: _EmptySetsRemoteDataSource(),
        storageManager: UserStorageManager(),
        uidOverride: () => 'finish-test-user',
      ),
      sessionRepository: sessionRepository,
      sets: sets,
      previousSets: <ExerciseSet>[],
    );
    restTimerCubit = RestTimerCubit();
  });

  tearDown(() async {
    await sessionCubit.close();
    await exerciseCubit.close();
    await restTimerCubit.close();
    themeMode.dispose();
  });

  Widget app() => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeMode,
    builder: (context, mode, _) => MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {
        AppNavigator.home: (_) => const Scaffold(body: Text('HOME SCREEN')),
      },
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => MultiBlocProvider(
                    providers: [
                      BlocProvider<WorkoutSessionCubit>.value(
                        value: sessionCubit,
                      ),
                      BlocProvider<SessionExerciseCubit>.value(
                        value: exerciseCubit,
                      ),
                      BlocProvider<RestTimerCubit>.value(value: restTimerCubit),
                    ],
                    child: ActiveWorkoutSessionScreen(session: session),
                  ),
                ),
              ),
              child: const Text('Open workout'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> openWorkout(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('Open workout'));
    await pumpFrames(tester);
  }

  Finder buttonWithTooltip(String label) => find.ancestor(
    of: find.byTooltip(label),
    matching: find.byType(IconButton),
  );

  void addSet(String name, double weight, int reps, {String? notes}) {
    sets.add(
      ExerciseSet(
        exerciseName: name,
        weight: weight,
        reps: reps,
        date: DateTime.now(),
        programId: session.programId,
        workoutTemplateId: session.workoutTemplateId,
        workoutSessionId: session.id,
        notes: notes,
      ),
    );
  }

  testWidgets('set notes are displayed below their weight and reps', (
    tester,
  ) async {
    const note = 'Keep my shoulders relaxed';
    addSet('Bench Press', 40, 8, notes: note);
    await openWorkout(tester);

    expect(find.text(note), findsOneWidget);
    expect(find.text('40.0kg × 8'), findsOneWidget);
  });

  testWidgets('previous workout notes appear with the same exercise', (
    tester,
  ) async {
    addSet('Bench Press', 45, 8);
    exerciseCubit.previousSets.add(
      ExerciseSet(
        exerciseName: 'Bench Press',
        weight: 42.5,
        reps: 8,
        date: DateTime(2025, 5, 1),
        programId: session.programId,
        workoutTemplateId: session.workoutTemplateId,
        workoutSessionId: 'previous-session',
        notes: 'Keep elbows tucked',
      ),
    );
    await openWorkout(tester);

    expect(find.text('Keep elbows tucked'), findsOneWidget);
    expect(find.text('42.5kg × 8'), findsOneWidget);
  });

  testWidgets('empty Finish offers Keep Training and Discard exactly once', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await openWorkout(tester);

    final finishButton = find.text(l10n.finishWorkoutButton);
    await tester.tap(finishButton, warnIfMissed: false);
    await tester.pump();
    await tester.tap(finishButton, warnIfMissed: false);
    await pumpFrames(tester);

    expect(find.text(l10n.discardEmptyWorkoutTitle), findsOneWidget);
    expect(find.text(l10n.keepTrainingButton), findsOneWidget);
    expect(find.text(l10n.discardWorkoutButton), findsOneWidget);

    await tester.tap(find.text(l10n.keepTrainingButton));
    await pumpFrames(tester);
    expect(sessionRepository.session.isInProgress, isTrue);
    expect(sessionRepository.cancellationCount, 0);
    expect(sessionRepository.inactivitySyncCount, 0);

    await tester.tap(find.text(l10n.finishWorkoutButton));
    await pumpFrames(tester);
    await tester.tap(find.text(l10n.discardWorkoutButton));
    await pumpFrames(tester);

    expect(sessionRepository.session.isCancelled, isTrue);
    expect(sessionRepository.cancellationCount, 1);
    expect(sessionRepository.completionCount, 0);
    expect(sessionRepository.inactivitySyncCount, 0);
    expect(find.text('Open workout'), findsOneWidget);
  });

  testWidgets('active set-entry values survive a live theme change', (
    tester,
  ) async {
    addSet('Bench Press', 40, 8);
    await openWorkout(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.enterText(
      find.byKey(const ValueKey('rest-minutes-input')),
      '0',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rest-seconds-input')),
      '1',
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();

    await tester.tap(find.byTooltip(l10n.addSetTooltip));
    await tester.pumpAndSettle();
    final setFields = find.descendant(
      of: find.byType(Dialog).last,
      matching: find.byType(TextField),
    );
    await tester.enterText(setFields.at(0), '52.5');
    await tester.enterText(setFields.at(1), '9');
    themeMode.value = ThemeMode.dark;
    await pumpFrames(tester);

    expect(find.text('52.5'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    final dialogMaterial = find.descendant(
      of: find.byType(Dialog).last,
      matching: find.byType(Material),
    );
    expect(
      tester.widget<Material>(dialogMaterial.first).color,
      AppTheme.dark.colorScheme.surface,
    );
  });

  testWidgets(
    'marking a recorded set done starts and displays its rest countdown',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      addSet('Bench Press', 40, 8);
      await openWorkout(tester);

      await tester.enterText(
        find.byKey(const ValueKey('rest-minutes-input')),
        '1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('rest-seconds-input')),
        '0',
      );
      expect(
        restTimerCubit.state.configuredDuration,
        const Duration(minutes: 1),
      );
      final blockedAdd = find.byTooltip(l10n.markPreviousSetDoneLabel);
      expect(blockedAdd, findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              buttonWithTooltip(l10n.markPreviousSetDoneLabel),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(restTimerCubit.state.isRunning, isTrue);
      expect(restTimerCubit.state.remaining, const Duration(minutes: 1));
      expect(find.text(l10n.setDoneLabel), findsOneWidget);
      final waitingAdd = find.byTooltip(l10n.waitForRestTimerLabel);
      expect(waitingAdd, findsOneWidget);
      expect(
        tester
            .widget<IconButton>(buttonWithTooltip(l10n.waitForRestTimerLabel))
            .onPressed,
        isNull,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(restTimerCubit.state.remaining.inSeconds, 59);
      expect(restTimerCubit.state.progress, lessThan(1));
      expect(find.text('00:59'), findsOneWidget);
      restTimerCubit.stop();
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(buttonWithTooltip(l10n.waitForRestTimerLabel))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('zero-length rest does not leave the next set locked', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    addSet('Bench Press', 40, 8);
    await openWorkout(tester);

    await tester.enterText(
      find.byKey(const ValueKey('rest-minutes-input')),
      '0',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rest-seconds-input')),
      '0',
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(restTimerCubit.state.isRunning, isFalse);
    expect(
      tester
          .widget<IconButton>(buttonWithTooltip(l10n.addSetTooltip))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('rest countdown completion plays the Android notification tone', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    addSet('Bench Press', 40, 8);
    await openWorkout(tester);
    await tester.enterText(
      find.byKey(const ValueKey('rest-minutes-input')),
      '0',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rest-seconds-input')),
      '1',
    );

    const channel = MethodChannel('ae_coaching/rest_timer');
    var soundPlayed = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'playNotificationSound');
          soundPlayed = true;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(buttonWithTooltip(l10n.waitForRestTimerLabel))
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();

    expect(restTimerCubit.state.isRunning, isFalse);
    expect(soundPlayed, isTrue);
    expect(
      tester
          .widget<IconButton>(buttonWithTooltip(l10n.addSetTooltip))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'valid completion celebrates with session metrics and PR results',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      addSet('Bench Press', 60, 8);
      addSet('Bench Press', 62.5, 8);
      addSet('Lat Pulldown', 30, 10);
      await openWorkout(tester);

      await tester.tap(find.text(l10n.finishWorkoutButton));
      await pumpFrames(tester);
      await tester.tap(find.text(l10n.finishWorkoutButton).last);
      await pumpFrames(tester);

      expect(sessionRepository.session.isCompleted, isTrue);
      expect(sessionRepository.session.totalVolume, 1280);
      expect(sessionRepository.completionCount, 1);
      expect(sessionRepository.inactivitySyncCount, 1);
      expect(find.text(l10n.workoutCelebrationHeading), findsOneWidget);
      expect(find.text(l10n.workoutCelebrationSubtitle), findsOneWidget);
      expect(find.text('Push Day'), findsNWidgets(2));
      expect(find.text(l10n.completionExercisesLabel), findsOneWidget);
      expect(find.text(l10n.completionSetsLabel), findsOneWidget);
      expect(find.text('1280 kg'), findsOneWidget);
      expect(find.text(l10n.workoutDurationLabel), findsOneWidget);
      expect(find.text('42 min'), findsOneWidget);
      expect(find.text(l10n.newPersonalRecordsLabel), findsOneWidget);

      final exerciseMetric = find.ancestor(
        of: find.text(l10n.completionExercisesLabel),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: exerciseMetric, matching: find.text('2')),
        findsOneWidget,
      );
      final setMetric = find.ancestor(
        of: find.text(l10n.completionSetsLabel),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: setMetric, matching: find.text('3')),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.backToHomeButton));
      await pumpFrames(tester);
      expect(find.text('HOME SCREEN'), findsOneWidget);
    },
  );

  testWidgets('completion failure never shows the celebration', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    addSet('Bench Press', 60, 8);
    sessionRepository.failCompletion = true;
    await openWorkout(tester);

    await tester.tap(find.text(l10n.finishWorkoutButton));
    await pumpFrames(tester);
    await tester.tap(find.text(l10n.finishWorkoutButton).last);
    await pumpFrames(tester);

    expect(find.text(l10n.workoutCelebrationHeading), findsNothing);
    expect(find.text(l10n.unableToFinishWorkoutError), findsOneWidget);
    expect(sessionRepository.completionCount, 1);
    expect(sessionRepository.inactivitySyncCount, 0);
    expect(sessionRepository.session.isInProgress, isTrue);
  });

  test('Arabic finish experience strings are localized as requested', () async {
    final ar = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(ar.workoutCelebrationHeading, 'عاش يا بطل! 💪🔥');
    expect(
      ar.workoutCelebrationSubtitle,
      'خلصت تمرينك بنجاح. كل تمرينة بتقربك من هدفك!',
    );
    expect(ar.backToHomeButton, 'العودة للرئيسية');
    expect(ar.restDurationLabel, 'مدة الراحة');
    expect(ar.restMinutesLabel, 'دقيقة');
    expect(ar.restSecondsLabel, 'ثانية');
    expect(ar.setDoneLabel, 'تم');
    expect(ar.keepTrainingButton, isNotEmpty);
    expect(ar.discardWorkoutButton, isNotEmpty);
  });
}
