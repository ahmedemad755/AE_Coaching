import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:hive_flutter/hive_flutter.dart';

abstract class WorkoutRepository {
  Future<void> saveAndSyncWorkout(
    Box<ExerciseSet> box,
    String key,
    ExerciseSet set,
  );

  Future<void> deleteAndSyncWorkout(ExerciseSet set);

  Future<void> deleteMultipleAndSync(
    Box<ExerciseSet> box,
    List<String> keys,
  );

  Future<void> fetchAndSyncFromRemote(Box<ExerciseSet> box); // جلب البيانات السحابية وحفظها محلياً
}