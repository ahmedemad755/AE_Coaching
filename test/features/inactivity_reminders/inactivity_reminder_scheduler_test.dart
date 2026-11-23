import 'dart:async';
import 'dart:io';

import 'package:ae_coaching/core/notifications/local_notifications.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/inactivity_reminders/application/inactivity_reminder_scheduler.dart';
import 'package:ae_coaching/features/inactivity_reminders/data/workout_activity_reader.dart';
import 'package:ae_coaching/features/notification_settings/data/device_time_zone.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;

import '../notification_settings/notification_settings_fakes.dart';

class _FakeNotifications implements LocalNotificationsGateway {
  /// What the OS would have pending: id → (title, time).
  final Map<int, (String, tz.TZDateTime)> pending = {};
  int schedules = 0;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    required AppNotificationChannel channel,
    required String payload,
  }) async {
    expect(channel.id, 'inactivity_reminders');
    expect(payload, 'inactivity_reminder');
    expect('$title $body', isNot(contains('@'))); // no personal data
    schedules += 1;
    pending[id] = (title, at);
  }

  @override
  Future<void> cancel(int id) async => pending.remove(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeActivity extends WorkoutActivityReader {
  _FakeActivity() : super(storage: UserStorageManager());

  final Map<String, DateTime> latest = {};
  final _changes = StreamController<String>.broadcast();

  void record(String uid, DateTime at) {
    latest[uid] = at;
    _changes.add(uid);
  }

  @override
  Future<DateTime?> latestActivity(String uid) async => latest[uid];

  @override
  Stream<void> changes(String uid) => _changes.stream.where((changed) => changed == uid);
}

void main() {
  late Directory directory;
  late Box box;
  late _FakeNotifications notifications;
  late _FakeActivity activity;
  late FakeNotificationPreferencesRepository preferences;
  late InactivityReminderScheduler scheduler;
  var allowed = true;
  var language = 'en';
  var zone = 'Africa/Cairo';
  final pendingDeletion = <String>{};
  final saturday18 = DateTime.utc(2026, 11, 7, 16); // Sat 18:00 Cairo

  setUpAll(DeviceTimeZone.ensureDatabaseLoaded);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('reminder_scheduler_test_');
    Hive.init(directory.path);
    box = await Hive.openBox('authBox');
    notifications = _FakeNotifications();
    activity = _FakeActivity();
    preferences = FakeNotificationPreferencesRepository();
    allowed = true;
    language = 'en';
    zone = 'Africa/Cairo';
    pendingDeletion.clear();
    scheduler = InactivityReminderScheduler(
      notifications: notifications,
      activity: activity,
      preferences: preferences,
      notificationsAllowed: () async => allowed,
      location: () async => tz.getLocation(zone),
      languageCode: () => language,
      deletionPending: pendingDeletion.contains,
      authBox: box,
      clock: () => saturday18,
      observeLifecycle: false,
    );
  });

  tearDown(() async {
    await scheduler.deactivate();
    await preferences.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  List<int> pendingIds() => notifications.pending.keys.toList()..sort();

  test('schedules the plan on ids 7401–7406 in the app language, for this account', () async {
    activity.latest['alice'] = saturday18;
    await scheduler.activate('alice');
    expect(pendingIds(), [7401, 7402, 7403, 7404, 7405, 7406]);
    // The copy lives in the ARB files and can change; the language must not.
    final en = lookupAppLocalizations(const Locale('en'));
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(en.inactivityReminderTitle1, isNot(ar.inactivityReminderTitle1));
    final first = notifications.pending[7401]!;
    expect(first.$1, en.inactivityReminderTitle1);
    expect(first.$2.difference(saturday18), const Duration(hours: 48));
    expect(box.get(InactivityReminderScheduler.ownerKey), 'alice');

    language = 'ar';
    await scheduler.refresh();
    expect(notifications.pending[7401]!.$1, ar.inactivityReminderTitle1);
  });

  test('no duplicates: rescheduling replaces the same ids', () async {
    activity.latest['alice'] = saturday18;
    await scheduler.activate('alice');
    await Future.wait([scheduler.refresh(), scheduler.refresh(), scheduler.refresh()]);
    expect(pendingIds(), hasLength(6));
  });

  test('new workout activity reschedules from it', () async {
    activity.latest['alice'] = saturday18;
    await scheduler.activate('alice');
    final workout = saturday18.add(const Duration(hours: 24)); // Sun 18:00
    activity.record('alice', workout);
    await pumpEventQueue();
    await scheduler.refresh();
    expect(notifications.pending[7401]!.$2.difference(workout), const Duration(hours: 48));
  });

  test('the reminder toggle: off cancels everything, on schedules again', () async {
    activity.latest['alice'] = saturday18;
    preferences.documents['alice'] = NotificationPreferences.defaults;
    await scheduler.activate('alice');
    expect(pendingIds(), hasLength(6));
    await preferences.save('alice', NotificationPreferences.defaults.copyWith(inactivityRemindersEnabled: false));
    await pumpEventQueue();
    await scheduler.refresh();
    expect(pendingIds(), isEmpty);
    await preferences.save('alice', NotificationPreferences.defaults);
    await pumpEventQueue();
    await scheduler.refresh();
    expect(pendingIds(), hasLength(6));
  });

  test('nothing without notification permission, history, or while deletion is pending', () async {
    activity.latest['alice'] = saturday18;
    allowed = false;
    await scheduler.activate('alice');
    expect(pendingIds(), isEmpty);
    allowed = true;
    pendingDeletion.add('alice');
    await scheduler.refresh();
    expect(pendingIds(), isEmpty);
    pendingDeletion.clear();
    await scheduler.activate('bob'); // no workout history
    expect(pendingIds(), isEmpty);
  });

  test('logout cancels the account reminders and forgets the owner', () async {
    activity.latest['alice'] = saturday18;
    await scheduler.activate('alice');
    await scheduler.deactivate();
    expect(pendingIds(), isEmpty);
    expect(box.get(InactivityReminderScheduler.ownerKey), isNull);
    activity.record('alice', saturday18.add(const Duration(hours: 1)));
    await pumpEventQueue();
    expect(pendingIds(), isEmpty); // no longer watching
  });

  test('account switch: the previous account reminders are replaced, never mixed', () async {
    activity.latest['alice'] = saturday18;
    activity.latest['bob'] = saturday18.add(const Duration(hours: 2)); // 20:00
    await scheduler.activate('alice');
    await scheduler.activate('bob');
    expect(pendingIds(), hasLength(6));
    expect(notifications.pending[7401]!.$2.difference(activity.latest['bob']!), const Duration(hours: 48));
    expect(box.get(InactivityReminderScheduler.ownerKey), 'bob');
  });

  test('app start: reminders of an account that is not signed in are cancelled', () async {
    activity.latest['alice'] = saturday18;
    await scheduler.activate('alice');
    await scheduler.reconcileAtStartup('alice');
    expect(pendingIds(), hasLength(6)); // same account: kept
    await scheduler.reconcileAtStartup(null);
    expect(pendingIds(), isEmpty);
    expect(box.get(InactivityReminderScheduler.ownerKey), isNull);
  });

  test('a time-zone change moves reminders into the new local window', () async {
    activity.latest['alice'] = DateTime.utc(2026, 11, 7, 20, 30); // 22:30 Cairo
    await scheduler.activate('alice');
    expect(notifications.pending[7401]!.$2.hour, 10); // Tue 10:00 Cairo
    zone = 'Asia/Tokyo'; // traveled; resume → refresh
    await scheduler.refresh();
    final at = notifications.pending[7401]!.$2;
    expect(at.location.name, 'Asia/Tokyo');
    expect(at.hour, inInclusiveRange(10, 20));
  });
}
