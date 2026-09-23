import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
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

  /// @visibleForTesting seam — see WorkoutProgramRepository for why
  /// this exists (no real Firebase app in a unit-test environment).
  @visibleForTesting
  final String? Function()? uidOverride;

  WorkoutTemplateRepository({
    WorkoutTemplateRemoteDataSource? remoteDataSource,
    required UserStorageManager storageManager,
    @visibleForTesting this.uidOverride,
  })  : remoteDataSource = remoteDataSource ?? WorkoutTemplateRemoteDataSourceImpl(),
        _userBox = UserBox<WorkoutTemplate>(
          manager: storageManager,
          prefix: 'workout_templates',
          uidOverride: uidOverride,
        );

  Future<Box<WorkoutTemplate>> getUserBox() => _userBox.getUserBox();

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
    final matches = box.values.where((t) => t.programId == programId && (includeArchived || !t.isArchived)).toList();

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

  WorkoutTemplate? getTemplateById(Box<WorkoutTemplate> box, String templateId) {
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

    final archived = target.copyWith(isArchived: true, updatedAt: DateTime.now());
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

    final restored = target.copyWith(isArchived: false, updatedAt: DateTime.now());
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
        final template = WorkoutTemplate.fromJson(doc.data());
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
      debugPrint('Failed to fetch and sync workout templates from cloud: $error\n$stackTrace');
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
