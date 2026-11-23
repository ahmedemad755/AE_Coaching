import 'dart:async';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/sync/revision_sync_engine.dart';
import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/data/sync/workout_sync_adapters.dart';
import 'package:ae_coaching/features/workout/data/workout_id_generator.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class DuplicateCustomExerciseException implements Exception {
  final String name;

  const DuplicateCustomExerciseException(this.name);

  @override
  String toString() => 'A custom exercise with this name already exists.';
}

/// Custom exercises: local Hive box (what the app reads) and, when a
/// [remoteDataSource] is given, the revision-protected cloud copy
/// `users/{uid}/custom_exercises/{id}` (document id = local id, so syncing
/// again or from another device can never duplicate an exercise).
class CustomExerciseRepository {
  final UserBox<CustomExercise> _userBox;
  final UserBox<Map> _conflictsBox;
  final UserBox<Map> _tombstonesBox;
  final UserBox<Map> _stateBox;
  final CustomExerciseRemoteDataSource? remoteDataSource;
  final String Function() _newWriteId;
  final Map<String, RevisionSyncEngine<CustomExercise>> _engines = {};

  @visibleForTesting
  final String? Function()? uidOverride;

  Future<void> _createQueue = Future<void>.value();

  CustomExerciseRepository({
    required UserStorageManager storageManager,
    this.remoteDataSource,
    String Function()? newWriteId,
    @visibleForTesting this.uidOverride,
  }) : _newWriteId = newWriteId ?? (() => WorkoutIdGenerator.generate('w')),
       _userBox = UserBox<CustomExercise>(
         manager: storageManager,
         prefix: 'custom_exercises',
         uidOverride: uidOverride,
       ),
       _conflictsBox = UserBox<Map>(
         manager: storageManager,
         prefix: 'sync_conflicts',
         uidOverride: uidOverride,
       ),
       _tombstonesBox = UserBox<Map>(
         manager: storageManager,
         prefix: 'sync_tombstones',
         uidOverride: uidOverride,
       ),
       _stateBox = UserBox<Map>(
         manager: storageManager,
         prefix: 'sync_state',
         uidOverride: uidOverride,
       );

  Future<Box<CustomExercise>> getUserBox() => _userBox.getUserBox();

  /// Null when this repository has no cloud copy (e.g. in unit tests).
  Future<RevisionSyncEngine<CustomExercise>?> syncEngine() async {
    final remote = remoteDataSource;
    if (remote == null) return null;
    final records = await getUserBox();
    final engine = _engines[records.name];
    if (engine != null && records.isOpen) return engine;
    final created = RevisionSyncEngine<CustomExercise>(
      records: records,
      conflicts: await _conflictsBox.getUserBox(),
      tombstones: await _tombstonesBox.getUserBox(),
      state: await _stateBox.getUserBox(),
      cloud: remote,
      adapter: CustomExerciseSyncAdapter(),
      newWriteId: _newWriteId,
    );
    _engines[records.name] = created;
    return created;
  }

  /// Pulls exercises created or changed on other devices (only what changed
  /// since the last pull, see [RevisionSyncEngine]) and pushes local ones.
  /// Offline is reported, not thrown.
  Future<SyncReport> syncWithCloud() async =>
      await (await syncEngine())?.syncAll() ?? SyncReport();

  /// Background push: never opens storage (see WorkoutTemplateRepository).
  void _requestSync() {
    RevisionSyncEngine<CustomExercise>? engine;
    for (final candidate in _engines.values.toList().reversed) {
      if (candidate.records.isOpen &&
          candidate.conflicts.isOpen &&
          candidate.tombstones.isOpen) {
        engine = candidate;
        break;
      }
    }
    if (engine == null) return;
    unawaited(
      engine.requestPush().catchError((Object error) {
        if (kDebugMode) debugPrint('[CustomExerciseRepository] $error');
        return SyncReport();
      }),
    );
  }

  /// Creates one of the user's own exercises. [activityType] is strength
  /// unless given (Stage 3: cardio from the cardio library).
  Future<CustomExercise> createExercise({
    required String name,
    String? muscleGroup,
    String? equipment,
    ActivityType activityType = ActivityType.strength,
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
          activityType: activityType,
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
    required ActivityType activityType,
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
      // Null keeps strength exercises exactly as they always were stored.
      activityType: activityType == ActivityType.strength
          ? null
          : activityType.name,
      // A new id: there is no cloud copy to match it with, it is created.
    ).withSyncMeta(SyncMeta.empty.migratedAsNew());
    await box.put(exercise.id, exercise);
    _requestSync();
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
