import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_catalog_item.dart';

enum ExerciseLibraryItemSource { builtIn, custom }

class ExerciseLibraryItem {
  final String id;
  final String nameEn;
  final String? nameAr;
  final String? muscleGroup;
  final String? equipment;
  final ExerciseLibraryItemSource source;
  final ExerciseCatalogItem? catalogExercise;
  final Set<String> legacyIds;

  const ExerciseLibraryItem({
    required this.id,
    required this.nameEn,
    this.nameAr,
    this.muscleGroup,
    this.equipment,
    required this.source,
    this.catalogExercise,
    this.legacyIds = const {},
  });

  factory ExerciseLibraryItem.fromBuiltIn(
    ExerciseCatalogItem exercise, {
    Set<String> legacyIds = const {},
  }) {
    return ExerciseLibraryItem(
      id: exercise.id,
      nameEn: exercise.nameEn,
      nameAr: exercise.nameAr,
      muscleGroup: exercise.muscleGroup,
      equipment: exercise.equipment,
      source: ExerciseLibraryItemSource.builtIn,
      catalogExercise: exercise,
      legacyIds: Set<String>.unmodifiable(legacyIds),
    );
  }

  factory ExerciseLibraryItem.fromCustom(CustomExercise exercise) {
    return ExerciseLibraryItem(
      id: exercise.id,
      nameEn: exercise.name,
      muscleGroup: exercise.muscleGroup,
      equipment: exercise.equipment,
      source: ExerciseLibraryItemSource.custom,
    );
  }

  String nameForLanguage(String languageCode) =>
      languageCode.toLowerCase().startsWith('ar') && nameAr?.isNotEmpty == true
      ? nameAr!
      : nameEn;
}
