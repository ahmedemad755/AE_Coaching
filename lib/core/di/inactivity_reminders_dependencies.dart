import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/core/notifications/fcm_device_service.dart';
import 'package:ae_coaching/features/account_deletion/application/account_deletion_lifecycle.dart';
import 'package:ae_coaching/features/inactivity_reminders/application/inactivity_reminder_scheduler.dart';
import 'package:ae_coaching/features/inactivity_reminders/data/workout_activity_reader.dart';
import 'package:ae_coaching/features/notification_settings/data/device_time_zone.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Local inactivity reminders (Spark plan): scheduled on the device from the
// account's own workout history; the server-side delivery stays disabled.
void initInactivityReminders() {
  sl.registerLazySingleton(() => WorkoutActivityReader(storage: sl()));
  sl.registerLazySingleton(
    () => InactivityReminderScheduler(
      notifications: sl(),
      activity: sl(),
      preferences: sl(),
      notificationsAllowed: () async {
        final status = await sl<FcmDeviceService>().notificationAuthorizationStatus();
        return status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional;
      },
      location: () => sl<DeviceTimeZone>().currentLocation(),
      languageCode: () => Hive.box('authBox').get('appLocale', defaultValue: 'ar') as String,
      deletionPending: (uid) => sl<AccountDeletionLifecycle>().isInProgress(uid),
      authBox: Hive.box('authBox'),
    ),
  );
}
