import 'dart:io';
import 'dart:typed_data';

import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/account_deletion/application/account_deletion_lifecycle.dart';
import 'package:ae_coaching/features/account_deletion/domain/account_deletion.dart';
import 'package:ae_coaching/features/account_deletion/presentation/cubit/account_deletion_cubit.dart';
import 'package:ae_coaching/features/account_deletion/presentation/delete_account_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'account_deletion_fakes.dart';

void main() {
  late Directory directory;
  late Box box;
  late FakeAccountDeletionRepository repository;
  late RecordingWiper wiper;
  late AccountDeletionLifecycle lifecycle;
  late int signOuts;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('delete_account_screen_test_');
    Hive.init(directory.path);
    // In-memory: the submit writes through Hive, and real file I/O never
    // completes inside testWidgets' fake-async zone.
    box = await Hive.openBox('authBox', bytes: Uint8List(0));
    repository = FakeAccountDeletionRepository();
    wiper = RecordingWiper(box);
    signOuts = 0;
    lifecycle = AccountDeletionLifecycle(
      authBox: box,
      repository: repository,
      wiper: wiper,
      currentUid: () => 'alice',
      signOut: () async => signOuts += 1,
      clearFirestoreCache: () async {},
    );
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<AppLocalizations> pump(WidgetTester tester, {String language = 'en'}) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final cubit = AccountDeletionCubit(
      repository: repository,
      lifecycle: lifecycle,
      currentUid: () => 'alice',
      onStarted: () async {},
    );
    addTearDown(cubit.close);
    await tester.runAsync(cubit.load);
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: BlocProvider.value(value: cubit, child: const DeleteAccountScreen()),
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('route:${settings.name}')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(DeleteAccountScreen)))!;
  }

  FilledButton submit(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const ValueKey('delete-account-submit')));

  Future<void> fillAndSubmit(WidgetTester tester, String password) async {
    await tester.enterText(find.byKey(const ValueKey('delete-account-password')), password);
    await tester.tap(find.byKey(const ValueKey('delete-account-confirm')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('delete-account-submit')));
    await tester.pumpAndSettle();
  }

  for (final language in ['en', 'ar']) {
    testWidgets('$language: explains, requires password and confirmation, deletes, returns to login', (tester) async {
      final l10n = await pump(tester, language: language);
      expect(find.text(l10n.deleteAccountIntro), findsOneWidget);
      expect(find.text(l10n.deleteAccountItemWorkouts), findsOneWidget);
      expect(find.text(l10n.deleteAccountIrreversible), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-account-incomplete')), findsNothing);
      expect(submit(tester).onPressed, isNull);

      await tester.enterText(find.byKey(const ValueKey('delete-account-password')), 'right-password');
      await tester.pump();
      expect(submit(tester).onPressed, isNull); // not confirmed yet
      await tester.tap(find.byKey(const ValueKey('delete-account-confirm')));
      await tester.pump();
      expect(submit(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('delete-account-submit')));
      await tester.pumpAndSettle();
      expect(repository.deleted, ['alice']);
      expect(wiper.wiped, ['alice']);
      expect(signOuts, 1);
      expect(find.text('route:${AppNavigator.login}'), findsOneWidget);
      expect(find.byType(DeleteAccountScreen), findsNothing);
    });
  }

  testWidgets('a wrong password keeps the form and deletes nothing', (tester) async {
    await pump(tester);
    await fillAndSubmit(tester, 'wrong');
    expect(find.byKey(const ValueKey('delete-account-submit')), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-account-incomplete')), findsNothing);
    expect(repository.deleted, isEmpty);
    expect(signOuts, 0);
  });

  testWidgets('interrupted part-way: stays on the form, flagged incomplete, nothing local removed', (tester) async {
    repository.deleteFailure = AccountDeletionFailure.offline;
    await pump(tester);
    await fillAndSubmit(tester, 'right-password');
    expect(find.byKey(const ValueKey('delete-account-incomplete')), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-account-submit')), findsOneWidget);
    expect(wiper.wiped, isEmpty);
    expect(signOuts, 0);
  });

  testWidgets('the delete button stays above the system navigation bar and the keyboard', (tester) async {
    const navigationBar = 48.0;
    tester.view.padding = const FakeViewPadding(bottom: navigationBar);
    tester.view.viewPadding = const FakeViewPadding(bottom: navigationBar);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await pump(tester);

    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final button = find.byKey(const ValueKey('delete-account-submit'));
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(screenHeight - navigationBar));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(52));

    // Keyboard open: it takes over the bottom inset, the button rides on top.
    const keyboard = 300.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    tester.view.padding = FakeViewPadding.zero;
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getRect(button).bottom, lessThanOrEqualTo(screenHeight - keyboard));
    // The form scrolls above the pinned bar instead of hiding behind it.
    expect(
      tester.getRect(find.byType(ListView)).bottom,
      lessThanOrEqualTo(tester.getRect(button).top),
    );
  });

  testWidgets('an interrupted deletion opens with the incomplete notice', (tester) async {
    await tester.runAsync(() => lifecycle.markStarted('alice'));
    final l10n = await pump(tester);
    expect(find.byKey(const ValueKey('delete-account-incomplete')), findsOneWidget);
    expect(find.text(l10n.deleteAccountIncomplete), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-account-submit')), findsOneWidget);
  });
}
