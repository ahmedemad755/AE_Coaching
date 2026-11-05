import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program_draft.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/data/workout_id_generator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum WorkoutDraftError { invalid, saveFailed, accountChanged, legacyResolution }

class WorkoutProgramDraftState {
  final WorkoutProgramDraft draft;
  final bool saving;
  final WorkoutDraftError? error;
  final WorkoutTemplateImportResult? saved;
  const WorkoutProgramDraftState(
    this.draft, {
    this.saving = false,
    this.error,
    this.saved,
  });
}

class WorkoutProgramDraftCubit extends Cubit<WorkoutProgramDraftState> {
  final WorkoutTemplateImportService importer;
  WorkoutProgramDraftCubit({
    required WorkoutProgramDraft draft,
    required this.importer,
  }) : super(WorkoutProgramDraftState(draft));

  bool get _canEdit => !state.saving && state.saved == null && !isClosed;
  void _edit(WorkoutProgramDraft Function(WorkoutProgramDraft) edit) {
    if (!_canEdit) return;
    if (importer.currentUserId() != state.draft.ownerUid) {
      emit(
        WorkoutProgramDraftState(
          state.draft,
          error: WorkoutDraftError.accountChanged,
        ),
      );
      return;
    }
    try {
      emit(WorkoutProgramDraftState(edit(state.draft)));
    } catch (_) {
      emit(
        WorkoutProgramDraftState(state.draft, error: WorkoutDraftError.invalid),
      );
    }
  }

  void renameProgram(String name) =>
      _edit((draft) => draft.copyWith(name: name));
  void _day(String id, WorkoutTemplate Function(WorkoutTemplate) update) =>
      _edit(
        (draft) => draft.copyWith(
          days: [for (final d in draft.days) d.id == id ? update(d) : d],
        ),
      );
  void renameDay(String id, String name) =>
      _day(id, (d) => d.copyWith(name: name));

  void _assignments(
    String dayId,
    List<WorkoutTemplateExerciseAssignment> Function(
      List<WorkoutTemplateExerciseAssignment>,
    )
    change,
  ) => _day(dayId, (day) {
    final assignments = change(List.of(day.exerciseAssignments));
    if (assignments.map((e) => e.exerciseId).toSet().length !=
            assignments.length ||
        assignments
                .map((e) => normalizeExerciseName(e.exerciseNameSnapshot))
                .toSet()
                .length !=
            assignments.length) {
      throw ArgumentError('Duplicate exercise.');
    }
    return day.copyWith(exerciseAssignments: assignments);
  });

  void addExercises(
    String dayId,
    List<ExerciseLibraryItem> exercises,
    String languageCode,
  ) => _assignments(
    dayId,
    (items) => [
      ...items,
      for (final e in exercises)
        WorkoutTemplateExerciseAssignment(
          assignmentId: WorkoutIdGenerator.generate('assignment'),
          exerciseId: e.id,
          exerciseNameSnapshot: e.nameForLanguage(languageCode),
          referenceType: e.source == ExerciseLibraryItemSource.builtIn
              ? 'builtIn'
              : 'custom',
          workingSets: 2,
          targetRepsMin: 8,
          targetRepsMax: 12,
          restSeconds: 90,
        ),
    ],
  );
  void removeExercise(String dayId, String assignmentId) => _assignments(
    dayId,
    (items) => items.where((e) => e.assignmentId != assignmentId).toList(),
  );
  void replaceExercise(
    String dayId,
    String assignmentId,
    ExerciseLibraryItem exercise,
    String languageCode,
  ) => _assignments(
    dayId,
    (items) => [
      for (final e in items)
        e.assignmentId == assignmentId
            ? e.copyWith(
                exerciseId: exercise.id,
                exerciseNameSnapshot: exercise.nameForLanguage(languageCode),
                referenceType:
                    exercise.source == ExerciseLibraryItemSource.builtIn
                    ? 'builtIn'
                    : 'custom',
              )
            : e,
    ],
  );
  void updateTargets(
    String dayId,
    WorkoutTemplateExerciseAssignment assignment,
  ) => _assignments(dayId, (items) {
    assignment.validateTargets();
    return [
      for (final e in items)
        e.assignmentId == assignment.assignmentId
            ? e.copyWith(
                workingSets: assignment.workingSets,
                targetRepsMin: assignment.targetRepsMin,
                targetRepsMax: assignment.targetRepsMax,
                restSeconds: assignment.restSeconds,
              )
            : e,
    ];
  });
  void moveExercise(String dayId, int index, int delta) =>
      _assignments(dayId, (items) {
        final next = index + delta;
        if (index < 0 ||
            index >= items.length ||
            next < 0 ||
            next >= items.length) {
          return items;
        }
        items.insert(next, items.removeAt(index));
        return items;
      });

  Future<void> save() async {
    if (!_canEdit) return;
    final draft = state.draft;
    if (importer.currentUserId() != draft.ownerUid) {
      emit(
        WorkoutProgramDraftState(
          draft,
          error: WorkoutDraftError.accountChanged,
        ),
      );
      return;
    }
    if (draft.name.trim().isEmpty ||
        draft.days.any(
          (d) => d.name.trim().isEmpty || d.exerciseAssignments.isEmpty,
        )) {
      emit(WorkoutProgramDraftState(draft, error: WorkoutDraftError.invalid));
      return;
    }
    emit(WorkoutProgramDraftState(draft, saving: true));
    try {
      final saved = await importer.save(draft);
      if (!isClosed) emit(WorkoutProgramDraftState(draft, saved: saved));
    } on UnresolvedLegacyExerciseException {
      if (!isClosed) {
        emit(
          WorkoutProgramDraftState(
            draft,
            error: WorkoutDraftError.legacyResolution,
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          WorkoutProgramDraftState(
            draft,
            error: importer.currentUserId() != draft.ownerUid
                ? WorkoutDraftError.accountChanged
                : WorkoutDraftError.saveFailed,
          ),
        );
      }
    }
  }
}
