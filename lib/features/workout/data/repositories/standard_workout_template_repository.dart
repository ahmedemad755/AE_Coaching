import 'dart:convert';

import 'package:ae_coaching/features/workout/data/models/standard_workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:flutter/services.dart';

class StandardWorkoutTemplateRepository {
  static const assetPath = 'lib/assets/data/standard_workout_templates.json';
  static const expectedDayCounts = {
    'push_pull_legs': {'ppl_3': 3, 'ppl_6': 6},
    'upper_lower': {'upper_lower_4': 4},
    'full_body': {'full_body_3': 3},
    'bro_split': {'bro_5': 5},
    'arnold': {'arnold_3': 3, 'arnold_6': 6},
    'hybrid': {'hybrid_5': 5},
    'anterior_posterior': {'anterior_posterior_4': 4},
  };
  final ExerciseCatalogRepository catalog;
  final Future<String> Function(String) _loadAsset;
  List<StandardWorkoutSplit>? _cache;

  StandardWorkoutTemplateRepository({
    required this.catalog,
    Future<String> Function(String)? loadAsset,
  }) : _loadAsset = loadAsset ?? rootBundle.loadString;

  Future<List<StandardWorkoutSplit>> loadTemplates() async {
    if (_cache != null) return _cache!;
    final exercises = {for (final e in await catalog.loadCatalog()) e.id: e};
    final data =
        jsonDecode(await _loadAsset(assetPath)) as Map<String, dynamic>;
    if (data['schema_version'] != 1) {
      throw const FormatException('Unsupported template catalog.');
    }
    final splits = <StandardWorkoutSplit>[];
    final splitIds = <String>{};
    for (final raw in data['splits'] as List) {
      final id = raw['id'] as String;
      if (!splitIds.add(id) || !expectedDayCounts.containsKey(id)) {
        throw const FormatException('Unexpected or duplicate split.');
      }
      final variants = <StandardWorkoutVariant>[];
      final variantIds = <String>{};
      for (final v in raw['variants'] as List) {
        final vid = v['id'] as String;
        if (!variantIds.add(vid)) {
          throw const FormatException('Duplicate variant.');
        }
        final days = <StandardWorkoutDay>[];
        final dayIds = <String>{};
        for (final d in v['days'] as List) {
          if (!dayIds.add(d['id'] as String)) {
            throw const FormatException('Duplicate day.');
          }
          final items = <StandardWorkoutExercise>[];
          final assigned = <String>{};
          for (final e in d['exercises'] as List) {
            final exerciseId = e['exercise_id'] as String;
            // First-party templates use the active catalog directly. Legacy
            // resolution is reserved for previously saved user content.
            final ref = exercises[exerciseId];
            if (ref == null || !ref.isRepDb || !assigned.add(ref.id)) {
              throw FormatException(
                'Invalid or duplicate canonical exercise ID: $vid/${d['id']}/$exerciseId',
              );
            }
            final item = StandardWorkoutExercise(
              exercise: ref,
              workingSets: e['working_sets'] as int,
              repsMin: e['reps_min'] as int,
              repsMax: e['reps_max'] as int,
              restSeconds: e['rest_seconds'] as int,
            );
            WorkoutTemplateExerciseAssignment(
              assignmentId: 'validation',
              exerciseId: exerciseId,
              exerciseNameSnapshot: ref.nameEn,
              referenceType: 'builtIn',
              workingSets: item.workingSets,
              targetRepsMin: item.repsMin,
              targetRepsMax: item.repsMax,
              restSeconds: item.restSeconds,
            ).validateTargets();
            items.add(item);
          }
          if (items.isEmpty ||
              (d['name_en'] as String).trim().isEmpty ||
              (d['name_ar'] as String).trim().isEmpty) {
            throw const FormatException('Empty workout day.');
          }
          days.add(
            StandardWorkoutDay(
              id: d['id'] as String,
              nameEn: d['name_en'] as String,
              nameAr: d['name_ar'] as String,
              exercises: items,
            ),
          );
        }
        final week = (v['suggested_week'] as List).cast<int?>();
        final scheduled = week.whereType<int>().toList()..sort();
        if (days.length != expectedDayCounts[id]![vid] ||
            week.length != 7 ||
            scheduled.length != days.length ||
            scheduled.asMap().entries.any(
              (entry) => entry.value != entry.key,
            )) {
          throw const FormatException(
            'Invalid day count or recovery schedule.',
          );
        }
        variants.add(
          StandardWorkoutVariant(id: vid, days: days, suggestedWeek: week),
        );
      }
      if (variantIds.length != expectedDayCounts[id]!.length ||
          !variantIds.containsAll(expectedDayCounts[id]!.keys)) {
        throw const FormatException('Missing template variant.');
      }
      if ((raw['name_en'] as String).trim().isEmpty ||
          (raw['name_ar'] as String).trim().isEmpty) {
        throw const FormatException('Missing translated split name.');
      }
      splits.add(
        StandardWorkoutSplit(
          id: id,
          nameEn: raw['name_en'] as String,
          nameAr: raw['name_ar'] as String,
          variants: variants,
        ),
      );
    }
    if (splitIds.length != expectedDayCounts.length) {
      throw const FormatException('Missing splits.');
    }
    return _cache = List.unmodifiable(splits);
  }
}
