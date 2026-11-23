import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:flutter/foundation.dart';

/// Finds the library exercise behind a program/workout exercise, by its
/// stored id and reference type only (never by name), so its image and
/// details can be shown wherever the program is.
///
/// - `builtIn`: the bundled catalog, including older `ex_` ids (mapped to
///   their RepDB exercise, or the legacy catalog).
/// - `custom`: the signed-in account's custom exercises (no image).
/// - anything else (e.g. `manual`), or an id that no longer exists: null.
///
/// Built-in lookups are cached for the app's lifetime (bundled data never
/// changes). Custom lookups are not: they belong to the current account.
/// Never throws: a broken reference simply has no picture.
class ExerciseReferenceResolver {
  ExerciseReferenceResolver({
    required ExerciseCatalogRepository catalog,
    required CustomExerciseRepository customExercises,
  }) : _catalog = catalog,
       _customExercises = customExercises;

  final ExerciseCatalogRepository _catalog;
  final CustomExerciseRepository _customExercises;
  final Map<String, Future<ExerciseLibraryItem?>> _builtIn = {};

  Future<ExerciseLibraryItem?> resolveAssignment(
    WorkoutTemplateExerciseAssignment assignment,
  ) => resolve(
    exerciseId: assignment.exerciseId,
    referenceType: assignment.referenceType,
  );

  Future<ExerciseLibraryItem?> resolve({
    required String exerciseId,
    required String referenceType,
  }) {
    if (exerciseId.isEmpty) return Future.value();
    switch (referenceType) {
      case 'builtIn':
        return _builtIn.putIfAbsent(
          exerciseId,
          () => _resolveBuiltIn(exerciseId),
        );
      case 'custom':
        return _resolveCustom(exerciseId);
      default:
        return Future.value();
    }
  }

  Future<ExerciseLibraryItem?> _resolveBuiltIn(String id) async {
    try {
      final item = await _catalog.resolveReference(id);
      if (item == null) return null;
      return ExerciseLibraryItem.fromBuiltIn(
        item,
        legacyIds: item.id == id ? const {} : {id},
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ExerciseReference] $id unresolved: $error');
      }
      return null;
    }
  }

  Future<ExerciseLibraryItem?> _resolveCustom(String id) async {
    try {
      final exercise = await _customExercises.getById(id);
      return exercise == null ? null : ExerciseLibraryItem.fromCustom(exercise);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[ExerciseReference] custom $id unresolved: $error');
      }
      return null;
    }
  }
}
