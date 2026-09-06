import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/domain/repositories/workout_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SaveAndSyncWorkoutParams {
  final Box<ExerciseSet> box;
  final String key;
  final ExerciseSet set;

  const SaveAndSyncWorkoutParams({
    required this.box,
    required this.key,
    required this.set,
  });
}

class SaveAndSyncWorkoutUseCase {
  final WorkoutRepository repository;

  const SaveAndSyncWorkoutUseCase(this.repository);

  Future<void> call(SaveAndSyncWorkoutParams params) async {
    await repository.saveAndSyncWorkout(
      params.box,
      params.key,
      params.set,
    );
  }
}