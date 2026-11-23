import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/core/notifications/fcm_device_service.dart';
import 'package:ae_coaching/features/account_deletion/application/account_deletion_lifecycle.dart';
import 'package:ae_coaching/features/account_deletion/application/local_account_data_wiper.dart';
import 'package:ae_coaching/features/account_deletion/data/firebase_account_deletion_repository.dart';
import 'package:ae_coaching/features/account_deletion/domain/account_deletion.dart';
import 'package:ae_coaching/features/account_deletion/presentation/cubit/account_deletion_cubit.dart';
import 'package:ae_coaching/features/inactivity_reminders/application/inactivity_reminder_scheduler.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

// Account deletion (Spark plan): deleted in the app after re-authentication
// (Firestore data first, the Auth account last), then this device's data.
void initAccountDeletion() {
  sl.registerLazySingleton<AccountDeletionRepository>(() => FirebaseAccountDeletionRepository());
  sl.registerLazySingleton(
    () => LocalAccountDataWiper(
      storage: sl(),
      profilePhotos: sl(),
      authBox: Hive.box('authBox'),
      session: sl(),
      documentsDirectory: getApplicationDocumentsDirectory,
      accountHooks: [
        (_) => sl<InactivityReminderScheduler>().deactivate(),
        (_) async => sl<WorkoutSessionCubit>().reset(),
        (uid) => sl<FcmDeviceService>().forgetDeletedAccount(uid),
      ],
    ),
  );
  sl.registerLazySingleton(
    () => AccountDeletionLifecycle(
      authBox: Hive.box('authBox'),
      repository: sl(),
      wiper: sl(),
      currentUid: () => FirebaseAuth.instance.currentUser?.uid,
      signOut: () => FirebaseAuth.instance.signOut(),
      clearFirestoreCache: () => FirebaseFirestore.instance.clearPersistence(),
    ),
  );
  sl.registerFactory(
    () => AccountDeletionCubit(
      repository: sl(),
      lifecycle: sl(),
      currentUid: () => FirebaseAuth.instance.currentUser?.uid,
      onStarted: () => sl<InactivityReminderScheduler>().deactivate(),
    ),
  );
}
