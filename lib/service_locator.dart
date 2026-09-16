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
import 'package:ae_coaching/features/workout/data/repositories/workout_cascade_deletion_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_template_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_history_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_analytics_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_overview_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_consistency_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/home_workout_overview_cubit.dart';
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

// Workout Programs feature (Phase 5 UI) — completely separate from
// Workout/Measurements/Progress Photos. Only touches
// `workout_programs_$uid` via WorkoutProgramRepository (already built
// in Phase 1).
void initWorkoutPrograms() {
  sl.registerLazySingleton(() => WorkoutProgramRepository());

  sl.registerFactory(
    () => WorkoutProgramCubit(repository: sl(), deletionService: sl()),
  );
}

// Workout Days UI (Phase 6) — separate from all of the above. Only
// touches `workout_templates_$uid` via WorkoutTemplateRepository
// (already built in Phase 2).
void initWorkoutTemplates() {
  sl.registerLazySingleton(() => WorkoutTemplateRepository());

  sl.registerFactory(
    () => WorkoutTemplateCubit(repository: sl(), deletionService: sl()),
  );
}

// Cascade delete (Program/Template → Session → ExerciseSet). Shared by
// WorkoutProgramCubit and WorkoutTemplateCubit — one instance,
// composing the same repository singletons those Cubits already use.
void initWorkoutCascadeDeletion() {
  sl.registerLazySingleton(
    () => WorkoutCascadeDeletionService(
      programRepository: sl(),
      templateRepository: sl(),
      sessionRepository: sl(),
      setRepository: sl(),
    ),
  );
}

// Active Workout Session (Phase 7) — separate from all of the above.
// Registered as a Cubit SINGLETON (not a factory): "is a workout
// currently active" is a cross-cutting, app-wide concern shared by the
// Programs hub, Workout Days screen, and the active-session screen —
// they must all observe the exact same instance to stay in sync.
void initWorkoutSessions() {
  sl.registerLazySingleton(() => WorkoutSessionRepository());
  sl.registerLazySingleton(() => WorkoutSessionCubit(repository: sl()));
}

// Session exercise logging (Phase 8) — separate registration since this
// Cubit is screen-scoped (one active-session screen at a time), unlike
// the app-wide WorkoutSessionCubit singleton above.
void initSessionExercises() {
  sl.registerLazySingleton(() => SessionExerciseRepository());
  sl.registerFactory(() => SessionExerciseCubit(repository: sl(), sessionRepository: sl()));
}

// Workout History (Phase 14) — screen-scoped, read-only. Reuses the
// already-registered WorkoutSessionRepository/SessionExerciseRepository
// singletons rather than creating new instances.
void initWorkoutHistory() {
  sl.registerFactory(() => WorkoutHistoryCubit(sessionRepository: sl()));
}

// Program Analytics (Phase 15) — screen-scoped, read-only. Reuses the
// already-registered Template/Session/Set repository singletons.
void initProgramAnalytics() {
  sl.registerFactory(
    () => ProgramAnalyticsCubit(templateRepository: sl(), sessionRepository: sl(), setRepository: sl()),
  );
}

// Program Overview (Phase 16) — screen-scoped, read-only "This Week"
// summary. Reuses the already-registered Template/Session repository
// singletons.
void initProgramOverview() {
  sl.registerFactory(() => ProgramOverviewCubit(templateRepository: sl(), sessionRepository: sl()));
}

// Rest Timer (Phase 17) — screen-scoped, in-memory only, no storage.
void initRestTimer() {
  sl.registerFactory(() => RestTimerCubit());
}

// Program Consistency (Phase 19) — screen-scoped, read-only. Reuses
// the already-registered WorkoutSessionRepository singleton.
void initProgramConsistency() {
  sl.registerFactory(() => ProgramConsistencyCubit(sessionRepository: sl()));
}

// Home Workout Overview — redesigned Home workout section, reusing
// the already-registered Program/Template/Session/Set repository
// singletons. Screen-scoped factory (Hom is a single long-lived
// screen, but a fresh factory instance is still the established
// pattern for every other screen-scoped Cubit in this feature).
void initHomeWorkoutOverview() {
  sl.registerFactory(
    () => HomeWorkoutOverviewCubit(
      sessionRepository: sl(),
      programRepository: sl(),
      templateRepository: sl(),
      setRepository: sl(),
    ),
  );
}
