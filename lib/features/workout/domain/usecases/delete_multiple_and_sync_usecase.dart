import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/domain/repositories/workout_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DeleteMultipleAndSyncParams {
  final Box<ExerciseSet> box;
  final List<String> keys;

  const DeleteMultipleAndSyncParams({
    required this.box,
    required this.keys,
  });
}

class DeleteMultipleAndSyncUseCase {
  final WorkoutRepository repository;

  const DeleteMultipleAndSyncUseCase(this.repository);

  Future<void> call(DeleteMultipleAndSyncParams params) async {
    await repository.deleteMultipleAndSync(
      params.box,
      params.keys,
    );
  }
}