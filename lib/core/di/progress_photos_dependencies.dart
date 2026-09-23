import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/features/progress_photos/data/repositories/progress_photo_repository.dart';
import 'package:ae_coaching/features/progress_photos/presentation/cubit/progress_photo_cubit.dart';

// Progress Photos feature — completely separate from Workout and
// Measurements. Local-only by design (per the user's explicit choice):
// no remote data source, photos live in the per-user
// `progress_photos_$uid` Hive box + the app's documents directory.
void initProgressPhotos() {
  sl.registerLazySingleton(() => ProgressPhotoRepository(storageManager: sl()));

  sl.registerFactory(() => ProgressPhotoCubit(repository: sl()));
}
