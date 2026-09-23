import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_repository_impl.dart';
import 'package:ae_coaching/features/workout/domain/repositories/workout_repository.dart';
import 'package:ae_coaching/features/workout/presentation/bloc/workout_cubit.dart';

/// The original, flat `sets_$uid` ExerciseSet stack — kept separate
/// from `workout_programs_dependencies.dart`'s Program/Template/
/// Session/SessionExercise stack, which is a distinct, later feature
/// that never touches this repository.
///
/// Stage 7: WorkoutCubit used to depend on four use-case wrappers
/// (SaveAndSyncWorkoutUseCase, DeleteAndSyncWorkoutUseCase,
/// DeleteMultipleAndSyncUseCase, FetchAndSyncFromRemoteUseCase), each a
/// pure single-repository-method pass-through — removed; WorkoutCubit
/// now receives WorkoutRepository directly, matching every other
/// workout Cubit in this app.
void initWorkout() {
  // 1. Repository
  sl.registerLazySingleton<WorkoutRepository>(
    () => WorkoutRepositoryImpl(remoteDataSource: sl()),
  );

  // 2. Data Source
  sl.registerLazySingleton<WorkoutRemoteDataSource>(
    () => WorkoutRemoteDataSourceImpl(),
  );

  // 3. Bloc / Cubit Factory
  sl.registerFactory(
    () => WorkoutCubit(
      repository: sl(),
      sessionStorage: sl(),
      storageManager: sl(),
    ),
  );
}
