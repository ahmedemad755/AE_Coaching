import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/features/measurements/data/datasources/measurement_remote_data_source.dart';
import 'package:ae_coaching/features/measurements/data/repositories/measurement_repository.dart';
import 'package:ae_coaching/features/measurements/presentation/cubit/measurement_cubit.dart';

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
    () => MeasurementRepository(remoteDataSource: sl(), storageManager: sl()),
  );

  sl.registerFactory(() => MeasurementCubit(repository: sl()));
}
