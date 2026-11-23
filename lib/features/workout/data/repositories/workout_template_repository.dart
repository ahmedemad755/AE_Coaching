import 'dart:async';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/sync/canonical_hash.dart';
import 'package:ae_coaching/core/sync/revision_sync_engine.dart';
import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/data/sync/workout_sync_adapters.dart';
import 'package:ae_coaching/features/workout/data/workout_id_generator.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/workout_limits.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Data layer for [WorkoutTemplate] (workout days and their activities).
///
/// Storage:
/// - Local (the source the UI reads): `workout_templates_$uid` Hive box,
///   keyed by the template's own `id`.
/// - Cloud: `users/{uid}/workout_templates/{id}`, schema 2, activities
///   included, revision-protected. Every write goes through the sync engine
///   ([RevisionSyncEngine]): changes are saved locally first and sent in the
///   background (never awaited by the UI); deletions are revision-checked
///   tombstones; conflicts and old-format data wait for the user.
///
/// Does not touch `sets_$uid`, `measurements_$uid`,
/// `progress_photos_$uid`, or `workout_programs_$uid` — entirely
/// separate box. No WorkoutSession logic here yet (Phase 3).
class WorkoutTemplateRepository {
  final WorkoutTemplateRemoteDataSource remoteDataSource;
  final UserBox<WorkoutTemplate> _userBox;
  final UserBox<Map> _conflictsBox;
  final UserBox<Map> _tombstonesBox;
  final UserBox<Map> _stateBox;
  final String Function() _newWriteId;
  Future<void>? _mutationTail;
  final Map<String, RevisionSyncEngine<WorkoutTemplate>> _engines = {};

  /// @visibleForTesting seam — see WorkoutProgramRepository for why
  /// this exists (no real Firebase app in a unit-test environment).
  @visibleForTesting
  final String? Function()? uidOverride;

