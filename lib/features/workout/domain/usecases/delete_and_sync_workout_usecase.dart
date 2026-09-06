import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/domain/repositories/workout_repository.dart';

class DeleteAndSyncWorkoutParams {
  final ExerciseSet set;

  const DeleteAndSyncWorkoutParams({required this.set});
}

class DeleteAndSyncWorkoutUseCase {
  final WorkoutRepository repository;

  const DeleteAndSyncWorkoutUseCase(this.repository);

  Future<void> call(DeleteAndSyncWorkoutParams params) async {
    await repository.deleteAndSyncWorkout(params.set);
  }
}