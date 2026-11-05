import 'dart:async';
import 'dart:io';

import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/notifications/fcm_device_service.dart';
import 'package:ae_coaching/core/notifications/inactivity_reminder_service.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/theme/theme_cubit.dart';
import 'package:ae_coaching/core/theme/theme_preference_store.dart';
import 'package:ae_coaching/features/profile/presentation/app_settings_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _PermissionService implements FcmDeviceService {
  @override
  Future<AuthorizationStatus> notificationAuthorizationStatus() async =>
      AuthorizationStatus.denied;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reminders implements InactivityReminderService {
  final changes = StreamController<bool>.broadcast();
  bool enabled = true;
  @override
  Stream<bool> watch() async* {
    yield enabled;
    yield* changes.stream;
  }

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
    changes.add(value);
  }

  @override
  Future<void> syncLanguage(String languageCode) async {}
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
  late _Reminders reminders;
  late LocaleCubit locale;
  late ThemeCubit theme;
  late _ThemeStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('app_settings_test_');
    Hive.init(directory.path);
    await Hive.openBox('authBox');
    reminders = _Reminders();
    store = _ThemeStore();
    locale = LocaleCubit(inactivityReminderService: reminders);
    theme = ThemeCubit(
      store: store,
      userChanges: const Stream.empty(),
      initialUid: 'settings-user',
    );
    sl.registerSingleton<FcmDeviceService>(_PermissionService());
    sl.registerSingleton<InactivityReminderService>(reminders);
  });

  tearDown(() async {
    await locale.close();
    await theme.close();
    await reminders.changes.close();
    await sl.reset();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  for (final language in ['ar', 'en']) {
    testWidgets('settings supports $language, themes, reminders and logout', (
      tester,
    ) async {
      var logoutRequested = false;
      await tester.runAsync(() => locale.setLocale(Locale(language)));
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: locale),
            BlocProvider.value(value: theme),
          ],
          child: BlocBuilder<LocaleCubit, Locale>(
            builder: (context, currentLocale) =>
                BlocBuilder<ThemeCubit, ThemeMode>(
                  builder: (context, mode) => MaterialApp(
                    locale: currentLocale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme: AppTheme.light,
                    darkTheme: AppTheme.dark,
                    themeMode: mode,
                    home: AppSettingsScreen(
                      onLogout: () async => logoutRequested = true,
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AppSettingsScreen));
      final l10n = AppLocalizations.of(context)!;
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
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(reminders.enabled, isFalse);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.ensureVisible(find.text(l10n.settingsNotificationDenied));
      expect(find.text(l10n.settingsNotificationDenied), findsOneWidget);
      await tester.ensureVisible(find.text(l10n.logoutTooltip));
      await tester.tap(find.text(l10n.logoutTooltip));
      expect(logoutRequested, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
