import 'package:ae_coaching/core/feedback/feedback_host.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_run.dart';
import 'package:ae_coaching/features/workout/presentation/screens/cardio_session_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const countdown = CardioPlan(mode: CardioMode.countdown, durationSeconds: 1200);
const intervals = CardioPlan(
  mode: CardioMode.intervals,
  warmupSeconds: 60,
  workSeconds: 30,
  intervalRestSeconds: 15,
  rounds: 3,
);
const t0 = 1700000000000;
int at(int seconds) => t0 + seconds * 1000;

void main() {
  late int clock;
  late List<CardioRun> saved;
  late List<String> native;
  late int haptics;

  setUp(() {
    clock = t0;
    saved = [];
    native = [];
    haptics = 0;
  });

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    CardioPlan plan = countdown,
    CardioRun initial = const CardioRun(),
    String language = 'en',
    String? next = 'Lateral Raises',
  }) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('ae_coaching/rest_timer'),
      (call) async {
        native.add('${call.method}:${call.arguments}');
        return null;
      },
    );
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics++;
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(
        const MethodChannel('ae_coaching/rest_timer'),
        null,
      );
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        builder: AppFeedbackHost.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('open'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CardioSessionScreen(
                      workoutTitle: 'Push A',
                      activityName: 'Running',
                      exerciseId: 'repdb:running',
                      plan: plan,
                      initialRun: initial,
                      nextActivityName: next,
                      onSave: (run) async => saved.add(run),
                      now: () => clock,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    return AppLocalizations.of(
      tester.element(find.byType(CardioSessionScreen)),
    )!;
  }

  String time(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('cardio-time'))).data!;

  /// Moves the clock and lets the screen's ticker see it.
  Future<void> advance(WidgetTester tester, int seconds) async {
    clock += seconds * 1000;
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Closes the screen (its ticker stops) and lets any toast finish.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets('countdown: starts only when asked; pause, resume and finish '
      'early are saved; the screen stays on only while it runs', (
    tester,
  ) async {
    final l10n = await pump(tester);
    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text(l10n.cardioPlannedValue('20 min')), findsOneWidget);
    expect(
      find.text(l10n.cardioNextActivity('Lateral Raises')),
      findsOneWidget,
    );
    expect(time(tester), '20:00');
    await advance(tester, 90);
    expect(time(tester), '20:00', reason: 'nothing runs before Start');
    expect(saved, isEmpty);

    await tester.tap(find.byKey(const ValueKey('cardio-start')));
    await tester.pump();
    expect(saved.last.status, CardioRunStatus.running);
    expect(native, contains('keepScreenOn:true'));
    await advance(tester, 65);
    expect(time(tester), '18:55');

    await tester.tap(find.byKey(const ValueKey('cardio-pause')));
    await tester.pump();
    expect(saved.last.status, CardioRunStatus.paused);
    expect(native.last, 'keepScreenOn:false');
    await advance(tester, 300);
    expect(time(tester), '18:55', reason: 'paused time is not counted');

    await tester.tap(find.byKey(const ValueKey('cardio-resume')));
    await tester.pump();
    await advance(tester, 10);
    expect(time(tester), '18:45');

    await tester.tap(find.byKey(const ValueKey('cardio-finish')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.cardioFinishEarlyTitle), findsOneWidget);
    expect(
      find.text(l10n.cardioFinishEarlyBody('01:15', '20:00')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('cardio-confirm-ok')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(saved.last.status, CardioRunStatus.endedEarly);
    expect(saved.last.actualSeconds, 75);
    expect(find.text(l10n.cardioStatusEndedEarly('01:15')), findsOneWidget);
    expect(find.byKey(const ValueKey('cardio-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('cardio-start')), findsNothing);
    await done(tester);
  });

  testWidgets('intervals: phases change by themselves, named with an icon '
      '(not colour alone), with the round, the next phase and a cue', (
    tester,
  ) async {
    final l10n = await pump(tester, plan: intervals, next: null);
    expect(find.text(l10n.cardioLastActivity), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cardio-start')));
    await tester.pump();
    final phase = find.byKey(const ValueKey('cardio-phase'));
    expect(
      find.descendant(of: phase, matching: find.text(l10n.intervalPhaseWarmup)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: phase, matching: find.byType(Icon)),
      findsOneWidget,
    );
    expect(time(tester), '01:00');

    await advance(tester, 60);
    expect(
      find.descendant(of: phase, matching: find.text(l10n.intervalPhaseWork)),
      findsOneWidget,
    );
    expect(find.text(l10n.intervalRoundOf(1, 3)), findsOneWidget);
    expect(
      find.text(l10n.intervalNextPhase(l10n.intervalPhaseRest, '00:15')),
      findsOneWidget,
    );
    expect(
      native.where((c) => c.startsWith('playNotificationSound')),
      hasLength(1),
    );
    expect(haptics, 1);

    // Sounds off: the phases still change, silently.
    await tester.tap(find.byKey(const ValueKey('cardio-sound')));
    await tester.pump();
    await advance(tester, 30);
    expect(
      find.descendant(of: phase, matching: find.text(l10n.intervalPhaseRest)),
      findsOneWidget,
    );
    expect(
      native.where((c) => c.startsWith('playNotificationSound')),
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('cardio-sound')));
    await tester.pump();

    await advance(tester, 15 + 30 + 15 + 30);
    expect(saved.last.status, CardioRunStatus.completed);
    expect(find.text(l10n.cardioStatusCompleted('03:00')), findsOneWidget);
    await done(tester);
  });

  testWidgets('skip asks first, is saved as skipped and returns to the '
      'workout', (tester) async {
    final l10n = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('cardio-skip')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.cardioSkipConfirmBody), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cardio-confirm-cancel')));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);

    await tester.tap(find.byKey(const ValueKey('cardio-skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cardio-confirm-ok')));
    await tester.pumpAndSettle();
    expect(saved.single.status, CardioRunStatus.skipped);
    expect(find.byType(CardioSessionScreen), findsNothing);
    await done(tester);
  });

  testWidgets('reopened after the app was closed mid-run: the time kept '
      'counting, and coming back from the background updates it at once', (
    tester,
  ) async {
    final running = CardioRun.planned(
      plan: countdown,
      name: 'Running',
      exerciseId: 'repdb:running',
    ).start(at(-300));
    await pump(tester, initial: running);
    expect(time(tester), '15:00');
    expect(find.byKey(const ValueKey('cardio-pause')), findsOneWidget);

    clock += 120 * 1000;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(time(tester), '13:00');
    await done(tester);
  });

  testWidgets('a countdown that ran out while away shows as done', (
    tester,
  ) async {
    final running = const CardioRun().start(at(-1800));
    final l10n = await pump(tester, initial: running);
    expect(find.text(l10n.cardioStatusCompleted('20:00')), findsOneWidget);
    expect(saved.single.status, CardioRunStatus.completed);
    expect(native.where((c) => c.startsWith('playNotificationSound')), isEmpty);
    await done(tester);
  });

  testWidgets('Arabic: right-to-left, Arabic labels, the time reads left to '
      'right', (tester) async {
    final l10n = await pump(tester, plan: intervals, language: 'ar');
    expect(
      Directionality.of(
        tester.element(find.byKey(const ValueKey('cardio-phase'))),
      ),
      TextDirection.rtl,
    );
    expect(find.text('ابدأ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cardio-start')));
    await tester.pump();
    await advance(tester, 60);
    expect(find.text(l10n.intervalPhaseWork), findsOneWidget);
    expect(l10n.intervalPhaseWork, 'جهد');
    expect(find.text(l10n.intervalRoundOf(1, 3)), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('cardio-time')))
          .textDirection,
      TextDirection.ltr,
    );
    await done(tester);
  });
}
