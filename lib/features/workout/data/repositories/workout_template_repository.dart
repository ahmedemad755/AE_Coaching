import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/data/workout_id_generator.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Data layer for [WorkoutTemplate] — Hive (offline-first) + Firestore
/// sync, same shape as `WorkoutProgramRepository`.
///
/// Storage:
/// - Local: `workout_templates_$uid` Hive box, keyed by the template's
///   own `id`.
/// - Cloud: `users/{uid}/workout_templates/{id}` (every document
///   includes `programId`).
///
/// Does not touch `sets_$uid`, `measurements_$uid`,
/// `progress_photos_$uid`, or `workout_programs_$uid` — entirely
/// separate box. No WorkoutSession logic here yet (Phase 3).
class WorkoutTemplateRepository {
  final WorkoutTemplateRemoteDataSource remoteDataSource;
  final UserBox<WorkoutTemplate> _userBox;
  Future<void>? _mutationTail;

  /// @visibleForTesting seam — see WorkoutProgramRepository for why
  /// this exists (no real Firebase app in a unit-test environment).
  @visibleForTesting
  final String? Function()? uidOverride;

  WorkoutTemplateRepository({
    WorkoutTemplateRemoteDataSource? remoteDataSource,
    required UserStorageManager storageManager,
    @visibleForTesting this.uidOverride,
  }) : remoteDataSource =
           remoteDataSource ?? WorkoutTemplateRemoteDataSourceImpl(),
       _userBox = UserBox<WorkoutTemplate>(
         manager: storageManager,
         prefix: 'workout_templates',
         uidOverride: uidOverride,
       );

  Future<Box<WorkoutTemplate>> getUserBox() => _userBox.getUserBox();

  /// Coordinates local-only exercise changes with the active session queue.
  Future<T> coordinateExerciseEdit<T>(Future<T> Function() write) =>
      _serializeMutation(write);

