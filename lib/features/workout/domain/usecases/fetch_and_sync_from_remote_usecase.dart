import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/domain/repositories/workout_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FetchAndSyncFromRemoteParams {
  final Box<ExerciseSet> box;

  const FetchAndSyncFromRemoteParams({required this.box});
}

class FetchAndSyncFromRemoteUseCase {
  final WorkoutRepository repository;

  const FetchAndSyncFromRemoteUseCase(this.repository);

  Future<void> call(FetchAndSyncFromRemoteParams params) async {
    await repository.fetchAndSyncFromRemote(params.box);
  }
}