import 'package:ae_coaching/core/bootstrap/startup_destination.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/profile/domain/my_progress_summary_service.dart';
import 'package:ae_coaching/features/profile/domain/personal_record_book.dart';
import 'package:ae_coaching/features/profile/presentation/progress/personal_records_screen.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_dashboard.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_programs_screen.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_widgets.dart';
import 'package:ae_coaching/features/profile/presentation/progress/workout_history_screen.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/presentation/screens/program_analytics_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_template_history_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/layout/keyboard_phone.dart';

// Sunday 22 Nov 2026, noon. The week started Monday 16 Nov.
final now = DateTime(2026, 11, 22, 12);

WorkoutSession _session(
  String id,
  DateTime completedAt, {
  required String program,
  required String template,
  String? name,
}) => WorkoutSession(
  id: id,
  programId: program,
  workoutTemplateId: template,
  workoutNameSnapshot: name ?? id,
  date: completedAt,
  startedAt: completedAt.subtract(const Duration(minutes: 50)),
  completedAt: completedAt,
  status: 'completed',
  totalVolume: 0,
);

ExerciseSet _set(
  WorkoutSession session,
  String exercise,
  double weight,
  int reps,
) => ExerciseSet(
  exerciseName: exercise,
  weight: weight,
  reps: reps,
  date: session.completedAt!,
  programId: session.programId,
  workoutTemplateId: session.workoutTemplateId,
  workoutSessionId: session.id,
);

final programs = [
  WorkoutProgram(
    id: 'p1',
    name: 'Strength Block',
    createdAt: DateTime(2026, 9, 1),
    isActive: true,
  ),
  WorkoutProgram(
    id: 'p2',
    name: 'Hypertrophy',
    createdAt: DateTime(2026, 8, 1),
  ),
  WorkoutProgram(
    id: 'p3',
    name: 'Old Program',
    createdAt: DateTime(2026, 1, 1),
  ),
];

final templates = [
  WorkoutTemplate(
    id: 't1',
    programId: 'p1',
    name: 'Push A',
    createdAt: DateTime(2026, 9, 1),
  ),
  WorkoutTemplate(
    id: 't2',
    programId: 'p1',
    name: 'Pull A',
    createdAt: DateTime(2026, 9, 1),
  ),
  WorkoutTemplate(
    id: 't3',
    programId: 'p2',
    name: 'Legs',
    createdAt: DateTime(2026, 8, 1),
  ),
];

final sessions = [
  _session(
    's1',
    DateTime(2026, 11, 22, 9),
    program: 'p1',
    template: 't1',
    name: 'Push A',
  ),
  _session(
    's2',
    DateTime(2026, 11, 22, 18 - 8),
    program: 'p1',
    template: 't2',
    name: 'Pull A',
  ),
  _session(
    's3',
    DateTime(2026, 11, 18, 19),
    program: 'p2',
    template: 't3',
    name: 'Legs',
  ),
  _session(
    's4',
    DateTime(2026, 10, 28, 19),
    program: 'p2',
    template: 't3',
    name: 'Legs',
  ),
  _session(
    's5',
    DateTime(2026, 10, 2, 19),
    program: 'p1',
    template: 't1',
    name: 'Push A',
  ),
];

final sets = [
  _set(sessions[4], 'Bench Press', 60, 10),
  _set(sessions[3], 'Squat', 100, 5),
  _set(sessions[2], 'Leg Press', 180, 10),
  _set(sessions[1], 'Barbell Row', 70, 8),
  _set(sessions[0], 'Bench Press', 80, 5),
  _set(sessions[0], 'Overhead Press', 45, 6),
];

ProgressDashboardData _data({
  List<WorkoutSession>? withSessions,
  List<ExerciseSet>? withSets,
  List<WorkoutProgram>? withPrograms,
}) {
  final s = withSessions ?? sessions;
  final x = withSets ?? sets;
  return ProgressDashboardData(
    summary: const MyProgressSummaryService().summarize(
      sessions: s,
      sets: x,
      now: now,
    ),
    records: PersonalRecordBook.fromSets(x),
    programs: withPrograms ?? programs,
    templates: templates,
  );
}

