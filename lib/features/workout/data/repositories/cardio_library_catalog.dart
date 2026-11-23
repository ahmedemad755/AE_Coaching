import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_library.dart';
import 'package:flutter/foundation.dart';

/// A cardio activity that can be added to a day: from the curated library
/// (RepDB or app-defined) or one of the user's own cardio exercises.
class CardioLibraryItem {
  const CardioLibraryItem({
    required this.exerciseId,
    required this.nameEn,
    this.nameAr,
    this.category,
    this.searchTerms = const [],
    this.isCustom = false,
  });

  final String exerciseId;
  final String nameEn;
  final String? nameAr;

  /// Null for the user's own cardio ("My cardio").
  final CardioCategory? category;
  final List<String> searchTerms;
  final bool isCustom;

  String nameFor(String languageCode) =>
      languageCode.toLowerCase().startsWith('ar') &&
          (nameAr?.trim().isNotEmpty ?? false)
      ? nameAr!
      : nameEn;

  WorkoutExerciseReferenceType get referenceType => isCustom
      ? WorkoutExerciseReferenceType.custom
      : WorkoutExerciseReferenceType.builtIn;

  /// The selection type the existing day flows (replace) take.
  ExerciseLibraryItem toLibraryItem() => ExerciseLibraryItem(
    id: exerciseId,
    nameEn: nameEn,
    nameAr: nameAr,
    source: isCustom
        ? ExerciseLibraryItemSource.custom
        : ExerciseLibraryItemSource.builtIn,
  );

  /// Every word of [query] is in one of its names (Arabic or English) or
  /// search terms; spelling variants are normalized the same way as the
  /// exercise library.
  bool matches(String query) {
    final tokens = normalizeExerciseName(
      query,
    ).split(' ').where((token) => token.isNotEmpty);
    if (tokens.isEmpty) return true;
    final names = normalizeExerciseName(
      [nameEn, nameAr ?? '', ...searchTerms].join(' '),
    );
    return tokens.every(names.contains);
  }
}

/// Names of the app-defined activities (`cardio:` ids) in both languages.
typedef AppDefinedCardioNames = Map<String, ({String en, String ar})>;

/// The cardio library as the screens show it. Reads the bundled catalog and
/// the user's own exercises; never the network.
class CardioLibraryCatalog {
  const CardioLibraryCatalog({
    required this.catalog,
    required this.customExercises,
    required this.appDefinedNames,
  });

  final ExerciseLibraryCatalog catalog;
  final CustomExerciseRepository customExercises;
  final AppDefinedCardioNames appDefinedNames;

  /// The curated activities in the library's order, then the user's own
  /// cardio. A curated RepDB activity missing from the bundled catalog is
  /// left out (never invented).
  Future<List<CardioLibraryItem>> load() async {
    final builtIns = {for (final item in await catalog.search()) item.id: item};
    final items = <CardioLibraryItem>[];
    for (final entry in CardioLibrary.entries) {
      if (entry.isAppDefined) {
        final names = appDefinedNames[entry.exerciseId];
        if (names == null) continue;
        items.add(
          CardioLibraryItem(
            exerciseId: entry.exerciseId,
            nameEn: names.en,
            nameAr: names.ar,
            category: entry.category,
            searchTerms: entry.searchTerms,
          ),
        );
        continue;
      }
      final item = builtIns[entry.exerciseId];
      if (item == null) continue;
      items.add(
        CardioLibraryItem(
          exerciseId: item.id,
          nameEn: item.nameEn,
          nameAr: item.nameAr,
          category: entry.category,
          searchTerms: entry.searchTerms,
        ),
      );
    }
    items.addAll(await myCardio());
    return List.unmodifiable(items);
  }

  /// The user's own cardio exercises (oldest first).
  Future<List<CardioLibraryItem>> myCardio() async {
    List<CustomExercise> custom;
    try {
      custom = await customExercises.getAllExercises();
    } catch (error) {
      if (kDebugMode) debugPrint('[CardioLibrary] custom unavailable: $error');
      custom = const [];
    }
    return [
      for (final exercise in custom)
        if (exercise.activityType == ActivityType.cardio.name)
          CardioLibraryItem(
            exerciseId: exercise.id,
            nameEn: exercise.name,
            isCustom: true,
          ),
    ];
  }
}
