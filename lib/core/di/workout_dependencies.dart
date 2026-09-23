import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_repository_impl.dart';
import 'package:ae_coaching/features/workout/domain/repositories/workout_repository.dart';
import 'package:ae_coaching/features/workout/domain/usecases/delete_and_sync_workout_usecase.dart';
import 'package:ae_coaching/features/workout/domain/usecases/delete_multiple_and_sync_usecase.dart';
import 'package:ae_coaching/features/workout/domain/usecases/save_and_sync_workout_usecase.dart';
import 'package:ae_coaching/features/workout/domain/usecases/fetch_and_sync_from_remote_usecase.dart'; // الـ Import الجديد
import 'package:ae_coaching/features/workout/presentation/bloc/workout_cubit.dart';

/// The original, flat `sets_$uid` ExerciseSet stack — kept separate
/// from `workout_programs_dependencies.dart`'s Program/Template/
/// Session/SessionExercise stack, which is a distinct, later feature
/// that never touches this repository.
void initWorkout() {
  // 1. UseCases
  sl.registerLazySingleton(() => SaveAndSyncWorkoutUseCase(sl()));
  sl.registerLazySingleton(() => DeleteAndSyncWorkoutUseCase(sl()));
  sl.registerLazySingleton(() => DeleteMultipleAndSyncUseCase(sl()));
  sl.registerLazySingleton(
    () => FetchAndSyncFromRemoteUseCase(sl()),
  ); // تسجيل الـ UseCase الجديد

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
      fetchAndSyncFromRemoteUseCase:
          sl(), // حقن الحقل الجديد تلقائياً عبر GetIt
      sessionStorage: sl(),
      storageManager: sl(),
    ),
  );
}
