import 'dart:io';

import 'package:ae_coaching/core/notifications/legacy_inactivity_reminder_cleanup.dart';
import 'package:ae_coaching/core/notifications/local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeNotifications implements LocalNotificationsGateway {
  final List<int> cancelled = [];
  final List<String> channels = [];
  void Function(String? payload)? onTap;
  bool failInitialize = false;
  bool failCancel = false;
  int initializeCalls = 0;

  @override
  Future<void> initialize({required void Function(String? payload) onTap}) async {
    initializeCalls += 1;
    if (failInitialize) throw StateError('plugin unavailable');
    this.onTap = onTap;
  }

  @override
  Future<void> ensureAndroidChannel(AppNotificationChannel channel) async => channels.add(channel.id);

  @override
  Future<void> cancel(int id) async {
    if (failCancel) throw StateError('cancel failed');
    cancelled.add(id);
  }
}

void main() {
  late Directory directory;
  late Box box;
  late _FakeNotifications notifications;
  late LegacyInactivityReminderCleanup cleanup;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('legacy_reminder_test_');
    Hive.init(directory.path);
    box = await Hive.openBox('authBox');
    notifications = _FakeNotifications();
    cleanup = LegacyInactivityReminderCleanup(notifications: notifications, box: box);
    // State left by the retired InactivityReminderService for two accounts,
    // plus unrelated app keys.
    await box.putAll({
      'localInactivityNotificationUid': 'user-a',
      'inactivityLanguage:user-a': 'ar',
      'inactivityLastCompletedAt:user-a': 1,
      'inactivityCycleId:user-a': 's1',
      'inactivityScheduledCycleId:user-a': 's1',
      'inactivityCycleId:user-b': 's9',
      'inactivityRemindersEnabled:user-a': false,
      'inactivityRemindersEnabled:user-b': true,
      'appLocale': 'en',
      'isLoggedIn': true,
      'currentUserUid': 'user-a',
      'fcmPermissionPrompted': true,
      'themeMode:user-a': 'dark',
    });
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  group('LegacyInactivityReminderCleanup', () {
    test('cancels only the legacy notification id and deletes only its scheduling keys', () async {
      await cleanup.run();
      expect(notifications.cancelled, [LegacyInactivityReminderCleanup.legacyNotificationId]);
      expect(notifications.cancelled, [7301]);
      expect(box.keys.toSet(), {
        // The on/off choices wait to be carried over to the server.
        'inactivityRemindersEnabled:user-a',
        'inactivityRemindersEnabled:user-b',
        // Unrelated keys are untouched.
        'appLocale',
        'isLoggedIn',
        'currentUserUid',
        'fcmPermissionPrompted',
        'themeMode:user-a',
        LegacyInactivityReminderCleanup.retiredMarkerKey,
      });
      expect(cleanup.isRetired, isTrue);
    });

    test('idempotent across restarts: a second run does nothing', () async {
      await cleanup.run();
      await cleanup.run();
      await LegacyInactivityReminderCleanup(notifications: notifications, box: box).run();
      expect(notifications.cancelled, [7301]);
    });

    test('a failed cancel leaves everything for the next launch', () async {
      notifications.failCancel = true;
      await expectLater(cleanup.run(), throwsStateError);
      expect(cleanup.isRetired, isFalse);
      expect(box.get('inactivityCycleId:user-a'), 's1');

      notifications.failCancel = false;
      await cleanup.run();
      expect(cleanup.isRetired, isTrue);
      expect(box.containsKey('inactivityCycleId:user-a'), isFalse);
    });

    test('exposes and forgets the legacy choice per account', () async {
      expect(cleanup.legacyEnabledFor('user-a'), isFalse);
      expect(cleanup.legacyEnabledFor('user-b'), isTrue);
      expect(cleanup.legacyEnabledFor('user-c'), isNull);
      await cleanup.forgetUser('user-a');
      expect(cleanup.legacyEnabledFor('user-a'), isNull);
      expect(cleanup.legacyEnabledFor('user-b'), isTrue);
    });
  });

  group('LocalNotificationsBootstrap', () {
    test('creates the FCM reminder channel, then retires the legacy reminder', () async {
      var homeOpened = 0;
      final bootstrap = LocalNotificationsBootstrap(
        notifications: notifications,
        legacyCleanup: cleanup,
        openHome: () => homeOpened += 1,
      );
      await bootstrap.initialize();
      await bootstrap.initialize(); // once per process
      expect(notifications.initializeCalls, 1);
      expect(notifications.channels, ['inactivity_reminders']);
      expect(cleanup.isRetired, isTrue);

      // A legacy reminder still in the tray opens Home; anything else does not.
      notifications.onTap!('inactivity_reminder');
      notifications.onTap!('something_else');
      notifications.onTap!(null);
      expect(homeOpened, 1);
    });

    test('the channel id matches the server and manifest contract', () {
      expect(AppNotificationChannels.inactivityReminders.id, 'inactivity_reminders');
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(
        RegExp(
          r'android:name="com\.google\.firebase\.messaging\.default_notification_channel_id"\s+'
          r'android:value="inactivity_reminders"',
        ).hasMatch(manifest),
        isTrue,
      );
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      // Retired with the local reminder: nothing can post or re-arm it.
      expect(manifest, isNot(contains('ScheduledNotificationReceiver')));
      expect(manifest, isNot(contains('ScheduledNotificationBootReceiver')));
    });

    test('the default notification icon names a resource that exists', () {
      // Device bug: 'launcher_icon' (no @mipmap/) is looked up as a
      // drawable, plugin setup failed and the reminder channel was never
      // created.
      const icon = FlutterLocalNotificationsGateway.androidDefaultIcon;
      final match = RegExp(r'^@(mipmap|drawable)/([a-z0-9_]+)$').firstMatch(icon);
      expect(match, isNotNull, reason: 'use @mipmap/name or @drawable/name');
      final folderPrefix = match!.group(1)!;
      final name = match.group(2)!;
      final found = Directory('android/app/src/main/res')
          .listSync()
          .whereType<Directory>()
          .where((dir) => dir.uri.pathSegments.where((s) => s.isNotEmpty).last.startsWith(folderPrefix))
          .expand((dir) => dir.listSync().whereType<File>())
          .any((file) => file.uri.pathSegments.last.split('.').first == name);
      expect(found, isTrue, reason: '$icon not found under res/$folderPrefix-*');
    });

    test('a plugin failure is not fatal and the cleanup still runs', () async {
      notifications.failInitialize = true;
      await LocalNotificationsBootstrap(notifications: notifications, legacyCleanup: cleanup, openHome: () {})
          .initialize();
      expect(cleanup.isRetired, isTrue);
    });

    test('a cleanup failure is not fatal either', () async {
      notifications.failCancel = true;
      await LocalNotificationsBootstrap(notifications: notifications, legacyCleanup: cleanup, openHome: () {})
          .initialize();
      expect(notifications.channels, ['inactivity_reminders']);
      expect(cleanup.isRetired, isFalse);
    });
  });
}