  WorkoutTemplateRepository({
    WorkoutTemplateRemoteDataSource? remoteDataSource,
    required UserStorageManager storageManager,
    String Function()? newWriteId,
    @visibleForTesting this.uidOverride,
  }) : remoteDataSource =
           remoteDataSource ?? WorkoutTemplateRemoteDataSourceImpl(),
       _newWriteId = newWriteId ?? (() => WorkoutIdGenerator.generate('w')),
       _userBox = UserBox<WorkoutTemplate>(
         manager: storageManager,
         prefix: 'workout_templates',
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

  Future<Box<WorkoutTemplate>> getUserBox() => _userBox.getUserBox();

  /// Coordinates local-only exercise changes with the active session queue.
  Future<T> coordinateExerciseEdit<T>(Future<T> Function() write) =>
      _serializeMutation(write);

  Future<T> _serializeMutation<T>(Future<T> Function() mutation) {
    final result =
        _mutationTail?.then((_) => mutation()) ?? Future<T>.sync(mutation);
    _mutationTail = result.then<void>(
      (_) => _requestSync(),
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  // ── Cloud sync ───────────────────────────────────────────────────────────

  /// The sync engine of the signed-in account's boxes.
  Future<RevisionSyncEngine<WorkoutTemplate>> syncEngine() async {
    final records = await getUserBox();
    final engine = _engines[records.name];
    if (engine != null && records.isOpen) return engine;
    final created = RevisionSyncEngine<WorkoutTemplate>(
      records: records,
      conflicts: await _conflictsBox.getUserBox(),
      tombstones: await _tombstonesBox.getUserBox(),
      state: await _stateBox.getUserBox(),
      cloud: remoteDataSource,
      adapter: WorkoutTemplateSyncAdapter(),
      newWriteId: _newWriteId,
    );
    _engines[records.name] = created;
    return created;
  }

  /// Sends local changes in the background (a push: no reads unless the
  /// server refuses a write). Never awaited by the UI and never throws
  /// (failures keep the change locally and are retried).
  ///
  /// It never opens storage: it only uses an engine whose boxes are open
  /// (created by the first load or an explicit sync). Before that, or after
  /// a logout closed them, the change simply waits for the next sync.
  void _requestSync() {
    final engine = _openEngine();
    if (engine == null) return;
    unawaited(
      engine.requestPush().catchError((Object error) {
        if (kDebugMode) debugPrint('[WorkoutTemplateRepository] $error');
        return SyncReport();
      }),
    );
  }

  RevisionSyncEngine<WorkoutTemplate>? _openEngine() {
    for (final engine in _engines.values.toList().reversed) {
      if (engine.records.isOpen &&
          engine.conflicts.isOpen &&
          engine.tombstones.isOpen) {
        return engine;
      }
    }
    return null;
  }

  /// One sync now: pull (only the changes since the last pull, or
  /// everything once a day), push, deletions. Offline is reported, not
  /// thrown.
  Future<SyncReport> syncWithCloud() async => (await syncEngine()).syncAll();

  /// True when every day in [templateIds] is confirmed by the server.
  Future<bool> isConfirmedInCloud(Iterable<String> templateIds) async {
    final box = await getUserBox();
    for (final id in templateIds) {
      final day = box.get(id);
      if (day == null) return false;
      final meta = day.syncMeta;
      if (!meta.isMigrated ||
          meta.hasFlight ||
          meta.hasConflict ||
          meta.hasUnsyncedChanges(day.contentFingerprint)) {
        return false;
      }
    }
    return true;
  }

  static const migrationMarkerKey = 'cloudMigration.v2.templates';

  /// The migration-complete marker (null until verified against the server).
  Future<Map?> migrationMarker() async =>
      (await _stateBox.getUserBox()).get(migrationMarkerKey);

  Future<void> _markMigrationIfVerified(
    RevisionSyncEngine<WorkoutTemplate> engine,
  ) async {
    final state = await _stateBox.getUserBox();
    if (state.containsKey(migrationMarkerKey)) return;
    final verification = await engine.verifyAgainstServer();
    if (!verification.complete) {
      if (kDebugMode) {
        debugPrint(
          '[WorkoutTemplateRepository] Cloud migration not complete yet: '
          '${verification.mismatches.length} item(s) pending.',
        );
      }
      return;
    }
    await state.put(migrationMarkerKey, {
      'verifiedAt': DateTime.now().toUtc().toIso8601String(),
      'days': verification.checked,
    });
    await state.flush();
  }

  /// Days that need the user: a conflict, or older exercises found in an
  /// old-format cloud document (prompted, or only offered on request).
  Future<List<WorkoutDaySyncIssue>> syncIssues() async {
    final box = await getUserBox();
    final engine = await syncEngine();
    final copies = {for (final c in engine.conflictCopies()) c['key']: c};
    return [
      for (final day in box.values)
        if (day.syncMeta.hasConflict || day.syncMeta.legacyCandidate != null)
          WorkoutDaySyncIssue(
            day: day,
            conflictCopy: copies[day.syncMeta.conflictKey],
          ),
    ];
  }

  /// Conflict: keep this device's version (re-based explicitly on the
  /// cloud revision found at the conflict).
  Future<void> keepMyVersion(String templateId) async {
    await (await syncEngine()).keepMine(templateId);
    _requestSync();
  }

  /// Conflict: keep the cloud version (the local copy stays available).
  Future<void> keepCloudVersion(String templateId) async {
    await (await syncEngine()).keepServer(templateId);
    _requestSync();
  }

  /// Deletes a saved conflict copy (only on the user's request).
  Future<void> discardConflictCopy(String key) async =>
      (await syncEngine()).discardConflictCopy(key);

  /// Restores ALL the older exercises found in the old-format cloud
  /// document (after the user saw the preview and confirmed). The current
  /// list, if any, is first saved as a conflict copy, so nothing is lost.
  /// More than a day may hold: the first [WorkoutLimits.maxActivitiesPerDay]
  /// go into this day and the rest into new days of the same program
  /// ([splitPlan] shows how, before confirming). Returns every day written,
  /// this one first.
  Future<List<WorkoutTemplate>> restoreOlderExercises(String templateId) =>
      _serializeMutation(() async {
        final box = await getUserBox();
        final day = box.get(templateId);
        final candidate = day?.syncMeta.legacyCandidate;
        if (day == null || candidate == null) {
          throw StateError('Nothing to restore.');
        }
        final engine = await syncEngine();
        if (day.exerciseAssignments.isNotEmpty) {
          final key = 'template:$templateId:${day.contentFingerprint}';
          await engine.conflicts.put(key, <String, dynamic>{
            'kind': 'template',
            'id': templateId,
            'reason': 'replacedByRestore',
            'detectedAt': DateTime.now().toUtc().toIso8601String(),
            'localHash': day.contentFingerprint,
            'content': day.toCloudContent(),
          });
          await engine.conflicts.flush();
        }
        final items = (candidate['items'] as List? ?? const [])
            .whereType<Map>()
            .map(WorkoutTemplateExerciseAssignment.fromActivityMap)
            .toList();
        final meta = day.syncMeta.withLegacyDecision('restored');
        return _writeSplit(
          box,
          day.withSyncMeta(meta.isMigrated ? meta : meta.migratedAsNew()),
          items,
        );
      });

  /// How [count] activities are spread over days of at most
  /// [WorkoutLimits.maxActivitiesPerDay]: the sizes, this day first.
  static List<int> splitPlan(int count) {
    const limit = WorkoutLimits.maxActivitiesPerDay;
    if (count <= limit) return [count];
    return [
      for (var start = 0; start < count; start += limit)
        count - start < limit ? count - start : limit,
    ];
  }

  /// A day with more activities than the cloud accepts (e.g. kept from an
  /// older version of the app, which had no limit) is never cut: the
  /// activities after the first [WorkoutLimits.maxActivitiesPerDay] move,
  /// in order, to new days of the same program. Returns every day written,
  /// this one first.
  Future<List<WorkoutTemplate>> splitOversizedDay(String templateId) =>
      _serializeMutation(() async {
        final box = await getUserBox();
        final day = box.get(templateId);
        if (day == null) throw StateError('Workout day not found.');
        return _writeSplit(box, day, day.exerciseAssignments);
      });

  /// Writes [items] into [day] and, beyond the limit, into new days named
  /// `<name> (2)`, `(3)`… at the end of the same program. The new days are
  /// written FIRST, with ids derived from the content being split: after an
  /// interruption the same split is simply done again (nothing duplicated),
  /// and the day itself is changed last.
  Future<List<WorkoutTemplate>> _writeSplit(
    Box<WorkoutTemplate> box,
    WorkoutTemplate day,
    List<WorkoutTemplateExerciseAssignment> items,
  ) async {
    const limit = WorkoutLimits.maxActivitiesPerDay;
    final now = DateTime.now();
    final sizes = splitPlan(items.length);
    final parts = <List<WorkoutTemplateExerciseAssignment>>[];
    var start = 0;
    for (final size in sizes) {
      parts.add(items.sublist(start, start + size));
      start += size;
    }
    final written = <WorkoutTemplate>[];
    if (parts.length > 1) {
      final splitId = contentHash([
        for (final item in items) item.toActivityMap(),
      ]).substring(0, 12);
      final siblings = box.values.where((d) => d.programId == day.programId);
      final orders = [
        for (final sibling in siblings)
          if (sibling.orderIndex != null) sibling.orderIndex!,
      ];
      final lastOrder = orders.isEmpty
          ? null
          : orders.reduce((a, b) => a > b ? a : b);
      for (var part = 1; part < parts.length; part++) {
        final id = '${day.id}-part${part + 1}-$splitId';
        final existing = box.get(id);
        if (existing != null) {
          written.add(existing); // done before an interruption
          continue;
        }
        final extra = WorkoutTemplate(
          id: id,
          programId: day.programId,
          name: '${day.name} (${part + 1})',
          createdAt: now,
          orderIndex: lastOrder == null ? null : lastOrder + part,
          exerciseAssignments: parts[part],
        ).withSyncMeta(SyncMeta.empty.migratedAsNew());
        await box.put(id, extra);
        written.add(extra);
      }
      await box.flush();
    }
    assert(parts.first.length <= limit);
    final updated = day.copyWith(
      exerciseAssignments: parts.first,
      updatedAt: now,
    );
    await box.put(day.id, updated);
    await box.flush();
    return [updated, ...written];
  }

  /// The user does not want the older exercises: never asked again (the
  /// decision is synced). The old cloud data itself is left untouched.
  Future<WorkoutTemplate> dismissOlderExercises(String templateId) =>
      _serializeMutation(() async {
        final box = await getUserBox();
        final day = box.get(templateId);
        if (day == null) throw StateError('Workout day not found.');
        final meta = day.syncMeta.withLegacyDecision('dismissed');
        final updated = day.withSyncMeta(
          meta.isMigrated ? meta : meta.migratedAsNew(),
        );
        await box.put(templateId, updated);
        await box.flush();
        return updated;
      });

  void _checkActivityLimit(int count) {
    if (count > WorkoutLimits.maxActivitiesPerDay) {
      throw const ActivityLimitExceededException();
    }
  }

  /// Adds one activity at the end of the day. With [cardio] it is a cardio
  /// activity with that plan (validated); otherwise a strength exercise.
  /// The same exercise can be in a day only once (each entry still gets
  /// its own assignment id).
  Future<WorkoutTemplate> addExerciseAssignment({
    required String templateId,
    required String exerciseId,
    required String exerciseNameSnapshot,
    required WorkoutExerciseReferenceType referenceType,
    CardioPlan? cardio,
  }) {
    return _serializeMutation(() async {
      final name = exerciseNameSnapshot.trim();
      if (exerciseId.trim().isEmpty || name.isEmpty) {
        throw ArgumentError('Exercise reference and name are required.');
      }
      cardio?.validate();
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
      _checkActivityLimit(template.exerciseAssignments.length + 1);

      final added = WorkoutTemplateExerciseAssignment(
        assignmentId: WorkoutIdGenerator.generate('assignment'),
        exerciseId: exerciseId,
        exerciseNameSnapshot: name,
        referenceType: referenceType.name,
      );
      final updated = template.copyWith(
        exerciseAssignments: [
          ...template.exerciseAssignments,
          cardio == null
              ? added
              : added.withActivity(type: ActivityType.cardio, cardio: cardio),
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

      _checkActivityLimit(assignments.length + added.length);
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

  /// Undo of a removal: puts [assignment] back (the same entry: its id,
  /// targets and plan) at [index] (clamped to the day). Already back: no
  /// change. Refused like any addition when the day is full, or when the
  /// same exercise was added to the day again meanwhile.
  Future<WorkoutTemplate> restoreExerciseAssignment({
    required String templateId,
    required WorkoutTemplateExerciseAssignment assignment,
    required int index,
  }) => _serializeMutation(() async {
    final box = await getUserBox();
    final template = box.get(templateId);
    if (template == null) throw StateError('Workout template not found.');
    final assignments = List<WorkoutTemplateExerciseAssignment>.of(
      template.exerciseAssignments,
    );
    if (assignments.any((a) => a.assignmentId == assignment.assignmentId)) {
      return template;
    }
    final name = normalizeExerciseName(assignment.exerciseNameSnapshot);
    final duplicate = assignments.any(
      (a) =>
          a.exerciseId == assignment.exerciseId ||
          normalizeExerciseName(a.exerciseNameSnapshot) == name,
    );
    if (duplicate) {
      throw DuplicateTemplateExerciseException(assignment.exerciseNameSnapshot);
    }
    _checkActivityLimit(assignments.length + 1);
    assignments.insert(index.clamp(0, assignments.length), assignment);
    final updated = template.copyWith(
      exerciseAssignments: assignments,
      updatedAt: DateTime.now(),
    );
    await box.put(templateId, updated);
    return updated;
  });

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

  /// Saves the settings of the cardio activity [assignmentId] (validated
  /// first: nothing is saved otherwise). Its id, exercise, name and place in
  /// the day stay as they are; settings this version doesn't know (written
  /// by another app version) are kept.
  Future<WorkoutTemplate> updateCardioPlan({
    required String templateId,
    required String assignmentId,
    required CardioPlan plan,
  }) => _serializeMutation(() async {
    plan.validate();
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
    final current = assignments[index];
    if (current.type != ActivityType.cardio) {
      throw StateError('Not a cardio activity.');
    }
    final kept = {
      for (final entry in (current.cardioData ?? const {}).entries)
        if (!CardioPlan.fieldNames.contains(entry.key)) entry.key: entry.value,
    };
    assignments[index] = WorkoutTemplateExerciseAssignment(
      assignmentId: current.assignmentId,
      exerciseId: current.exerciseId,
      exerciseNameSnapshot: current.exerciseNameSnapshot,
      referenceType: current.referenceType,
      activityType: current.activityType,
      schemaVersion: current.schemaVersion,
      cardioData: {...kept, ...plan.toMap()},
      timedData: current.timedData,
    );
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
      // A new id: there is no cloud copy to match it with, it is created.
    ).withSyncMeta(SyncMeta.empty.migratedAsNew());

    await box.put(id, template);
    _requestSync();
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
    _requestSync();
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
    _requestSync();
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
    _requestSync();
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
  ///
  /// Removed here immediately; in the cloud it becomes a revision-checked
  /// tombstone on the next sync (refused, and turned into a conflict, if
  /// another device changed the day meanwhile).
  Future<void> deleteTemplate(String templateId) async {
    final engine = await syncEngine();
    await engine.markDeleted(templateId);
    _requestSync();
  }

  /// Syncs with the cloud (pull, push, deletions, migration of old-format
  /// data), then records the migration as complete once every day is
  /// verified against the server. Offline is not an error.
  Future<void> fetchAndSyncFromRemote(Box<WorkoutTemplate> box) async {
    final engine = await syncEngine();
    final report = await engine.syncAll();
    if (kDebugMode) debugPrint('[WorkoutTemplateRepository] $report');
    if (!report.offline) await _markMigrationIfVerified(engine);
  }
}

/// A workout day that needs the user's decision.
class WorkoutDaySyncIssue {
  const WorkoutDaySyncIssue({required this.day, this.conflictCopy});

  final WorkoutTemplate day;

  /// This device's version saved at the conflict (conflicts only).
  final Map<String, dynamic>? conflictCopy;

  SyncMeta get meta => day.syncMeta;
  bool get isConflict => meta.hasConflict;

  /// Older exercises waiting for a decision (shown without being asked
  /// for only when [promptsUser]).
  List<WorkoutTemplateExerciseAssignment> get olderExercises => [
    for (final item in (meta.legacyCandidate?['items'] as List? ?? const []))
      if (item is Map) WorkoutTemplateExerciseAssignment.fromActivityMap(item),
  ];

  bool get promptsUser => isConflict || meta.legacyCandidate?['prompt'] == true;

  DateTime? get olderSavedAt {
    final value = meta.legacyCandidate?['savedAt'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  /// This device's version in a conflict.
  WorkoutTemplate? get myVersion {
    final content = conflictCopy?['content'];
    return content is Map
        ? WorkoutTemplate.fromCloudContent(
            Map<String, dynamic>.from(deepStringKeys(content) as Map),
          )
        : null;
  }
}

class ActivityLimitExceededException implements Exception {
  const ActivityLimitExceededException();

  int get limit => WorkoutLimits.maxActivitiesPerDay;

  @override
  String toString() =>
      'A workout day can hold at most ${WorkoutLimits.maxActivitiesPerDay} activities.';
}

class DuplicateTemplateExerciseException implements Exception {
  final String exerciseName;

  const DuplicateTemplateExerciseException(this.exerciseName);

  @override
  String toString() => 'This exercise is already assigned to the workout day.';
}
