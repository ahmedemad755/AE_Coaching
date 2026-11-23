import 'package:ae_coaching/core/notifications/fcm_notification_routing.dart';
import 'package:ae_coaching/core/notifications/legacy_inactivity_reminder_cleanup.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// An Android notification channel the app owns.
class AppNotificationChannel {
  const AppNotificationChannel({required this.id, required this.name, required this.description});

  final String id;
  final String name;
  final String description;
}

abstract final class AppNotificationChannels {
  /// Server-sent workout inactivity reminders. The id is a contract shared
  /// with Cloud Functions (`androidChannelId`) and AndroidManifest.xml
  /// (`default_notification_channel_id`); it is the same id the retired
  /// local reminders used, so existing installs keep the user's channel
  /// settings. Never rename it.
  static const inactivityReminders = AppNotificationChannel(
    id: 'inactivity_reminders',
    name: 'Inactivity reminders',
    description: 'Reminders to return to your workout routine.',
  );
}

/// The few local-notification operations the app still needs.
abstract interface class LocalNotificationsGateway {
  /// [onTap] receives the payload of a tapped local notification, including
  /// the one that launched the app.
  Future<void> initialize({required void Function(String? payload) onTap});
  Future<void> ensureAndroidChannel(AppNotificationChannel channel);

  /// One local notification at [at] (an absolute instant; inexact on
  /// Android, so no exact-alarm permission is needed), in [channel].
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    required AppNotificationChannel channel,
    required String payload,
  });
  Future<void> cancel(int id);
}

class FlutterLocalNotificationsGateway implements LocalNotificationsGateway {
  FlutterLocalNotificationsGateway({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Default small icon. The app icon exists only as a mipmap
  /// (`res/mipmap-*/launcher_icon`); a bare name is looked up as a drawable
  /// and fails, which aborted plugin setup and with it channel creation.
  static const androidDefaultIcon = '@mipmap/launcher_icon';

  @override
  Future<void> initialize({required void Function(String? payload) onTap}) async {
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings(androidDefaultIcon),
        // Permission is requested once, by FcmDeviceService, never here.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) onTap(launch?.notificationResponse?.payload);
  }

  @override
  Future<void> ensureAndroidChannel(AppNotificationChannel channel) async {
    // Creating an existing channel only updates its name and description;
    // the user's importance/sound choices are kept by Android.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            channel.id,
            channel.name,
            description: channel.description,
            importance: Importance.defaultImportance,
          ),
        );
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    required AppNotificationChannel channel,
    required String payload,
  }) => _plugin.zonedSchedule(
    id,
    title,
    body,
    at,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    // Inexact: may arrive a few minutes late under Doze, but needs no
    // SCHEDULE_EXACT_ALARM permission (a reminder does not need the minute).
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    payload: payload,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);
}

/// Startup work for local notifications: the channel FCM reminders are
/// displayed in exists before the first one arrives, taps on reminders
/// already in the tray still open Home, and the retired local reminder is
/// cleaned up. Failures are logged, never fatal.
class LocalNotificationsBootstrap {
  LocalNotificationsBootstrap({
    required LocalNotificationsGateway notifications,
    required LegacyInactivityReminderCleanup legacyCleanup,
    void Function()? openHome,
  }) : _notifications = notifications,
       _legacyCleanup = legacyCleanup,
       _openHome = openHome ?? AppRouter.openHomeFromNotification;

  final LocalNotificationsGateway _notifications;
  final LegacyInactivityReminderCleanup _legacyCleanup;
  final void Function() _openHome;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    try {
      await _notifications.initialize(onTap: _handleTap);
      await _notifications.ensureAndroidChannel(AppNotificationChannels.inactivityReminders);
    } catch (error) {
      debugPrint('Local notification setup failed: $error');
    }
    try {
      await _legacyCleanup.run();
    } catch (error) {
      // No marker is written, so the cleanup runs again next launch.
      debugPrint('Legacy inactivity reminder cleanup failed: $error');
    }
  }

  void _handleTap(String? payload) {
    if (FcmNotificationRouting.destinationForData({'type': payload}) == FcmNotificationDestination.home) {
      _openHome();
    }
  }
}
