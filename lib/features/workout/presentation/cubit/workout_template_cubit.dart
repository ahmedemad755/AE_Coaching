import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_cascade_deletion_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'workout_template_state.dart';

/// Dedicated Cubit for the Workout Days UI — separate from
/// WorkoutProgramCubit/WorkoutCubit/etc. Only ever reads/writes the
/// current user's `workout_templates_$uid` box via
/// [WorkoutTemplateRepository]. No session logic lives here.
class WorkoutTemplateCubit extends Cubit<WorkoutTemplateState> {
  final WorkoutTemplateRepository repository;
  final WorkoutCascadeDeletionService deletionService;

  // Stage 3: see HomeWorkoutOverviewCubit.
  WorkoutTemplateCubit({
    required this.repository,
    required this.deletionService,
  }) : super(const WorkoutTemplateInitial());

  Future<void> loadTemplates() async {
    emit(const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.load));
    try {
      final box = await repository.getUserBox();
      emit(WorkoutTemplateLoaded(box: box));

      await repository.fetchAndSyncFromRemote(box);
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(WorkoutTemplateError(operation: WorkoutTemplateOperation.load, message: _mapExceptionToMessage(error)));
    }
  }

  Future<void> createTemplate({required String programId, required String name}) async {
    emit(const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.create));
    try {
      final box = await repository.getUserBox();
      // New templates append to the end of the current visual order.
      final existingForProgram = repository.getTemplatesForProgram(box, programId, includeArchived: true);
      final nextOrderIndex = existingForProgram.length;

      await repository.createTemplate(programId: programId, name: name, orderIndex: nextOrderIndex);
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(WorkoutTemplateError(operation: WorkoutTemplateOperation.create, message: _mapExceptionToMessage(error)));
    }
  }

  Future<void> renameTemplate({required String templateId, required String newName}) async {
    emit(const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.rename));
    try {
      final box = await repository.getUserBox();
      await repository.updateTemplate(templateId: templateId, name: newName);
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(WorkoutTemplateError(operation: WorkoutTemplateOperation.rename, message: _mapExceptionToMessage(error)));
    }
  }

  Future<void> archiveTemplate(String templateId) async {
    emit(const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.archive));
    try {
      final box = await repository.getUserBox();
      await repository.archiveTemplate(templateId);
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(WorkoutTemplateError(operation: WorkoutTemplateOperation.archive, message: _mapExceptionToMessage(error)));
    }
  }

  /// Reverses [archiveTemplate] — brings a workout day back into the
  /// normal active list, so it shows up in the Workout Days screen
  /// again exactly as it did before being archived.
  Future<void> restoreTemplate(String templateId) async {
    emit(const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.restore));
    try {
      final box = await repository.getUserBox();
      await repository.restoreTemplate(templateId);
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(WorkoutTemplateError(operation: WorkoutTemplateOperation.restore, message: _mapExceptionToMessage(error)));
    }
  }

  /// Permanently deletes [templateId] and EVERYTHING under it (every
  /// session, every logged set) — see [WorkoutCascadeDeletionService].
  /// This is a real, irreversible delete; [archiveTemplate] remains
  /// the normal, non-destructive action. Only call this after an
  /// explicit, unambiguous user confirmation.
  Future<void> deleteTemplate(String templateId) async {
    emit(const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.delete));
    try {
      await deletionService.deleteTemplateCascade(templateId);
      final box = await repository.getUserBox();
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(WorkoutTemplateError(operation: WorkoutTemplateOperation.delete, message: _mapExceptionToMessage(error)));
    }
  }

  /// Re-sequences [orderedTemplateIds] to orderIndex 0..n-1 in the
  /// given order. UI computes the new order (e.g. swapping two
  /// adjacent cards) and passes the full resulting id list; this
  /// persists it. Safe/simple alternative to full drag-and-drop.
  Future<void> reorderTemplates(List<String> orderedTemplateIds) async {
    emit(const WorkoutTemplateLoading(operation: WorkoutTemplateOperation.reorder));
    try {
      final box = await repository.getUserBox();
      for (var i = 0; i < orderedTemplateIds.length; i++) {
        await repository.updateTemplate(templateId: orderedTemplateIds[i], orderIndex: i);
      }
      emit(WorkoutTemplateLoaded(box: box));
    } catch (error) {
      emit(WorkoutTemplateError(operation: WorkoutTemplateOperation.reorder, message: _mapExceptionToMessage(error)));
    }
  }

  String _mapExceptionToMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
