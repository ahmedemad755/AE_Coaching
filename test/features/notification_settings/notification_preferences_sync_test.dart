import 'dart:io';

import 'package:ae_coaching/core/notifications/legacy_inactivity_reminder_cleanup.dart';
import 'package:ae_coaching/core/notifications/local_notifications.dart';
import 'package:ae_coaching/features/notification_settings/application/notification_preferences_sync.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'notification_settings_fakes.dart';

class _NoNotifications implements LocalNotificationsGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late Box box;
  late FakeNotificationPreferencesRepository repository;
  late FakeVerifiedAccount account;
  late LegacyInactivityReminderCleanup legacy;

  NotificationPreferencesSync syncWith({String? deviceZone = 'Europe/Paris'}) => NotificationPreferencesSync(
    repository: repository,
    deviceTimeZone: fakeDeviceTimeZone(deviceZone),
    account: account,
    legacy: legacy,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('preference_sync_test_');
    Hive.init(directory.path);
    box = await Hive.openBox('authBox');
    repository = FakeNotificationPreferencesRepository();
    account = FakeVerifiedAccount('user-a');
    legacy = LegacyInactivityReminderCleanup(notifications: _NoNotifications(), box: box);
  });

  tearDown(() async {
    await repository.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('first session: creates the document with app language and device zone', () async {
    await syncWith().syncCurrentAccount(languageCode: 'en');
    expect(repository.writes, [
      (
        'user-a',
        const NotificationPreferences(
          inactivityRemindersEnabled: true,
          language: ReminderLanguage.en,
          timeZone: 'Europe/Paris',
        ),
      ),
    ]);
  });

  test('an account that turned the old on-device reminder off stays off', () async {
    await box.put('inactivityRemindersEnabled:user-a', false);
    await box.put('inactivityRemindersEnabled:user-b', true); // another account
    await syncWith().syncCurrentAccount(languageCode: 'ar');
    expect(repository.documents['user-a']!.inactivityRemindersEnabled, isFalse);
    expect(box.containsKey('inactivityRemindersEnabled:user-a'), isFalse); // carried over
    expect(box.get('inactivityRemindersEnabled:user-b'), isTrue); // untouched
  });

  test('never overrides an existing choice; writes only when language or zone differ', () async {
    repository.documents['user-a'] = const NotificationPreferences(
      inactivityRemindersEnabled: false,
      language: ReminderLanguage.ar,
      timeZone: 'Europe/Paris',
    );
    await box.put('inactivityRemindersEnabled:user-a', true); // stale legacy value
    await syncWith().syncCurrentAccount(languageCode: 'ar');
    expect(repository.writes, isEmpty); // nothing changed

    await syncWith().syncCurrentAccount(languageCode: 'en');
    expect(repository.writes.single.$2, const NotificationPreferences(
      inactivityRemindersEnabled: false,
      language: ReminderLanguage.en,
      timeZone: 'Europe/Paris',
    ));
    expect(box.containsKey('inactivityRemindersEnabled:user-a'), isFalse);
  });

  test('an unusable device zone keeps the stored zone', () async {
    repository.documents['user-a'] = const NotificationPreferences(
      inactivityRemindersEnabled: true,
      language: ReminderLanguage.ar,
      timeZone: 'Asia/Riyadh',
    );
    await syncWith(deviceZone: 'GMT+03:00').syncCurrentAccount(languageCode: 'ar');
    expect(repository.writes, isEmpty);
  });

  test('no verified account: nothing is read or written', () async {
    account.uid = null;
    await syncWith().syncCurrentAccount(languageCode: 'en');
    expect(repository.writes, isEmpty);
  });

  test('offline or rejected: never throws, keeps the legacy choice for the next try', () async {
    await box.put('inactivityRemindersEnabled:user-a', false);
    for (final failure in NotificationPreferencesFailure.values) {
      repository.reconcileError = NotificationPreferencesException(failure);
      await syncWith().syncCurrentAccount(languageCode: 'ar');
    }
    expect(repository.writes, isEmpty);
    expect(box.get('inactivityRemindersEnabled:user-a'), isFalse);

    repository.reconcileError = null; // back online, next session
    await syncWith().syncCurrentAccount(languageCode: 'ar');
    expect(repository.documents['user-a']!.inactivityRemindersEnabled, isFalse);
  });

  test('an account switch before writing never writes under either account', () async {
    final sync = NotificationPreferencesSync(
      repository: repository,
      deviceTimeZone: fakeDeviceTimeZone('Europe/Paris'),
      account: account,
      legacy: legacy,
    );
    // The account changes while the device zone is being resolved.
    final switching = _SwitchingAccount(account, after: 1, to: 'user-b');
    await NotificationPreferencesSync(
      repository: repository,
      deviceTimeZone: fakeDeviceTimeZone('Europe/Paris'),
      account: switching,
      legacy: legacy,
    ).syncCurrentAccount(languageCode: 'en');
    expect(repository.writes, isEmpty);
    await sync.syncCurrentAccount(languageCode: 'en'); // the new session syncs its own account
    expect(repository.writes.map((w) => w.$1), ['user-b']);
  });

  test('runs are serialized', () async {
    final sync = syncWith();
    await Future.wait([
      sync.syncCurrentAccount(languageCode: 'en'),
      sync.syncCurrentAccount(languageCode: 'ar'),
    ]);
    expect(repository.writes.map((w) => w.$2.language), [ReminderLanguage.en, ReminderLanguage.ar]);
  });
}

/// Returns the original uid [after] times, then [to] (and updates [base]).
class _SwitchingAccount extends FakeVerifiedAccount {
  _SwitchingAccount(this.base, {required this.after, required this.to}) : super(base.uid);
  final FakeVerifiedAccount base;
  final int after;
  final String to;

  @override
  String? currentUid() {
    reads += 1;
    if (reads > after) {
      base.uid = to;
      return to;
    }
    return uid;
  }
}
