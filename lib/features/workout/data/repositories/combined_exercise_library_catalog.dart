import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:flutter/foundation.dart';

class CombinedExerciseLibraryCatalog implements ExerciseLibraryCatalog {
  final ExerciseCatalogRepository builtInCatalog;
  final CustomExerciseRepository customExercises;

  const CombinedExerciseLibraryCatalog({
    required this.builtInCatalog,
    required this.customExercises,
  });

  @override
  Future<List<ExerciseLibraryItem>> search({
    String query = '',
    Set<String> muscleGroups = const {},
    Set<String> equipment = const {},
  }) async {
    final builtIns = await builtInCatalog.search(
      query: query,
      muscleGroups: muscleGroups,
      equipment: equipment,
    );
    List<CustomExercise> custom;
    try {
      custom = await customExercises.getAllExercises();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[ExerciseCatalog] Custom exercise storage unavailable; '
          'continuing with built-ins: $error\n$stackTrace',
        );
      }
      custom = const [];
    }
    final normalizedQuery = normalizeExerciseName(query);
    final tokens = normalizedQuery
        .split(' ')
        .where((token) => token.isNotEmpty);
    final selectedMuscles = muscleGroups.map(normalizeExerciseName).toSet();
    final selectedEquipment = equipment.map(normalizeExerciseName).toSet();
    final customMatches = custom.where((exercise) {
      final normalizedName = normalizeExerciseName(exercise.name);
      if (!tokens.every(normalizedName.contains)) return false;
      if (selectedMuscles.isNotEmpty &&
          !selectedMuscles.contains(
            normalizeExerciseName(exercise.muscleGroup ?? ''),
          )) {
        return false;
      }
      if (selectedEquipment.isNotEmpty &&
          !selectedEquipment.contains(
            normalizeExerciseName(exercise.equipment ?? ''),
          )) {
        return false;
      }
      return true;
    });

    final aliases = builtIns.any((e) => e.isRepDb)
        ? await builtInCatalog.loadLegacyMapping()
        : const <String, String>{};
    final results = [
      ...builtIns.map(
        (e) => ExerciseLibraryItem.fromBuiltIn(
          e,
          legacyIds: {
            for (final entry in aliases.entries)
              if (entry.value == e.id) entry.key,
          },
        ),
      ),
      ...customMatches.map(ExerciseLibraryItem.fromCustom),
    ];
    if (kDebugMode) {
      debugPrint(
        '[ExerciseCatalog] Combined search: builtIn=${builtIns.length}, '
        'custom=${customMatches.length}, total=${results.length}',
      );
    }
    return List.unmodifiable(results);
  }
}
