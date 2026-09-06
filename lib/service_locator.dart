import 'package:ae_coaching/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ae_coaching/auth/data/repositories/auth_repository_impl.dart';
import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';
import 'package:ae_coaching/auth/domain/usecases/login_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_phone_password_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/register_with_otp_usecase.dart';
import 'package:ae_coaching/auth/domain/usecases/request_otp_usecase.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_repository_impl.dart';
import 'package:ae_coaching/features/workout/domain/repositories/workout_repository.dart';
import 'package:ae_coaching/features/workout/domain/usecases/delete_and_sync_workout_usecase.dart';
import 'package:ae_coaching/features/workout/domain/usecases/delete_multiple_and_sync_usecase.dart';
import 'package:ae_coaching/features/workout/domain/usecases/save_and_sync_workout_usecase.dart';
import 'package:ae_coaching/features/workout/domain/usecases/fetch_and_sync_from_remote_usecase.dart'; // الـ Import الجديد
import 'package:ae_coaching/features/workout/presentation/bloc/workout_cubit.dart';
import 'package:ae_coaching/features/measurements/data/datasources/measurement_remote_data_source.dart';
import 'package:ae_coaching/features/measurements/data/repositories/measurement_repository.dart';
import 'package:ae_coaching/features/measurements/presentation/cubit/measurement_cubit.dart';
import 'package:ae_coaching/features/progress_photos/data/repositories/progress_photo_repository.dart';
import 'package:ae_coaching/features/progress_photos/presentation/cubit/progress_photo_cubit.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

void initAuth() {
  // 1. UseCases
  sl.registerLazySingleton(() => RequestOtpUseCase(sl()));
  sl.registerLazySingleton(() => RegisterWithOtpUseCase(sl()));
  sl.registerLazySingleton(() => RegisterWithPhonePasswordUseCase(sl()));
  sl.registerLazySingleton(() => LoginUseCase(sl()));

  // 2. Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // 3. Data Source
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(),
  );

  // الـ AuthCubit Factory
  sl.registerFactory(() => AuthCubit(
        requestOtpUseCase: sl(),
        registerWithOtpUseCase: sl(),
        registerWithPhonePasswordUseCase: sl(),
        loginUseCase: sl(),
      ));
}

void initWorkout() {
  // 1. UseCases
  sl.registerLazySingleton(() => SaveAndSyncWorkoutUseCase(sl()));
  sl.registerLazySingleton(() => DeleteAndSyncWorkoutUseCase(sl()));
  sl.registerLazySingleton(() => DeleteMultipleAndSyncUseCase(sl()));
  sl.registerLazySingleton(() => FetchAndSyncFromRemoteUseCase(sl())); // تسجيل الـ UseCase الجديد

  // 2. Repository
  sl.registerLazySingleton<WorkoutRepository>(
    () => WorkoutRepositoryImpl(remoteDataSource: sl()),
  );

  // 3. Data Source
  sl.registerLazySingleton<WorkoutRemoteDataSource>(
    () => WorkoutRemoteDataSourceImpl(),
  );

  // 4. Bloc / Cubit Factory المعدل لتمرير الحقل الرابع
  sl.registerFactory(
    () => WorkoutCubit(
      saveAndSyncWorkoutUseCase: sl(),
      deleteAndSyncWorkoutUseCase: sl(),
      deleteMultipleAndSyncUseCase: sl(),
      fetchAndSyncFromRemoteUseCase: sl(), // حقن الحقل الجديد تلقائياً عبر GetIt
    ),
  );
}

// Body Measurements feature — completely separate from initWorkout().
// Registers its own repository/Cubit so measurement CRUD never touches
// WorkoutCubit or the workout Hive boxes. Mirrors the Workout DI shape:
// a Firestore-backed remote data source behind the repository so
// check-ins survive logout / app kill / uninstall, keyed per Firebase
// UID exactly like exercise_sets already are.
void initMeasurements() {
  sl.registerLazySingleton<MeasurementRemoteDataSource>(
    () => MeasurementRemoteDataSourceImpl(),
  );

  sl.registerLazySingleton(
    () => MeasurementRepository(remoteDataSource: sl()),
  );

  sl.registerFactory(
    () => MeasurementCubit(repository: sl()),
  );
}

// Progress Photos feature — completely separate from Workout and
// Measurements. Local-only by design (per the user's explicit choice):
// no remote data source, photos live in the per-user
// `progress_photos_$uid` Hive box + the app's documents directory.
void initProgressPhotos() {
  sl.registerLazySingleton(() => ProgressPhotoRepository());

  sl.registerFactory(
    () => ProgressPhotoCubit(repository: sl()),
  );
}
