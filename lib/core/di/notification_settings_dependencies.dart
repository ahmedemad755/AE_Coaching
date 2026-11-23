import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/features/notification_settings/application/notification_preferences_sync.dart';
import 'package:ae_coaching/features/notification_settings/data/device_time_zone.dart';
import 'package:ae_coaching/features/notification_settings/data/firestore_notification_preferences_repository.dart';
import 'package:ae_coaching/features/notification_settings/data/verified_account.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences_repository.dart';

// Server-driven workout inactivity reminder preferences
// (`users/{uid}/settings/notifications`). The Settings screen creates its
// own NotificationPreferencesCubit from these, bound to the app language.
void initNotificationSettings() {
  sl.registerLazySingleton<NotificationPreferencesRepository>(
    () => FirestoreNotificationPreferencesRepository(),
  );
  sl.registerLazySingleton(() => DeviceTimeZone());
  sl.registerLazySingleton(() => VerifiedAccount());
  sl.registerLazySingleton(
    () => NotificationPreferencesSync(
      repository: sl(),
      deviceTimeZone: sl(),
      account: sl(),
      legacy: sl(),
    ),
  );
}
