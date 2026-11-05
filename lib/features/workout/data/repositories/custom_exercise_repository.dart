import 'dart:async';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/data/workout_id_generator.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DuplicateCustomExerciseException implements Exception {
  final String name;

  const DuplicateCustomExerciseException(this.name);

  @override
  String toString() => 'A custom exercise with this name already exists.';
}

class CustomExerciseRepository {
  final UserBox<CustomExercise> _userBox;

  @visibleForTesting
  final String? Function()? uidOverride;

  Future<void> _createQueue = Future<void>.value();

  CustomExerciseRepository({
    required UserStorageManager storageManager,
    @visibleForTesting this.uidOverride,
  }) : _userBox = UserBox<CustomExercise>(
         manager: storageManager,
         prefix: 'custom_exercises',
         uidOverride: uidOverride,
       );

  Future<Box<CustomExercise>> getUserBox() => _userBox.getUserBox();

  Future<CustomExercise> createExercise({
    required String name,
    String? muscleGroup,
    String? equipment,
  }) {
    final completer = Completer<void>();
    final previous = _createQueue;
    _createQueue = completer.future;
    return previous.then((_) async {
      try {
        return await _createExercise(
          name: name,
          muscleGroup: muscleGroup,
          equipment: equipment,
        );
      } finally {
        completer.complete();
      }
    });
  }

  Future<CustomExercise> _createExercise({
    required String name,
    String? muscleGroup,
    String? equipment,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Name must not be empty.');
    }

    final box = await getUserBox();
    final normalizedName = normalizeExerciseName(name);
    final duplicate = box.values.any(
      (exercise) => normalizeExerciseName(exercise.name) == normalizedName,
    );
    if (duplicate) throw DuplicateCustomExerciseException(name);

    final exercise = CustomExercise(
      id: WorkoutIdGenerator.generate('custom_exercise'),
      name: name,
      muscleGroup: _optionalValue(muscleGroup),
      equipment: _optionalValue(equipment),
      createdAt: DateTime.now(),
    );
    await box.put(exercise.id, exercise);
    return exercise;
  }

  Future<List<CustomExercise>> getAllExercises() async {
    final box = await getUserBox();
    final exercises = box.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(exercises);
  }

  Future<CustomExercise?> getById(String id) async {
    final box = await getUserBox();
    return box.get(id);
  }

  Future<List<CustomExercise>> search(String query) async {
    final normalizedQuery = normalizeExerciseName(query);
    final tokens = normalizedQuery
        .split(' ')
        .where((token) => token.isNotEmpty);
    final exercises = await getAllExercises();
    return List.unmodifiable(
      exercises.where((exercise) {
        final normalizedName = normalizeExerciseName(exercise.name);
        return tokens.every(normalizedName.contains);
      }),
    );
  }

  String? _optionalValue(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
