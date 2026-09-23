import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_cascade_deletion_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'workout_program_state.dart';

/// Dedicated Cubit for the Programs UI — completely separate from
/// WorkoutCubit/MeasurementCubit/ProgressPhotoCubit. Only ever reads/
/// writes the current user's `workout_programs_$uid` box via
/// [WorkoutProgramRepository]. No template/session logic lives here.
class WorkoutProgramCubit extends Cubit<WorkoutProgramState> {
  final WorkoutProgramRepository repository;
  final WorkoutCascadeDeletionService deletionService;

  // Stage 3: see HomeWorkoutOverviewCubit — both dependencies' own
  // zero-arg fallbacks are dead code nothing exercises, and
  // WorkoutCascadeDeletionService's own fallbacks were removed for the
  // same reason.
  WorkoutProgramCubit({
    required this.repository,
    required this.deletionService,
  }) : super(const WorkoutProgramInitial());

  /// Offline-first load: shows whatever is cached on-device immediately,
  /// then silently syncs with Firestore in the background — same
  /// pattern as WorkoutCubit/MeasurementCubit.
  Future<void> loadPrograms() async {
    emit(const WorkoutProgramLoading(operation: WorkoutProgramOperation.load));
    try {
      final box = await repository.getUserBox();
      emit(WorkoutProgramLoaded(box: box));

      await repository.fetchAndSyncFromRemote(box);
      emit(WorkoutProgramLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutProgramError(
          operation: WorkoutProgramOperation.load,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  /// Re-emits the current box without a network round-trip — for
  /// pull-to-refresh or re-asserting state after an error, without
  /// re-hitting Firestore every time.
  Future<void> refreshPrograms() async {
    try {
      final box = await repository.getUserBox();
      emit(WorkoutProgramLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutProgramError(
          operation: WorkoutProgramOperation.load,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  Future<void> createProgram({
    required String name,
    String? description,
    bool makeActive = false,
  }) async {
    emit(const WorkoutProgramLoading(operation: WorkoutProgramOperation.create));
    try {
      await repository.createProgram(name: name, description: description, makeActive: makeActive);
      final box = await repository.getUserBox();
      emit(WorkoutProgramLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutProgramError(
          operation: WorkoutProgramOperation.create,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  /// Renames a program without touching anything else — id, createdAt,
  /// startedAt, endedAt, isActive all pass through untouched via
  /// [WorkoutProgram.copyWith].
  Future<void> renameProgram({required String programId, required String newName}) async {
    emit(const WorkoutProgramLoading(operation: WorkoutProgramOperation.rename));
    try {
      final box = await repository.getUserBox();
      final existing = box.get(programId);
      if (existing == null) {
        throw Exception('Workout program not found.');
      }

      await repository.updateProgram(existing.copyWith(name: newName));
      emit(WorkoutProgramLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutProgramError(
          operation: WorkoutProgramOperation.rename,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  /// Delegates entirely to the repository's single-active-program
  /// invariant — no active/previous logic is duplicated here.
  Future<void> setActiveProgram(String programId) async {
    emit(const WorkoutProgramLoading(operation: WorkoutProgramOperation.setActive));
    try {
      await repository.setActiveProgram(programId);
      final box = await repository.getUserBox();
      emit(WorkoutProgramLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutProgramError(
          operation: WorkoutProgramOperation.setActive,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  Future<void> archiveProgram(String programId) async {
    emit(const WorkoutProgramLoading(operation: WorkoutProgramOperation.archive));
    try {
      await repository.archiveProgram(programId);
      final box = await repository.getUserBox();
      emit(WorkoutProgramLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutProgramError(
          operation: WorkoutProgramOperation.archive,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  /// Permanently deletes [programId] and EVERYTHING under it (every
  /// workout day, every session, every logged set) — see
  /// [WorkoutCascadeDeletionService]. This is a real, irreversible
  /// delete; [archiveProgram] remains the normal, non-destructive
  /// action and should be preferred by the UI's default flow. Only
  /// call this after an explicit, unambiguous user confirmation.
  Future<void> deleteProgram(String programId) async {
    emit(const WorkoutProgramLoading(operation: WorkoutProgramOperation.delete));
    try {
      await deletionService.deleteProgramCascade(programId);
      final box = await repository.getUserBox();
      emit(WorkoutProgramLoaded(box: box));
    } catch (error) {
      emit(
        WorkoutProgramError(
          operation: WorkoutProgramOperation.delete,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  String _mapExceptionToMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
