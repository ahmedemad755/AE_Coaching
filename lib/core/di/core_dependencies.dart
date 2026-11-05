import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/core/notifications/fcm_device_service.dart';
import 'package:ae_coaching/core/notifications/inactivity_reminder_service.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/profile/data/local_profile_photo_store.dart';
import 'package:ae_coaching/features/profile/data/user_profile_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Cross-cutting, not tied to any one feature — SessionStorage wraps the
// already-open global `authBox` (main.dart awaits Hive.openBox('authBox')
// before runApp(), so by the time anything actually resolves this lazy
// singleton via sl(), the box is guaranteed open, exactly like every
// other init*() registration below that doesn't run until first use).
//
// UserStorageManager is the ONE production lifecycle owner for every
// per-user Hive box — deliberately NOT a static/shared singleton on the
// class itself (Stage 3 design correction); this GetIt registration is
// the only place that decides what "the" production instance is. Every
// repository/Cubit that needs it receives it by constructor injection
// below, never by calling GetIt itself.
void initCore() {
  sl.registerLazySingleton(() => SessionStorage(Hive.box('authBox')));
  sl.registerLazySingleton(() => UserStorageManager());
  sl.registerLazySingleton(() => FcmDeviceService());
  sl.registerLazySingleton(() => InactivityReminderService());
  sl.registerLazySingleton(() => LocalProfilePhotoStore(Hive.box('authBox')));
  sl.registerLazySingleton(() => UserProfileRepository());
}
