import 'dart:async';

import 'package:ae_coaching/core/feedback/app_feedback.dart';
import 'package:ae_coaching/core/feedback/feedback_card.dart';
import 'package:ae_coaching/core/feedback/feedback_host.dart';
import 'package:ae_coaching/core/feedback/feedback_models.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _card = find.byType(FeedbackCard);
Finder _title(String text) =>
    find.descendant(of: _card, matching: find.text(text));

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.ancestor(of: _card, matching: find.byType(FadeTransition)).first,
    )
    .opacity
    .value;

/// A page that starts loading feedback and owns it.
class _LoadingPage extends StatefulWidget {
  const _LoadingPage();
  @override
  State<_LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<_LoadingPage>
    with FeedbackLoadingOwner<_LoadingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showLoadingFeedback('Uploading photo'),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Upload')));
}

void main() {
  int behindTaps = 0;

  Widget app({
    Locale locale = const Locale('en'),
    ThemeMode mode = ThemeMode.light,
    bool reduceMotion = false,
    String? Function()? currentUser,
    Stream<String?>? users,
    Widget? home,
  }) => MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: mode,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: AppFeedbackHost(
        currentUser: currentUser,
        userChanges: users,
        child: child!,
      ),
    ),
    home:
        home ??
        Scaffold(
          appBar: AppBar(title: const Text('Screen')),
          body: Stack(
            children: [
              Positioned(
                left: 8,
                top: 70,
                child: ElevatedButton(
                  key: const ValueKey('behind'),
                  onPressed: () => behindTaps++,
                  child: const Text('Behind'),
                ),
              ),
            ],
          ),
        ),
  );

  setUp(() => behindTaps = 0);

  testWidgets('no host mounted: the API is a safe no-op', (tester) async {
    expect(AppFeedback.controller, isNull);
    expect(AppFeedback.success('Saved'), isNull);
    final handle = AppFeedback.loading('Saving');
    expect(handle.isActive, isFalse);
    handle
      ..update(progress: 0.5)
      ..success('Done')
      ..dismiss();
  });

  group('appearance per type, light and dark', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('every type renders its icon, accent and text ($mode)', (
        tester,
      ) async {
        await tester.pumpWidget(app(mode: mode));
        final context = tester.element(find.text('Screen'));
        final colors = context.appColors;
        final scheme = Theme.of(context).colorScheme;
        final expected = {
          FeedbackType.success: colors.success,
          FeedbackType.error: colors.error,
          FeedbackType.warning: colors.warning,
          FeedbackType.info: scheme.primary,
          FeedbackType.emailVerification: scheme.primary,
        };
        for (final entry in expected.entries) {
          AppFeedback.show(
            entry.key,
            'Title ${entry.key.name}',
            message: 'More',
          );
          await tester.pumpAndSettle();
          expect(_title('Title ${entry.key.name}'), findsOneWidget);
          expect(
            find.descendant(of: _card, matching: find.text('More')),
            findsOneWidget,
          );
          final icon = tester.widget<Icon>(
            find.byKey(ValueKey('feedback-icon-${entry.key.name}')),
          );
          expect(icon.color, entry.value, reason: entry.key.name);
          AppFeedback.clear();
          await tester.pumpAndSettle();
        }

        final handle = AppFeedback.loading('Working');
        await tester.pump(
          const Duration(milliseconds: 400),
        ); // spinner: never settles
        expect(find.byKey(const ValueKey('feedback-spinner')), findsOneWidget);
        handle.dismiss();
        await tester.pumpAndSettle();
      });

      testWidgets('card surface follows the theme ($mode)', (tester) async {
        await tester.pumpWidget(app(mode: mode));
        AppFeedback.success('Saved');
        await tester.pumpAndSettle();
        final context = tester.element(_card);
        final decoration = tester
            .widgetList<DecoratedBox>(
              find.descendant(of: _card, matching: find.byType(DecoratedBox)),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .firstWhere(
              (d) =>
                  d.borderRadius == BorderRadius.circular(FeedbackCard.radius),
            );
        expect(
          decoration.color,
          mode == ThemeMode.dark
              ? context.appColors.surfaceRaised
              : Theme.of(context).colorScheme.surface,
        );
        expect(decoration.boxShadow, isNotEmpty);
      });
    }
  });

  group('animation and auto-dismiss', () {
    testWidgets('fade + slide + scale in over 300ms, out over 200ms', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      AppFeedback.info('Hello');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(_opacity(tester), inExclusiveRange(0, 1));
      final scale = tester.widget<ScaleTransition>(
        find.ancestor(of: _card, matching: find.byType(ScaleTransition)).first,
      );
      expect(scale.scale.value, inExclusiveRange(0.96, 1));
      await tester.pump(const Duration(milliseconds: 160));
      expect(_opacity(tester), 1);

      AppFeedback.clear();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacity(tester), inExclusiveRange(0, 1), reason: 'exiting');
      await tester.pump(const Duration(milliseconds: 120));
      expect(_card, findsNothing);
    });

    testWidgets('success auto-dismisses after 3s; errors stay 6s', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      AppFeedback.success('Saved');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 2700));
      expect(_title('Saved'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(_card, findsNothing);

      AppFeedback.error('Failed');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 5500));
      expect(_title('Failed'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
    });

    testWidgets('reduced motion: no entrance/exit motion, same timing', (
      tester,
    ) async {
      await tester.pumpWidget(app(reduceMotion: true));
      AppFeedback.success('Saved');
      await tester.pump();
      expect(_opacity(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump(const Duration(milliseconds: 2900));
      expect(_title('Saved'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(_card, findsNothing, reason: 'removed without an exit animation');
    });

    testWidgets('the countdown bar is opt-in', (tester) async {
      await tester.pumpWidget(app());
      AppFeedback.success('Plain');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('feedback-countdown')), findsNothing);
      expect(tester.hasRunningAnimations, isFalse, reason: 'no idle repaint');
      AppFeedback.clear();
      await tester.pumpAndSettle();

      AppFeedback.warning('Timed', showCountdown: true);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('feedback-countdown')), findsOneWidget);
      AppFeedback.clear();
      await tester.pumpAndSettle();
    });

    testWidgets('auto-dismiss pauses in the background and resumes', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      AppFeedback.info('Background-safe');
      await tester.pumpAndSettle();
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(seconds: 20));
      expect(_title('Background-safe'), findsOneWidget);
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(FeedbackDurations.info);
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
    });
  });

  group('dismissal, queueing and deduplication', () {
    testWidgets('the dismiss button and a swipe remove the card', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      AppFeedback.warning('Tap me away');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feedback-dismiss')));
      await tester.pumpAndSettle();
      expect(_card, findsNothing);

      AppFeedback.warning('Swipe me away');
      await tester.pumpAndSettle();
      await tester.fling(_card, const Offset(600, 0), 2000);
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an action runs once and closes the card', (tester) async {
      var retried = 0;
      await tester.pumpWidget(app());
      AppFeedback.error(
        'Offline',
        action: FeedbackAction(label: 'Retry', onPressed: () => retried++),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feedback-action')));
      await tester.pumpAndSettle();
      expect(retried, 1);
      expect(_card, findsNothing);
    });

    testWidgets('rapid repeated triggers show one card; distinct ones queue', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      for (var i = 0; i < 20; i++) {
        AppFeedback.success('Saved');
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(_card, findsOneWidget);
      expect(AppFeedback.controller!.queued, isEmpty);

      for (var i = 0; i < 10; i++) {
        AppFeedback.info('Message $i');
      }
      await tester.pumpAndSettle();
      expect(_card, findsOneWidget, reason: 'never a stack of cards');
      expect(AppFeedback.controller!.queued.length, lessThanOrEqualTo(3));

      AppFeedback.clear();
      AppFeedback.info('First');
      AppFeedback.info('Second');
      await tester.pumpAndSettle();
      expect(_title('First'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('feedback-dismiss')));
      await tester.pumpAndSettle();
      expect(_title('Second'), findsOneWidget);
    });

    testWidgets('an error replaces a visible success immediately', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      AppFeedback.success('Saved');
      await tester.pumpAndSettle();
      AppFeedback.error('Sync failed');
      await tester.pumpAndSettle();
      expect(_title('Sync failed'), findsOneWidget);
      expect(_title('Saved'), findsNothing);
    });
  });

  group('loading lifecycle', () {
    testWidgets('loading persists, updates, then resolves in place', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      final handle = AppFeedback.loading('Uploading', progress: 0.2);
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // spinner: never settles
      expect(find.byKey(const ValueKey('feedback-spinner')), findsOneWidget);
      expect(find.byKey(const ValueKey('feedback-dismiss')), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(_title('Uploading'), findsOneWidget, reason: 'never times out');

      handle.update(title: 'Almost there', progress: 0.9);
      await tester.pump();
      expect(_title('Almost there'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('feedback-progress')),
      );
      expect(progress.value, 0.9);

      final cardKey = tester.widget<FeedbackCard>(_card).key;
      handle.success('Uploaded');
      await tester.pump();
      expect(
        tester.widget<FeedbackCard>(_card).key,
        cardKey,
        reason: 'same card',
      );
      expect(_title('Uploaded'), findsOneWidget);
      expect(handle.isActive, isFalse);
      handle.update(title: 'too late');
      await tester.pump(FeedbackDurations.success);
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
    });

    testWidgets('runWithLoading always removes the card, even on failure', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      final ok = AppFeedback.runWithLoading(() async => 42, title: 'Working');
      expect(await ok, 42);
      await tester.pumpAndSettle();
      expect(_card, findsNothing);

      await expectLater(
        AppFeedback.runWithLoading<void>(
          () async => throw StateError('boom'),
          title: 'Working',
          errorTitle: 'Could not finish',
        ),
        throwsStateError,
      );
      await tester.pumpAndSettle();
      expect(_title('Could not finish'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing, reason: 'no raw error');
    });

    testWidgets("a popped screen's loading card is removed", (tester) async {
      await tester.pumpWidget(app());
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const _LoadingPage()),
      );
      // The page starts loading after its first frame; a spinner never
      // settles, so pump fixed frames instead of pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(_title('Uploading photo'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
    });

    testWidgets("signing out drops the previous user's feedback, loading too", (
      tester,
    ) async {
      String? uid = 'user-a';
      final users = StreamController<String?>.broadcast();
      addTearDown(users.close);
      await tester.pumpWidget(app(currentUser: () => uid, users: users.stream));
      AppFeedback.loading('Syncing workouts');
      AppFeedback.info('Queued for user A');
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // spinner: never settles
      expect(_title('Syncing workouts'), findsOneWidget);

      uid = null;
      AppFeedback.warning('Signed out notice');
      users.add(null);
      await tester.pumpAndSettle();
      expect(_title('Signed out notice'), findsOneWidget);
      expect(find.text('Syncing workouts'), findsNothing);
      expect(AppFeedback.controller!.queued, isEmpty);
    });
  });

  group('root placement and interaction', () {
    testWidgets('feedback survives navigation and shows above dialogs', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      AppFeedback.success('Profile saved');
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Next screen')),
        ),
        (_) => false,
      );
      await tester.pumpAndSettle();
      expect(find.text('Next screen'), findsOneWidget);
      expect(_title('Profile saved'), findsOneWidget);

      AppFeedback.clear();
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: tester.element(find.text('Next screen')),
          builder: (_) => const AlertDialog(content: Text('Dialog body')),
        ),
      );
      await tester.pumpAndSettle();
      AppFeedback.warning('Over the dialog');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feedback-dismiss')));
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
      expect(find.text('Dialog body'), findsOneWidget, reason: 'dialog intact');
    });

    testWidgets(
      'touches outside the card reach the app; the toolbar stays clear',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 30);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(app());
        AppFeedback.info('Not in the way');
        await tester.pumpAndSettle();

        final cardRect = tester.getRect(_card);
        expect(cardRect.top, greaterThanOrEqualTo(30 + kToolbarHeight));
        expect(cardRect.width, lessThanOrEqualTo(FeedbackCard.maxWidth));
        // A control beside the card, at the card's height, still works.
        final behind = tester.getRect(find.byKey(const ValueKey('behind')));
        expect(behind.right, lessThan(cardRect.left));
        await tester.tap(find.byKey(const ValueKey('behind')));
        await tester.pump();
        expect(behindTaps, 1);
        // The app bar under the reserved toolbar row is reachable too.
        expect(
          tester.getRect(find.text('Screen')).bottom,
          lessThan(cardRect.top),
        );
      },
    );
  });

  group('localization and accessibility', () {
    testWidgets('Arabic: RTL card, Arabic labels and announcement', (
      tester,
    ) async {
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message as Map<Object?, Object?>;
            if (map['type'] == 'announce') {
              announcements.add(
                (map['data']! as Map<Object?, Object?>)['message']! as String,
              );
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app(locale: const Locale('ar')));
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

      AppFeedback.error('تعذّر الحفظ');
      await tester.pumpAndSettle();
      expect(Directionality.of(tester.element(_card)), TextDirection.rtl);
      expect(find.bySemanticsLabel(l10n.feedbackDismiss), findsOneWidget);
      expect(announcements, ['${l10n.feedbackErrorLabel}: تعذّر الحفظ']);
      semantics.dispose();
    });

    testWidgets('a loading card that resolves announces the outcome', (
      tester,
    ) async {
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message as Map<Object?, Object?>;
            if (map['type'] == 'announce') {
              announcements.add(
                (map['data']! as Map<Object?, Object?>)['message']! as String,
              );
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      await tester.pumpWidget(app());
      final handle = AppFeedback.loading('Saving');
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // spinner: never settles
      handle.update(progress: 0.5);
      await tester.pump();
      handle.success('Saved');
      await tester.pumpAndSettle();
      expect(announcements, ['In progress: Saving', 'Success: Saved']);
    });
  });
}