void main() {
  late List<RouteSettings> opened;

  setUp(() {
    opened = [];
    final original = AppRouter.readAuthSnapshot;
    AppRouter.readAuthSnapshot = () => const StartupAuthSnapshot(
      firebaseUid: 'u',
      firebaseEmail: 'u@example.com',
      firebaseEmailVerified: true,
    );
    addTearDown(() => AppRouter.readAuthSnapshot = original);
  });

  Future<AppLocalizations> pump(
    WidgetTester tester,
    ProgressDashboardData data, {
    String language = 'en',
    bool tall = true,
  }) async {
    if (tall) {
      tester.view
        ..physicalSize = const Size(900, 2600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        // The real progress routes; the existing detail routes (which need
        // the service locator) are only recorded.
        onGenerateRoute: (settings) {
          opened.add(settings);
          if (settings.name == AppNavigator.workoutTemplateHistory ||
              settings.name == AppNavigator.programAnalytics) {
            return MaterialPageRoute<void>(
              builder: (_) => Scaffold(body: Text('opened ${settings.name}')),
            );
          }
          return AppRouter.onGenerateRoute(settings);
        },
        home: Scaffold(
          body: ProgressDashboard(data: data, now: now),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(ProgressDashboard)))!;
  }

  group('dashboard', () {
    testWidgets(
      'previews stay short: 3 latest records, 2 latest workouts, 2 programs',
      (tester) async {
        await pump(tester, _data());
        expect(find.byType(PersonalRecordTile), findsNWidgets(3));
        expect(find.byType(WorkoutSessionTile), findsNWidgets(2));
        expect(find.byType(ProgramAnalyticsTile), findsNWidgets(2));
        // Latest workouts are the two of today, newest first.
        final tiles = tester
            .widgetList<WorkoutSessionTile>(find.byType(WorkoutSessionTile))
            .toList();
        expect(tiles.map((t) => t.session.id), ['s2', 's1']);
        // Latest records: both of Barbell Row (10:00), then the heaviest
        // weight set at 09:00 (ties ordered by name: Bench Press).
        final records = tester
            .widgetList<PersonalRecordTile>(find.byType(PersonalRecordTile))
            .toList();
        expect(records.map((r) => r.record.exerciseName), [
          'Barbell Row',
          'Barbell Row',
          'Bench Press',
        ]);
        expect(records.last.record.newBest, 80); // not the older 60 kg
        expect(
          find.byKey(const ValueKey('progress-view-all-records')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('progress-view-all-workouts')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('progress-view-all-programs')),
          findsOneWidget,
        );
      },
    );

    testWidgets('metrics say what they count and since when', (tester) async {
      final l10n = await pump(tester, _data());
      expect(find.text(l10n.progressAllTimeCaption), findsOneWidget);
      expect(find.text('Since Monday'), findsOneWidget);
      expect(find.text('Since Nov 1'), findsOneWidget);
      final week = find.byKey(const ValueKey('progress-metric-week'));
      expect(
        find.descendant(of: week, matching: find.text('3')),
        findsOneWidget,
      ); // s1, s2, s3
      final month = find.byKey(const ValueKey('progress-metric-month'));
      expect(
        find.descendant(of: month, matching: find.text('3')),
        findsOneWidget,
      );
      final total = find.byKey(const ValueKey('progress-metric-total'));
      expect(
        find.descendant(of: total, matching: find.text('5')),
        findsOneWidget,
      );
    });

    testWidgets(
      'the chart shows completed workouts per day for the last 7 days, zeros included',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final l10n = await pump(tester, _data());
        expect(find.text(l10n.progressDailyChartSubtitle), findsOneWidget);
        expect(
          find.bySemanticsLabel('Sunday, November 22: 2 completed workouts'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Wednesday, November 18: 1 completed workout'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Monday, November 16: 0 completed workouts'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(r'completed workouts?$')),
          findsNWidgets(7),
        );
        expect(find.text(l10n.progressTodayLabel), findsOneWidget);
        expect(find.text(l10n.progressChartTotal(3)), findsOneWidget);

        // The existing 6-week view is still there.
        await tester.tap(find.text(l10n.progressRangeWeeks));
        await tester.pumpAndSettle();
        expect(find.text(l10n.progressWeeklyChartSubtitle), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'^Week of ')), findsNWidgets(6));
        expect(
          find.bySemanticsLabel('Week of November 16: 3 completed workouts'),
          findsOneWidget,
        );
        semantics.dispose();
      },
    );

    testWidgets('Arabic: right-to-left, oldest day on the right', (
      tester,
    ) async {
      final l10n = await pump(tester, _data(), language: 'ar');
      expect(find.text('منذ الاثنين'), findsOneWidget);
      final today = find.text(l10n.progressTodayLabel);
      expect(
        tester.getCenter(find.text('16/11')).dx,
        greaterThan(tester.getCenter(today).dx),
      );
      // One digit style on the whole screen (dates included), as in the
      // weights and counts; and Arabic weights read naturally.
      expect(find.textContaining(RegExp('[٠-٩۰-۹]')), findsNothing);
      expect(find.text('80 كجم × 5'), findsOneWidget);
      expect(find.textContaining('22 نوفمبر 2026'), findsWidgets);
    });

    testWidgets('empty sections explain themselves and offer no "View all"', (
      tester,
    ) async {
      // Completed workouts with body-weight sets only: no records.
      final bodyWeight = [for (final s in sessions) _set(s, 'Push-up', 0, 20)];
      final l10n = await pump(
        tester,
        _data(withSets: bodyWeight, withPrograms: [programs.first]),
      );
      expect(find.text(l10n.progressRecordsEmpty), findsOneWidget);
      expect(
        find.byKey(const ValueKey('progress-view-all-records')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('progress-view-all-programs')),
        findsNothing,
      ); // only 1
      await tester.pumpWidget(const SizedBox.shrink());

      // Programs only, nothing completed yet.
      final l10n2 = await pump(
        tester,
        _data(withSessions: const [], withSets: const []),
      );
      expect(find.text(l10n2.progressNoCompletedWorkouts), findsOneWidget);
      expect(
        find.byKey(const ValueKey('progress-view-all-workouts')),
        findsNothing,
      );
      expect(find.byType(ProgramAnalyticsTile), findsNWidgets(2));
    });

    testWidgets('a workout opens its existing workout-day history', (
      tester,
    ) async {
      await pump(tester, _data());
      await tester.tap(find.byType(WorkoutSessionTile).first);
      await tester.pumpAndSettle();
      final route = opened.last;
      expect(route.name, AppNavigator.workoutTemplateHistory);
      expect(
        (route.arguments! as WorkoutTemplateHistoryArgs).template.id,
        't2',
      );
    });
  });

  group('personal records screen', () {
    testWidgets(
      'View all: one card per exercise, both record kinds, searchable',
      (tester) async {
        final l10n = await pump(tester, _data());
        await tester.tap(
          find.byKey(const ValueKey('progress-view-all-records')),
        );
        await tester.pumpAndSettle();
        expect(opened.last.name, AppNavigator.personalRecords);
        expect(find.byType(PersonalRecordsScreen), findsOneWidget);

        final bench = find.byKey(
          const ValueKey('records-exercise-Bench Press'),
        );
        expect(bench, findsOneWidget);
        expect(
          find.descendant(
            of: bench,
            matching: find.text(l10n.progressHeaviestWeightRecord),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: bench,
            matching: find.text(l10n.progressBestSetVolumeLabel),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: bench, matching: find.text('80 kg × 5')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: bench,
            matching: find.text('60 kg × 10 = 600 kg'),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.progressExerciseCount(5)), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('records-search')),
          'press',
        );
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.progressExerciseCount(3)),
          findsOneWidget,
        ); // Bench, Leg, Overhead
        expect(
          find.byKey(const ValueKey('records-exercise-Squat')),
          findsNothing,
        );

        await tester.enterText(
          find.byKey(const ValueKey('records-search')),
          'deadlift',
        );
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.progressRecordsNoResults('deadlift')),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip(l10n.progressClearSearch));
        await tester.pumpAndSettle();
        expect(find.text(l10n.progressExerciseCount(5)), findsOneWidget);
      },
    );

    testWidgets('hundreds of exercises are built lazily', (tester) async {
      final many = [
        for (var i = 0; i < 300; i++)
          ExerciseSet(
            exerciseName: 'Exercise $i',
            weight: 20,
            reps: 10,
            date: DateTime(2026, 1, 1).add(Duration(hours: i)),
          ),
      ];
      tester.view
        ..physicalSize = smallPhone
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PersonalRecordsScreen(
            records: PersonalRecordBook.fromSets(many),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final built = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('records-exercise-'),
      );
      expect(built.evaluate().length, lessThan(30));
      await tester.enterText(
        find.byKey(const ValueKey('records-search')),
        'Exercise 150',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('records-exercise-Exercise 150')),
        findsOneWidget,
      );
    });

    testWidgets('no records: an explanation instead of an empty list', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PersonalRecordsScreen(records: PersonalRecordBook.empty),
        ),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PersonalRecordsScreen)),
      )!;
      expect(find.text(l10n.progressRecordsEmpty), findsOneWidget);
      expect(find.byKey(const ValueKey('records-search')), findsNothing);
    });
  });

  group('workout history screen', () {
    testWidgets(
      'View all: by month, newest first, filterable by program, opens details',
      (tester) async {
        final l10n = await pump(tester, _data());
        await tester.tap(
          find.byKey(const ValueKey('progress-view-all-workouts')),
        );
        await tester.pumpAndSettle();
        expect(opened.last.name, AppNavigator.workoutHistory);
        expect(find.byType(WorkoutHistoryScreen), findsOneWidget);

        final november = find.text('November 2026');
        final october = find.text('October 2026');
        expect(november, findsOneWidget);
        expect(october, findsOneWidget);
        expect(
          tester.getTopLeft(november).dy,
          lessThan(tester.getTopLeft(october).dy),
        );
        expect(
          find.text(l10n.progressWorkoutCount(3)),
          findsOneWidget,
        ); // November
        expect(
          find.text(l10n.progressWorkoutCount(2)),
          findsOneWidget,
        ); // October
        expect(find.byType(WorkoutSessionTile), findsNWidgets(5));

        // Only programs that have workouts are offered (not "Old Program").
        expect(find.byKey(const ValueKey('history-filter-p3')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('history-filter-p2')));
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutSessionTile), findsNWidgets(2));
        expect(find.text('Push A'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('history-filter-all')));
        await tester.pumpAndSettle();
        expect(find.byType(WorkoutSessionTile), findsNWidgets(5));

        await tester.tap(find.byType(WorkoutSessionTile).last);
        await tester.pumpAndSettle();
        expect(opened.last.name, AppNavigator.workoutTemplateHistory);
        expect(
          (opened.last.arguments! as WorkoutTemplateHistoryArgs).template.id,
          't1',
        );
      },
    );

    testWidgets('a workout whose day was deleted is shown but not tappable', (
      tester,
    ) async {
      final orphan = _session(
        'orphan',
        DateTime(2026, 11, 21, 9),
        program: 'p1',
        template: 'gone',
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkoutHistoryScreen(
            data: _data(
              withSessions: [orphan],
              withSets: [_set(orphan, 'Squat', 50, 5)],
            ),
          ),
        ),
      );
      final tile = tester.widget<WorkoutSessionTile>(
        find.byType(WorkoutSessionTile),
      );
      expect(tile.onTap, isNull);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });

  testWidgets(
    'programs: View all lists every program, each opens its analytics',
    (tester) async {
      await pump(tester, _data());
      await tester.tap(
        find.byKey(const ValueKey('progress-view-all-programs')),
      );
      await tester.pumpAndSettle();
      expect(opened.last.name, AppNavigator.progressPrograms);
      expect(find.byType(ProgressProgramsScreen), findsOneWidget);
      expect(find.byType(ProgramAnalyticsTile), findsNWidgets(3));
      await tester.tap(find.text('Old Program'));
      await tester.pumpAndSettle();
      expect(opened.last.name, AppNavigator.programAnalytics);
      expect((opened.last.arguments! as ProgramAnalyticsArgs).program.id, 'p3');
    },
  );

  testWidgets(
    'progress routes without their arguments show the invalid-route screen',
    (tester) async {
      await pump(tester, _data());
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      for (final (name, args) in [
        (AppNavigator.personalRecords, 'PersonalRecordsArgs'),
        (AppNavigator.workoutHistory, 'WorkoutHistoryArgs'),
        (AppNavigator.progressPrograms, 'ProgressProgramsArgs'),
      ]) {
        navigator.pushNamed(name);
        await tester.pumpAndSettle();
        expect(find.textContaining(args), findsOneWidget);
        navigator.pop();
        await tester.pumpAndSettle();
      }
    },
  );

  for (final language in ['en', 'ar']) {
    testWidgets('$language · small phone, text ×1.3: no overflow anywhere', (
      tester,
    ) async {
      useSmallPhone(tester, textScale: 1.3);
      await pump(tester, _data(), language: language, tall: false);
      expectNoOverflow(tester);
      final dashboard = find
          .descendant(
            of: find.byKey(const ValueKey('progress-dashboard')),
            matching: find.byType(Scrollable),
          )
          .first;
      Future<void> open(String key, Type screen) async {
        tester.state<ScrollableState>(dashboard).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(ValueKey(key)),
          150,
          scrollable: dashboard,
        );
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget);
        expectNoOverflow(tester);
      }

      await open('progress-view-all-programs', ProgressProgramsScreen);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await open('progress-view-all-workouts', WorkoutHistoryScreen);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await open('progress-view-all-records', PersonalRecordsScreen);
      await tester.showKeyboard(find.byKey(const ValueKey('records-search')));
      await setKeyboard(tester, open: true);
      expectNoOverflow(tester);
    });
  }
}
