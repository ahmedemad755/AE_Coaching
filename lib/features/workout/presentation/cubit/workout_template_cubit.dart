import 'package:ae_coaching/core/utils/close_safe_emit.dart';
import 'package:ae_coaching/core/errors/exception_message_mapper.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_cascade_deletion_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'workout_template_state.dart';

/// Dedicated Cubit for the Workout Days UI — separate from
/// WorkoutProgramCubit/WorkoutCubit/etc. Only ever reads/writes the
/// current user's `workout_templates_$uid` box via
/// [WorkoutTemplateRepository]. No session logic lives here.
class WorkoutTemplateCubit extends Cubit<WorkoutTemplateState>
    with CloseSafeEmit<WorkoutTemplateState> {
  final WorkoutTemplateRepository repository;
  final WorkoutCascadeDeletionService deletionService;
  final Future<void> Function()? migrateCatalogReferences;

  /// Syncs data the days depend on (custom exercises) with the cloud.
  final Future<void> Function()? syncRelated;

  // Stage 3: see HomeWorkoutOverviewCubit.
  WorkoutTemplateCubit({
    required this.repository,
    required this.deletionService,
    this.migrateCatalogReferences,
    this.syncRelated,
  }) : super(const WorkoutTemplateInitial());

  Future<void> _syncQuietly(String what, Future<void> Function() sync) async {
    try {
      await sync();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[WorkoutTemplateCubit] $what not synced: $error');
      }
    }
  }

  Future<void> loadTemplates() async {
    emit(
      const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.load),
    );
    try {
      final box = await repository.getUserBox();
      await migrateCatalogReferences?.call();
      emit(WorkoutTemplateLoaded(box: box));

      // The days are shown from local data. Syncing can never turn that
      // into an error (e.g. reading refused before the rules are deployed):
      // what could not be synced stays here and is sent next time.
      await _syncQuietly('custom exercises', () async => syncRelated?.call());
      await _syncQuietly(
        'workout days',
        () => repository.fetchAndSyncFromRemote(box),
      );
      await migrateCatalogReferences?.call();
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutTemplateError(
          operation: WorkoutTemplateOperation.load,
          message: mapGenericExceptionToMessage(error),
        ),
      );
    }
  }

  Future<void> createTemplate({
    required String programId,
    required String name,
  }) async {
    emit(
      const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.create),
    );
    try {
      final box = await repository.getUserBox();
      // New templates append to the end of the current visual order.
      final existingForProgram = repository.getTemplatesForProgram(
        box,
        programId,
        includeArchived: true,
      );
      final nextOrderIndex = existingForProgram.length;

      await repository.createTemplate(
        programId: programId,
        name: name,
        orderIndex: nextOrderIndex,
      );
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutTemplateError(
          operation: WorkoutTemplateOperation.create,
          message: mapGenericExceptionToMessage(error),
        ),
      );
    }
  }

  Future<void> renameTemplate({
    required String templateId,
    required String newName,
  }) async {
    emit(
      const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.rename),
    );
    try {
      final box = await repository.getUserBox();
      await repository.updateTemplate(templateId: templateId, name: newName);
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutTemplateError(
          operation: WorkoutTemplateOperation.rename,
          message: mapGenericExceptionToMessage(error),
        ),
      );
    }
  }

  Future<void> archiveTemplate(String templateId) async {
    emit(
      const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.archive),
    );
    try {
      final box = await repository.getUserBox();
      await repository.archiveTemplate(templateId);
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutTemplateError(
          operation: WorkoutTemplateOperation.archive,
          message: mapGenericExceptionToMessage(error),
        ),
      );
    }
  }

  /// Reverses [archiveTemplate] — brings a workout day back into the
  /// normal active list, so it shows up in the Workout Days screen
  /// again exactly as it did before being archived.
  Future<void> restoreTemplate(String templateId) async {
    emit(
      const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.restore),
    );
    try {
      final box = await repository.getUserBox();
      await repository.restoreTemplate(templateId);
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutTemplateError(
          operation: WorkoutTemplateOperation.restore,
          message: mapGenericExceptionToMessage(error),
        ),
      );
    }
  }

  /// Permanently deletes [templateId] and EVERYTHING under it (every
  /// session, every logged set) — see [WorkoutCascadeDeletionService].
  /// This is a real, irreversible delete; [archiveTemplate] remains
  /// the normal, non-destructive action. Only call this after an
  /// explicit, unambiguous user confirmation.
  Future<void> deleteTemplate(String templateId) async {
    emit(
      const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.delete),
    );
    try {
      await deletionService.deleteTemplateCascade(templateId);
      final box = await repository.getUserBox();
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutTemplateError(
          operation: WorkoutTemplateOperation.delete,
          message: mapGenericExceptionToMessage(error),
        ),
      );
    }
  }

  /// Re-sequences [orderedTemplateIds] to orderIndex 0..n-1 in the
  /// given order. UI computes the new order (e.g. swapping two
  /// adjacent cards) and passes the full resulting id list; this
  /// persists it. Safe/simple alternative to full drag-and-drop.
  Future<void> reorderTemplates(List<String> orderedTemplateIds) async {
    emit(
      const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.reorder),
    );
    try {
      final box = await repository.getUserBox();
      for (var i = 0; i < orderedTemplateIds.length; i++) {
        await repository.updateTemplate(
          templateId: orderedTemplateIds[i],
          orderIndex: i,
        );
      }
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutTemplateError(
          operation: WorkoutTemplateOperation.reorder,
          message: mapGenericExceptionToMessage(error),
        ),
      );
    }
  }
}