  Future<T> _serializeMutation<T>(Future<T> Function() mutation) {
    final result =
        _mutationTail?.then((_) => mutation()) ?? Future<T>.sync(mutation);
    _mutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<WorkoutTemplate> addExerciseAssignment({
    required String templateId,
    required String exerciseId,
    required String exerciseNameSnapshot,
    required WorkoutExerciseReferenceType referenceType,
  }) {
    return _serializeMutation(() async {
      final name = exerciseNameSnapshot.trim();
      if (exerciseId.trim().isEmpty || name.isEmpty) {
        throw ArgumentError('Exercise reference and name are required.');
      }
      final box = await getUserBox();
      final template = box.get(templateId);
      if (template == null) throw Exception('Workout template not found.');

      final normalizedName = normalizeExerciseName(name);
      final duplicate = template.exerciseAssignments.any(
        (assignment) =>
            assignment.exerciseId == exerciseId ||
            normalizeExerciseName(assignment.exerciseNameSnapshot) ==
                normalizedName,
      );
      if (duplicate) throw DuplicateTemplateExerciseException(name);

      final updated = template.copyWith(
        exerciseAssignments: [
          ...template.exerciseAssignments,
          WorkoutTemplateExerciseAssignment(
            assignmentId: WorkoutIdGenerator.generate('assignment'),
            exerciseId: exerciseId,
            exerciseNameSnapshot: name,
            referenceType: referenceType.name,
          ),
        ],
        updatedAt: DateTime.now(),
      );
      await box.put(templateId, updated);
      return updated;
    });
  }

  Future<WorkoutTemplate> addExerciseAssignments({
    required String templateId,
    required List<ExerciseLibraryItem> exercises,
    required String languageCode,
  }) {
    return _serializeMutation(() async {
      if (kDebugMode) {
        debugPrint(
          '[WorkoutTemplateRepository] Add assignments: template=$templateId, '
          'requested=${exercises.length}',
        );
      }
      final box = await getUserBox();
      final template = box.get(templateId);
      if (template == null) {
        if (kDebugMode) {
          debugPrint(
            '[WorkoutTemplateRepository] Missing template: $templateId',
          );
        }
        throw Exception('Workout template not found.');
      }
      if (exercises.isEmpty) return template;

      final assignments = List<WorkoutTemplateExerciseAssignment>.of(
        template.exerciseAssignments,
      );
      final ids = assignments.map((item) => item.exerciseId).toSet();
      final names = assignments
          .map((item) => normalizeExerciseName(item.exerciseNameSnapshot))
          .toSet();
      final seenBatchIds = <String>{};
      final seenBatchNames = <String>{};
      final added = <WorkoutTemplateExerciseAssignment>[];
      for (final exercise in exercises) {
        final name = exercise.nameForLanguage(languageCode).trim();
        final normalizedName = normalizeExerciseName(name);
        if (name.isEmpty ||
            ids.contains(exercise.id) ||
            names.contains(normalizedName) ||
            !seenBatchIds.add(exercise.id) ||
            !seenBatchNames.add(normalizedName)) {
          throw DuplicateTemplateExerciseException(name);
        }
        added.add(
          WorkoutTemplateExerciseAssignment(
            assignmentId: WorkoutIdGenerator.generate('assignment'),
            exerciseId: exercise.id,
            exerciseNameSnapshot: name,
            referenceType: exercise.source == ExerciseLibraryItemSource.builtIn
                ? WorkoutExerciseReferenceType.builtIn.name
                : WorkoutExerciseReferenceType.custom.name,
          ),
        );
      }

      final updated = template.copyWith(
        exerciseAssignments: [...assignments, ...added],
        updatedAt: DateTime.now(),
      );
      await box.put(templateId, updated);
      if (kDebugMode) {
        debugPrint(
          '[WorkoutTemplateRepository] Saved template=$templateId, '
          'assignments=${updated.exerciseAssignments.length}',
        );
      }
      return updated;
    });
  }

  Future<WorkoutTemplate> removeExerciseAssignment({
    required String templateId,
    required String assignmentId,
  }) {
    return _serializeMutation(() async {
      final box = await getUserBox();
      final template = box.get(templateId);
      if (template == null) throw Exception('Workout template not found.');
      final assignments = template.exerciseAssignments
          .where((assignment) => assignment.assignmentId != assignmentId)
          .toList();
      if (assignments.length == template.exerciseAssignments.length) {
        return template;
      }
      final updated = template.copyWith(
        exerciseAssignments: assignments,
        updatedAt: DateTime.now(),
      );
      await box.put(templateId, updated);
      return updated;
    });
  }

  Future<WorkoutTemplate> replaceExerciseAssignment({
    required String templateId,
    required String assignmentId,
    required ExerciseLibraryItem exercise,
    required String languageCode,
  }) {
    return _serializeMutation(() async {
      final box = await getUserBox();
      final template = box.get(templateId);
      if (template == null) throw Exception('Workout template not found.');
      final index = template.exerciseAssignments.indexWhere(
        (assignment) => assignment.assignmentId == assignmentId,
      );
      if (index < 0) throw Exception('Workout assignment not found.');

      final name = exercise.nameForLanguage(languageCode).trim();
      final normalizedName = normalizeExerciseName(name);
      final duplicate = template.exerciseAssignments.asMap().entries.any(
        (entry) =>
            entry.key != index &&
            (entry.value.exerciseId == exercise.id ||
                normalizeExerciseName(entry.value.exerciseNameSnapshot) ==
                    normalizedName),
      );
      if (name.isEmpty) throw ArgumentError('Exercise name is required.');
      if (duplicate) throw DuplicateTemplateExerciseException(name);

      final assignments = List<WorkoutTemplateExerciseAssignment>.of(
        template.exerciseAssignments,
      );
      final current = assignments[index];
      assignments[index] = current.copyWith(
        exerciseId: exercise.id,
        exerciseNameSnapshot: name,
        referenceType: exercise.source == ExerciseLibraryItemSource.builtIn
            ? WorkoutExerciseReferenceType.builtIn.name
            : WorkoutExerciseReferenceType.custom.name,
      );
      final updated = template.copyWith(
        exerciseAssignments: assignments,
        updatedAt: DateTime.now(),
      );
      await box.put(templateId, updated);
      return updated;
    });
  }

  Future<WorkoutTemplate> reorderExerciseAssignments({
    required String templateId,
    required List<String> orderedAssignmentIds,
  }) {
    return _serializeMutation(() async {
      final box = await getUserBox();
      final template = box.get(templateId);
      if (template == null) throw Exception('Workout template not found.');
      final currentById = {
        for (final assignment in template.exerciseAssignments)
          assignment.assignmentId: assignment,
      };
      if (orderedAssignmentIds.length != currentById.length ||
          orderedAssignmentIds.toSet().length != orderedAssignmentIds.length ||
          !orderedAssignmentIds.toSet().containsAll(currentById.keys)) {
        throw ArgumentError('Order must contain each assignment exactly once.');
      }
      final updated = template.copyWith(
        exerciseAssignments: orderedAssignmentIds
            .map((id) => currentById[id]!)
            .toList(),
        updatedAt: DateTime.now(),
      );
      await box.put(templateId, updated);
      return updated;
    });
  }

  Future<WorkoutTemplate> updateExerciseTargets({
    required String templateId,
    required String assignmentId,
    required int workingSets,
    required int targetRepsMin,
    required int targetRepsMax,
    required int restSeconds,
  }) => _serializeMutation(() async {
    final box = await getUserBox();
    final template = box.get(templateId);
    if (template == null) throw StateError('Workout template not found.');
    final assignments = List<WorkoutTemplateExerciseAssignment>.of(
      template.exerciseAssignments,
    );
    final index = assignments.indexWhere(
      (item) => item.assignmentId == assignmentId,
    );
    if (index < 0) throw StateError('Workout assignment not found.');
    final updatedAssignment = assignments[index].copyWith(
      workingSets: workingSets,
      targetRepsMin: targetRepsMin,
      targetRepsMax: targetRepsMax,
      restSeconds: restSeconds,
    );
    updatedAssignment.validateTargets();
    assignments[index] = updatedAssignment;
    final updated = template.copyWith(
      exerciseAssignments: assignments,
      updatedAt: DateTime.now(),
    );
    await box.put(templateId, updated);
    return updated;
  });

  /// Creates a new workout day template under [programId]. This is the
  /// only place a template's programId is ever set — there is no way
  /// to change it afterward.
  Future<WorkoutTemplate> createTemplate({
    required String programId,
    required String name,
    int? orderIndex,
  }) async {
    final box = await getUserBox();
    final id = WorkoutIdGenerator.generate('template');
    final template = WorkoutTemplate(
      id: id,
      programId: programId,
      name: name,
      createdAt: DateTime.now(),
      orderIndex: orderIndex,
    );

    await box.put(id, template);
    await _syncSafely(id, template);
    return template;
  }

  /// Updates a template's editable fields only. There is deliberately
  /// no `programId` parameter here — it is structurally impossible to
  /// move a template between programs through this method. The
  /// updated record always keeps the original's `programId` and `id`
  /// (enforced by `WorkoutTemplate.copyWith`, not just convention).
  Future<WorkoutTemplate> updateTemplate({
    required String templateId,
    String? name,
    int? orderIndex,
  }) async {
    final box = await getUserBox();
    final existing = box.get(templateId);
    if (existing == null) {
      throw Exception('Workout template not found.');
    }

    final updated = existing.copyWith(
      name: name,
      orderIndex: orderIndex,
      updatedAt: DateTime.now(),
    );
    await box.put(templateId, updated);
    await _syncSafely(templateId, updated);
    return updated;
  }

  /// Templates belonging to [programId], newest-ordered first by
  /// [orderIndex] (nulls last) then by creation date. Archived
  /// templates are excluded unless [includeArchived] is true — archive
  /// removes a template from the normal active list without deleting
  /// its record or history.
  List<WorkoutTemplate> getTemplatesForProgram(
    Box<WorkoutTemplate> box,
    String programId, {
    bool includeArchived = false,
  }) {
    final matches = box.values
        .where(
          (t) => t.programId == programId && (includeArchived || !t.isArchived),
        )
        .toList();

    matches.sort((a, b) {
      if (a.orderIndex != null && b.orderIndex != null) {
        return a.orderIndex!.compareTo(b.orderIndex!);
      }
      if (a.orderIndex != null) return -1;
      if (b.orderIndex != null) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return matches;
  }

  WorkoutTemplate? getTemplateById(
    Box<WorkoutTemplate> box,
    String templateId,
  ) {
    return box.get(templateId);
  }

  /// Marks a template archived and stamps `updatedAt`. Never deletes
  /// it — the record and any historical sessions stay intact. This is
  /// the normal, non-destructive way to "remove" a template from the
  /// active list; see [deleteTemplate] for actual (cascade) deletion.
  Future<void> archiveTemplate(String templateId) async {
    final box = await getUserBox();
    final target = box.get(templateId);
    if (target == null) return;

    final archived = target.copyWith(
      isArchived: true,
      updatedAt: DateTime.now(),
    );
    await box.put(templateId, archived);
    await _syncSafely(templateId, archived);
  }

  /// Reverses [archiveTemplate] — brings a workout day back into the
  /// normal active list. The record and any historical sessions were
  /// never touched while archived, so nothing needs repairing.
  Future<void> restoreTemplate(String templateId) async {
    final box = await getUserBox();
    final target = box.get(templateId);
    if (target == null) return;

    final restored = target.copyWith(
      isArchived: false,
      updatedAt: DateTime.now(),
    );
    await box.put(templateId, restored);
    await _syncSafely(templateId, restored);
  }

  /// Deletes ONLY this template's own record (local + remote) — never
  /// its sessions/sets. [archiveTemplate] remains the normal,
  /// non-destructive "I don't do this day anymore" action; use this
  /// only as part of a full cascade delete (see
  /// `WorkoutCascadeDeletionService.deleteTemplateCascade`, which
  /// deletes every session/set under this template FIRST, then calls
  /// this). Calling this directly on a template that still has
  /// sessions would orphan them — always go through the cascade
  /// service from the UI layer.
  Future<void> deleteTemplate(String templateId) async {
    final box = await getUserBox();
    await box.delete(templateId);

    try {
      await remoteDataSource.deleteTemplate(templateId);
    } catch (error, stackTrace) {
      debugPrint('WorkoutTemplate remote delete failed: $error\n$stackTrace');
      rethrow;
    }
  }

  /// Pulls every template stored in the cloud into the local box, then
  /// pushes up any local-only template the cloud doesn't know about
  /// yet — same merge pattern as Workout/Measurement/Program sync.
  Future<void> fetchAndSyncFromRemote(Box<WorkoutTemplate> box) async {
    try {
      final remoteDocs = await remoteDataSource.fetchAllRemoteTemplates();
      final remoteIds = remoteDocs.map((doc) => doc.id).toSet();

      for (final doc in remoteDocs) {
        final data = doc.data();
        var template = WorkoutTemplate.fromJson(data);
        final localTemplate = box.get(doc.id);
        // Exercise assignments are local-only. Older remote documents may
        // still contain a stale list, so an existing local template remains
        // authoritative even when its assignment list is intentionally empty.
        if (localTemplate != null) {
          template = template.copyWith(
            exerciseAssignments: localTemplate.exerciseAssignments,
          );
        }
        await box.put(doc.id, template);
      }

      for (final localId in box.keys) {
        final localTemplate = box.get(localId);
        if (localTemplate == null || remoteIds.contains(localId)) {
          continue;
        }
        await remoteDataSource.syncTemplate(localId as String, localTemplate);
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to fetch and sync workout templates from cloud: $error\n$stackTrace',
      );
      rethrow;
    }
  }

  Future<void> _syncSafely(String id, WorkoutTemplate template) async {
    try {
      await remoteDataSource.syncTemplate(id, template);
    } catch (error, stackTrace) {
      debugPrint('WorkoutTemplate remote sync failed: $error\n$stackTrace');
      rethrow;
    }
  }
}

class DuplicateTemplateExerciseException implements Exception {
  final String exerciseName;

  const DuplicateTemplateExerciseException(this.exerciseName);

  @override
  String toString() => 'This exercise is already assigned to the workout day.';
}
