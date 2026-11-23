import 'package:ae_coaching/features/workout/data/models/exercise_catalog_item.dart';

class StandardWorkoutExercise {
  final ExerciseCatalogItem exercise;
  final int workingSets;
  final int repsMin;
  final int repsMax;
  final int restSeconds;

  const StandardWorkoutExercise({
    required this.exercise,
    required this.workingSets,
    required this.repsMin,
    required this.repsMax,
    required this.restSeconds,
  });
}

class StandardWorkoutDay {
  final String id;
  final String nameEn;
  final String nameAr;
  final List<StandardWorkoutExercise> exercises;
  StandardWorkoutDay({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required List<StandardWorkoutExercise> exercises,
  }) : exercises = List.unmodifiable(exercises);
  String nameForLanguage(String code) =>
      code.startsWith('ar') ? nameAr : nameEn;
}

class StandardWorkoutVariant {
  final String id;
  final List<StandardWorkoutDay> days;

  /// Seven consecutive suggested days; null denotes rest. No calendar is persisted.
  final List<int?> suggestedWeek;
  StandardWorkoutVariant({
    required this.id,
    required List<StandardWorkoutDay> days,
    required List<int?> suggestedWeek,
  }) : days = List.unmodifiable(days),
       suggestedWeek = List.unmodifiable(suggestedWeek);
}

class StandardWorkoutSplit {
  final String id;
  final String nameEn;
  final String nameAr;
  final List<StandardWorkoutVariant> variants;
  StandardWorkoutSplit({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required List<StandardWorkoutVariant> variants,
  }) : variants = List.unmodifiable(variants);
  String nameForLanguage(String code) =>
      code.startsWith('ar') ? nameAr : nameEn;
}
