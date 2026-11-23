import 'dart:io';

import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/notifications/fcm_device_service.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/theme/theme_cubit.dart';
import 'package:ae_coaching/core/theme/theme_preference_store.dart';
import 'package:ae_coaching/features/notification_settings/data/device_time_zone.dart';
import 'package:ae_coaching/features/notification_settings/data/verified_account.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences_repository.dart';
import 'package:ae_coaching/features/profile/presentation/app_settings_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../notification_settings/notification_settings_fakes.dart';

class _PermissionService implements FcmDeviceService {
  AuthorizationStatus status = AuthorizationStatus.denied;
  @override
  Future<AuthorizationStatus> notificationAuthorizationStatus() async => status;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThemeStore implements ThemePreferenceStore {
  ThemeMode mode = ThemeMode.system;
  @override
  ThemeMode read(String uid) => mode;
  @override
  Future<void> write(String uid, ThemeMode value) async => mode = value;
}

void main() {
  late Directory directory;
  late FakeNotificationPreferencesRepository preferences;
  late FakeVerifiedAccount account;
  late _PermissionService permission;
  late LocaleCubit locale;
  late ThemeCubit theme;
  late _ThemeStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('app_settings_test_');
    Hive.init(directory.path);
    await Hive.openBox('authBox');
    preferences = FakeNotificationPreferencesRepository();
    account = FakeVerifiedAccount('settings-user');
    permission = _PermissionService();
    store = _ThemeStore();
    locale = LocaleCubit();
    theme = ThemeCubit(
      store: store,
      userChanges: const Stream.empty(),
      initialUid: 'settings-user',
    );
    sl.registerSingleton<FcmDeviceService>(permission);
    sl.registerSingleton<NotificationPreferencesRepository>(preferences);
    sl.registerSingleton<DeviceTimeZone>(fakeDeviceTimeZone('Africa/Cairo'));
    sl.registerSingleton<VerifiedAccount>(account);
  });

  tearDown(() async {
    await locale.close();
    await theme.close();
    await preferences.dispose();
    await sl.reset();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<AppLocalizations> pumpSettings(
    WidgetTester tester, {
    String language = 'en',
    Future<void> Function()? onLogout,
  }) async {
    // Tall enough that the whole settings list is on screen: taps never
    // depend on scroll positions (which differ per language).
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => locale.setLocale(Locale(language)));
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: locale),
          BlocProvider.value(value: theme),
        ],
        child: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, currentLocale) => BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, mode) => MaterialApp(
              locale: currentLocale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: mode,
              home: AppSettingsScreen(onLogout: onLogout ?? () async {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(AppSettingsScreen)))!;
  }

  SwitchListTile reminderSwitch(WidgetTester tester) => tester.widget<SwitchListTile>(find.byType(SwitchListTile));

  for (final language in ['ar', 'en']) {
    testWidgets('settings supports $language, themes, reminders and logout', (tester) async {
      var logoutRequested = false;
      final l10n = await pumpSettings(
        tester,
        language: language,
        onLogout: () async => logoutRequested = true,
      );
      final context = tester.element(find.byType(AppSettingsScreen));
      expect(
        Directionality.of(context),
        language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      for (final choice in [
        (l10n.themeDark, ThemeMode.dark),
        (l10n.themeLight, ThemeMode.light),
        (l10n.themeSystemDefault, ThemeMode.system),
      ]) {
        await tester.ensureVisible(find.text(choice.$1));
        await tester.tap(find.text(choice.$1));
        await tester.pumpAndSettle();
        expect(theme.state, choice.$2);
        expect(store.mode, choice.$2);
      }
      await tester.ensureVisible(find.byType(SwitchListTile));
      expect(reminderSwitch(tester).value, isTrue); // no document yet: default on
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      // Saved to this account's server document, in the app language.
      expect(preferences.documents['settings-user'], NotificationPreferences(
        inactivityRemindersEnabled: false,
        language: ReminderLanguage.fromLocaleCode(language),
        timeZone: 'Africa/Cairo',
      ));
      expect(reminderSwitch(tester).value, isFalse);
      // Turning reminders off did not change the app language.
      expect(locale.state.languageCode, language);
      await tester.ensureVisible(find.text(l10n.settingsNotificationDenied));
      expect(find.text(l10n.settingsNotificationDenied), findsOneWidget);
      await tester.ensureVisible(find.text(l10n.logoutTooltip));
      await tester.tap(find.text(l10n.logoutTooltip));
      expect(logoutRequested, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('account deletion sits in a separate Danger Zone below Logout', (tester) async {
    final l10n = await pumpSettings(tester);
    final logout = tester.getTopLeft(find.text(l10n.logoutTooltip));
    final dangerZone = tester.getTopLeft(find.text(l10n.dangerZoneTitle));
    final delete = tester.getTopLeft(find.byKey(const ValueKey('settings-delete-account')));
    expect(find.text(l10n.deleteAccountTitle), findsOneWidget);
    expect(dangerZone.dy, greaterThan(logout.dy));
    expect(delete.dy, greaterThan(dangerZone.dy));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('scrolled to the end, Delete account stays clear of the system navigation bar', (tester) async {
    const navigationBar = 48.0;
    await pumpSettings(tester);
    // Short phone with a 3-button navigation bar (set after pumpSettings,
    // which sizes the view).
    tester.view.physicalSize = const Size(400, 640);
    tester.view.padding = const FakeViewPadding(bottom: navigationBar);
    tester.view.viewPadding = const FakeViewPadding(bottom: navigationBar);
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    // A lazy list only estimates its extent: jump until the real end.
    for (var i = 0; i < 5 && position.pixels < position.maxScrollExtent; i++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    expect(position.pixels, position.maxScrollExtent);
    final tile = tester.getRect(find.byKey(const ValueKey('settings-delete-account')));
    expect(tile.bottom, lessThanOrEqualTo(640 - navigationBar));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows the stored server value of the signed-in account', (tester) async {
    preferences.documents['settings-user'] = NotificationPreferences.defaults.copyWith(inactivityRemindersEnabled: false);
    preferences.documents['other-user'] = NotificationPreferences.defaults;
    await pumpSettings(tester);
    expect(reminderSwitch(tester).value, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final (status, expectedText) in [
    (AuthorizationStatus.authorized, (AppLocalizations l) => l.settingsNotificationAuthorized),
    (AuthorizationStatus.provisional, (AppLocalizations l) => l.settingsNotificationAuthorized),
    (AuthorizationStatus.notDetermined, (AppLocalizations l) => l.settingsNotificationNotRequested),
    (AuthorizationStatus.denied, (AppLocalizations l) => l.settingsNotificationDenied),
  ]) {
    testWidgets('notification permission ${status.name} is shown, never requested here', (tester) async {
      permission.status = status;
      final l10n = await pumpSettings(tester);
      await tester.ensureVisible(find.text(expectedText(l10n)));
      expect(find.text(expectedText(l10n)), findsOneWidget);
      final help = find.byTooltip(l10n.settingsPermissionHelpAction);
      expect(help, status == AuthorizationStatus.denied || status == AuthorizationStatus.notDetermined
          ? findsOneWidget
          : findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('offline save: shown as waiting to sync, not as saved', (tester) async {
    preferences.saveResult = PreferenceSaveResult.pendingSync;
    final l10n = await pumpSettings(tester);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(reminderSwitch(tester).value, isFalse);
    expect(find.text(l10n.inactivityReminderPendingSync), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a rejected save leaves the switch unchanged', (tester) async {
    preferences.saveError = const NotificationPreferencesException(NotificationPreferencesFailure.permissionDenied);
    await pumpSettings(tester);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(reminderSwitch(tester).value, isTrue);
    expect(preferences.documents, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('offline with nothing loaded: switch disabled with an explanation', (tester) async {
    preferences.fromCache = true;
    final l10n = await pumpSettings(tester);
    expect(reminderSwitch(tester).onChanged, isNull);
    expect(find.text(l10n.inactivityReminderOffline), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unverified account: switch disabled, nothing read', (tester) async {
    account.uid = null;
    final l10n = await pumpSettings(tester);
    expect(reminderSwitch(tester).onChanged, isNull);
    expect(find.text(l10n.inactivityReminderUnavailable), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a load failure offers a retry', (tester) async {
    preferences.watchError = const NotificationPreferencesException(NotificationPreferencesFailure.unknown);
    final l10n = await pumpSettings(tester);
    expect(find.text(l10n.inactivityReminderLoadFailed), findsOneWidget);
    preferences.watchError = null;
    await tester.ensureVisible(find.text(l10n.retry));
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();
    expect(reminderSwitch(tester).onChanged, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
