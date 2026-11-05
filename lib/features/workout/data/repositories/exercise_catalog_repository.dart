import 'dart:convert';

import 'package:ae_coaching/features/workout/data/models/exercise_catalog_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ExerciseCatalogRepository {
  static const String assetPath = 'lib/assets/repdb/exercises.json';
  static const String legacyAssetPath =
      'lib/assets/data/exercises_catalog.json';
  static const String arabicAssetPath = 'lib/assets/repdb/ar.json';
  static const String mappingAssetPath = 'lib/assets/repdb/legacy-mapping.json';
  static const String datasetCommit =
      '66c4298af8d99b9dc397dad6699e508fb871d249';
  static const int supportedSchemaVersion = 3;

  final Future<String> Function(String path) _loadAsset;
  Future<List<ExerciseCatalogItem>>? _catalogFuture;
  Future<List<ExerciseCatalogItem>>? _legacyFuture;
  Future<Map<String, String>>? _mappingFuture;

  ExerciseCatalogRepository({Future<String> Function(String path)? loadAsset})
    : _loadAsset = loadAsset ?? rootBundle.loadString;

  Future<List<ExerciseCatalogItem>> loadCatalog() {
    return _catalogFuture ??= _loadWithDiagnostics();
  }

  /// Compatibility data is never appended to active browsing/search.
  Future<List<ExerciseCatalogItem>> loadLegacyCatalog() =>
      _legacyFuture ??= _loadAsset(legacyAssetPath).then((value) {
        final data = jsonDecode(value) as Map<String, dynamic>;
        if (data['schema_version'] != 1) {
          throw const FormatException('Invalid legacy exercise catalog.');
        }
        return List<ExerciseCatalogItem>.unmodifiable(
          (data['exercises'] as List).map(
            (row) => ExerciseCatalogItem.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          ),
        );
      });

  Future<Map<String, String>> loadLegacyMapping() =>
      _mappingFuture ??= _loadAsset(mappingAssetPath).then((value) {
        final data = jsonDecode(value) as Map<String, dynamic>;
        if (data['version'] != 1 || data['dataset_commit'] != datasetCommit) {
          throw const FormatException('Invalid legacy mapping version.');
        }
        final result = <String, String>{};
        for (final row in data['mappings'] as List) {
          if (row['status'] == 'exact') {
            final legacy = row['legacy_id'] as String;
            final canonical = row['canonical_id'] as String;
            if (!canonical.startsWith('repdb:') || result.containsKey(legacy)) {
              throw const FormatException('Invalid/duplicate legacy mapping.');
            }
            result[legacy] = canonical;
          }
        }
        return Map<String, String>.unmodifiable(result);
      });

  Future<ExerciseCatalogItem?> resolveReference(String id) async {
    final active = await loadCatalog();
    for (final item in active) {
      if (item.id == id) return item;
    }
    if (id.startsWith('ex_')) {
      final mapped = (await loadLegacyMapping())[id];
      if (mapped != null) {
        for (final item in active) {
          if (item.id == mapped) return item;
        }
        throw FormatException('Legacy mapping has no canonical exercise: $id');
      }
      for (final item in await loadLegacyCatalog()) {
        if (item.id == id) return item;
      }
    }
    return null;
  }

  Future<List<ExerciseCatalogItem>> _loadWithDiagnostics() async {
    try {
      return await _loadAndValidateCatalog();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[ExerciseCatalog] Load/validation failed: $error\n$stackTrace',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<List<ExerciseCatalogItem>> search({
    String query = '',
    Set<String> muscleGroups = const {},
    Set<String> equipment = const {},
  }) async {
    final catalog = await loadCatalog();
    final normalizedQuery = normalizeExerciseName(query);
    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty);
    final selectedMuscles = muscleGroups.map(normalizeExerciseName).toSet();
    final selectedEquipment = equipment.map(normalizeExerciseName).toSet();

    final matches = catalog
        .where((item) {
          if (selectedMuscles.isNotEmpty &&
              ![item.muscleGroup, ...item.primaryMuscles].any(
                (value) =>
                    selectedMuscles.contains(normalizeExerciseName(value)),
              )) {
            return false;
          }
          if (selectedEquipment.isNotEmpty &&
              !selectedEquipment.contains(
                normalizeExerciseName(item.equipment),
              )) {
            return false;
          }
          if (tokens.isEmpty) return true;

          final englishName = normalizeExerciseName(item.nameEn);
          final arabicName = normalizeExerciseName(item.nameAr);
          return tokens.every(
            (token) =>
                englishName.contains(token) || arabicName.contains(token),
          );
        })
        .toList(growable: false);
    if (kDebugMode) {
      debugPrint(
        '[ExerciseCatalog] Built-in search returned ${matches.length} '
        'of ${catalog.length} entries (query=${query.isEmpty ? "empty" : "set"}, '
        'muscleFilters=${muscleGroups.length}, equipmentFilters=${equipment.length})',
      );
    }
    return List.unmodifiable(matches);
  }

  Future<List<ExerciseCatalogItem>> _loadAndValidateCatalog() async {
    String source;
    try {
      source = await _loadAsset(assetPath);
      if (kDebugMode) {
        debugPrint(
          '[ExerciseCatalog] Asset loaded: $assetPath (${source.length} chars)',
        );
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ExerciseCatalog] Asset load failed: $error\n$stackTrace');
      }
      rethrow;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ExerciseCatalog] JSON decode failed: $error\n$stackTrace');
      }
      rethrow;
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Exercise catalog root must be a JSON object.',
      );
    }
    final rawCount = decoded['exercises'] is List
        ? (decoded['exercises'] as List).length
        : null;
    if (kDebugMode) {
      debugPrint(
        '[ExerciseCatalog] JSON structure: root=object, '
        'keys=${decoded.keys.toList()}, schema=${decoded['schema_version']}, '
        'exercises=$rawCount',
      );
    }
    final legacy = decoded['schema_version'] == 1;
    if (decoded['schema_version'] != supportedSchemaVersion && !legacy) {
      throw FormatException(
        'Unsupported exercise catalog schema version: ${decoded['schema_version']}.',
      );
    }

    final rawExercises = decoded['exercises'];
    if (rawExercises is! List<dynamic>) {
      throw const FormatException(
        'Exercise catalog "exercises" must be an array.',
      );
    }

    final ids = <String>{};
    final exercises = <ExerciseCatalogItem>[];
    var arabic = <String, dynamic>{};
    if (!legacy) {
      final overlay = jsonDecode(await _loadAsset(arabicAssetPath));
      if (overlay is! Map<String, dynamic> ||
          overlay['schema_version'] != 1 ||
          overlay['dataset_commit'] != datasetCommit ||
          overlay['exercises'] is! Map<String, dynamic>) {
        throw const FormatException(
          'Arabic overlay does not match the RepDB version.',
        );
      }
      arabic = overlay['exercises'] as Map<String, dynamic>;
      if (arabic.length != rawExercises.length) {
        throw const FormatException(
          'Arabic overlay coverage differs from the catalog.',
        );
      }
    }
    for (var index = 0; index < rawExercises.length; index++) {
      final raw = rawExercises[index];
      if (raw is! Map<String, dynamic>) {
        throw FormatException(
          'Exercise catalog entry $index must be an object.',
        );
      }
      late final ExerciseCatalogItem exercise;
      try {
        exercise = legacy
            ? ExerciseCatalogItem.fromJson(raw)
            : ExerciseCatalogItem.fromRepDb(
                raw,
                datasetVersion: datasetCommit,
                arabic: arabic['repdb:${raw['id']}'] as Map<String, dynamic>?,
              );
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            '[ExerciseCatalog] Entry parse failed at index $index: '
            '$error\n$stackTrace',
          );
        }
        rethrow;
      }
      if (!ids.add(exercise.id)) {
        throw FormatException(
          'Duplicate exercise catalog id "${exercise.id}".',
        );
      }
      if (!legacy &&
          (!arabic.containsKey(exercise.id) ||
              exercise.nameAr.trim().isEmpty)) {
        throw FormatException('Missing Arabic name for ${exercise.id}.');
      }
      if (exercise.instructionsAr.isNotEmpty &&
          exercise.instructionsAr.length != exercise.instructionsEn.length) {
        throw FormatException(
          'Partial Arabic instructions for ${exercise.id}.',
        );
      }
      exercises.add(exercise);
    }

    if (!legacy && decoded['count'] != exercises.length) {
      throw const FormatException('RepDB exercise count differs from source.');
    }

    if (kDebugMode) {
      debugPrint(
        '[ExerciseCatalog] Successfully parsed ${exercises.length} entries',
      );
    }
    return List.unmodifiable(exercises);
  }
}
