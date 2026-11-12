import 'dart:async';

import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences_repository.dart';
import 'package:ae_coaching/features/notification_settings/presentation/cubit/notification_preferences_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_settings_fakes.dart';

void main() {
  late FakeNotificationPreferencesRepository repository;
  late FakeVerifiedAccount account;
  var language = 'ar';

  NotificationPreferencesCubit cubitFor({String? deviceZone = 'Africa/Cairo'}) => NotificationPreferencesCubit(
    repository: repository,
    deviceTimeZone: fakeDeviceTimeZone(deviceZone),
    account: account,
    languageCode: () => language,
  );

  setUp(() {
    repository = FakeNotificationPreferencesRepository();
    account = FakeVerifiedAccount('user-a');
    language = 'ar';
  });

  tearDown(() => repository.dispose());

  test('no verified account: unavailable, nothing read', () async {
    account.uid = null;
    final cubit = cubitFor();
    await cubit.start();
    expect(cubit.state.status, NotificationPreferencesStatus.unavailable);
    expect(cubit.state.canToggle, isFalse);
    expect(await cubit.setEnabled(false), PreferenceSaveOutcome.failed);
    expect(repository.writes, isEmpty);
    await cubit.close();
  });

  test('loading, then the stored value of this account only', () async {
    repository.documents['user-a'] = NotificationPreferences.defaults.copyWith(inactivityRemindersEnabled: false);
    repository.documents['user-b'] = NotificationPreferences.defaults;
    final cubit = cubitFor();
    expect(cubit.state.status, NotificationPreferencesStatus.loading);
    await cubit.start();
    await pumpEventQueue();
    expect(cubit.state.status, NotificationPreferencesStatus.ready);
    expect(cubit.state.enabled, isFalse);
    await cubit.close();
  });

  test('a missing document shows the default (on) and saves the full document', () async {
    language = 'en';
    final cubit = cubitFor(deviceZone: 'Asia/Riyadh');
    await cubit.start();
    await pumpEventQueue();
    expect(cubit.state.enabled, isTrue);

    expect(await cubit.setEnabled(false), PreferenceSaveOutcome.confirmed);
    await pumpEventQueue();
    expect(repository.writes.single, (
      'user-a',
      const NotificationPreferences(
        inactivityRemindersEnabled: false,
        language: ReminderLanguage.en,
        timeZone: 'Asia/Riyadh',
      ),
    ));
    expect(cubit.state.enabled, isFalse);
    expect(cubit.state.saving, isFalse);
    expect(cubit.state.pendingSync, isFalse);
    await cubit.close();
  });

  test('offline save: pending, shown as waiting to sync, never confirmed', () async {
    repository.saveResult = PreferenceSaveResult.pendingSync;
    final cubit = cubitFor();
    await cubit.start();
    await pumpEventQueue();
    expect(await cubit.setEnabled(false), PreferenceSaveOutcome.pendingSync);
    await pumpEventQueue();
    expect(cubit.state.enabled, isFalse);
    expect(cubit.state.pendingSync, isTrue);
    await cubit.close();
  });

  test('offline with nothing confirmed for this account: no switch', () async {
    repository.fromCache = true;
    final cubit = cubitFor();
    await cubit.start();
    await pumpEventQueue();
    expect(cubit.state.status, NotificationPreferencesStatus.offline);
    expect(cubit.state.canToggle, isFalse);
    await cubit.close();
  });

  test('rejected and failed saves are reported as such; the value does not change', () async {
    final cubit = cubitFor();
    await cubit.start();
    await pumpEventQueue();
    repository.saveError = const NotificationPreferencesException(NotificationPreferencesFailure.permissionDenied);
    expect(await cubit.setEnabled(false), PreferenceSaveOutcome.rejected);
    repository.saveError = const NotificationPreferencesException(NotificationPreferencesFailure.unknown);
    expect(await cubit.setEnabled(false), PreferenceSaveOutcome.failed);
    await pumpEventQueue();
    expect(cubit.state.enabled, isTrue);
    expect(cubit.state.saving, isFalse);
    await cubit.close();
  });

  test('one save at a time', () async {
    final cubit = cubitFor();
    await cubit.start();
    await pumpEventQueue();
    repository.saveGate = Completer<void>();
    final first = cubit.setEnabled(false);
    await pumpEventQueue();
    expect(cubit.state.saving, isTrue);
    expect(cubit.state.canToggle, isFalse);
    expect(await cubit.setEnabled(true), PreferenceSaveOutcome.busy);
    repository.saveGate!.complete();
    expect(await first, PreferenceSaveOutcome.confirmed);
    expect(repository.writes, hasLength(1));
    await cubit.close();
  });

  test('another account signed in meanwhile: nothing is written', () async {
    final cubit = cubitFor();
    await cubit.start();
    await pumpEventQueue();
    account.uid = 'user-b';
    expect(await cubit.setEnabled(false), PreferenceSaveOutcome.accountChanged);
    expect(repository.writes, isEmpty);
    await cubit.close();
  });

  test('a load failure can be retried', () async {
    repository.watchError = const NotificationPreferencesException(NotificationPreferencesFailure.permissionDenied);
    final cubit = cubitFor();
    await cubit.start();
    await pumpEventQueue();
    expect(cubit.state.status, NotificationPreferencesStatus.failure);
    expect(cubit.state.failure, NotificationPreferencesFailure.permissionDenied);

    repository.watchError = null;
    await cubit.start();
    await pumpEventQueue();
    expect(cubit.state.status, NotificationPreferencesStatus.ready);
    await cubit.close();
  });
}
