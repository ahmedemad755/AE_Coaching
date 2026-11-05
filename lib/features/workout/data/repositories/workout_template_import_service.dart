import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program_draft.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';

class UnresolvedLegacyExerciseException implements Exception {
  const UnresolvedLegacyExerciseException(this.exerciseId);
  final String exerciseId;
}

class WorkoutTemplateImportResult {
  final WorkoutProgram program;
  final bool cloudSyncIncomplete;
  const WorkoutTemplateImportResult(
    this.program, {
    required this.cloudSyncIncomplete,
  });
}

/// Composes the existing user-scoped repositories and their existing metadata
/// sync endpoints. Assignments/targets remain local, exactly as ordinary days.
class WorkoutTemplateImportService {
  final WorkoutProgramRepository programs;
  final WorkoutTemplateRepository templates;
  final String? Function() currentUserId;
  final Duration syncTimeout;
  final ExerciseCatalogRepository? catalog;
  final Set<String> _saving = {};
  WorkoutTemplateImportService({
    required this.programs,
    required this.templates,
    required this.currentUserId,
    this.syncTimeout = const Duration(seconds: 8),
    this.catalog,
  });

  void _checkOwner(String owner) {
    if (owner.isEmpty || currentUserId() != owner) {
      throw StateError('Account changed.');
    }
  }

  Future<WorkoutTemplateImportResult> save(WorkoutProgramDraft draft) async {
    _checkOwner(draft.ownerUid);
    if (!_saving.add(draft.programId)) {
      throw StateError('Save already in progress.');
    }
    try {
      final source = catalog;
      if (source != null) {
        final days = <WorkoutTemplate>[];
        for (final day in draft.days) {
          final assignments = <WorkoutTemplateExerciseAssignment>[];
          for (final assignment in day.exerciseAssignments) {
            if (assignment.referenceType != 'builtIn') {
              assignments.add(assignment);
              continue;
            }
            final resolved = await source.resolveReference(
              assignment.exerciseId,
            );
            _checkOwner(draft.ownerUid);
            if (resolved?.isRepDb != true) {
              throw UnresolvedLegacyExerciseException(assignment.exerciseId);
            }
            assignments.add(assignment.copyWith(exerciseId: resolved!.id));
          }
          days.add(day.copyWith(exerciseAssignments: assignments));
        }
        draft = draft.copyWith(days: days);
      }
      if (draft.name.trim().isEmpty || draft.days.isEmpty) {
        throw ArgumentError('Program name and days are required.');
      }
      final dayIds = <String>{};
      final assignmentIds = <String>{};
      for (final day in draft.days) {
        if (day.programId != draft.programId ||
            !dayIds.add(day.id) ||
            day.name.trim().isEmpty ||
            day.exerciseAssignments.isEmpty) {
          throw ArgumentError('Invalid draft day.');
        }
        final exercises = <String>{};
        for (final e in day.exerciseAssignments) {
          e.validateTargets();
          if (!e.hasTargets ||
              !assignmentIds.add(e.assignmentId) ||
              !exercises.add(e.exerciseId) ||
              e.exerciseNameSnapshot.trim().isEmpty) {
            throw ArgumentError('Invalid draft exercise.');
          }
        }
      }
      final programBox = await programs.getUserBox();
      _checkOwner(draft.ownerUid);
      final dayBox = await templates.getUserBox();
      _checkOwner(draft.ownerUid);
      if (programBox.name !=
              'workout_programs_${draft.ownerUid}'.toLowerCase() ||
          dayBox.name != 'workout_templates_${draft.ownerUid}'.toLowerCase() ||
          programBox.containsKey(draft.programId) ||
          draft.days.any((d) => dayBox.containsKey(d.id))) {
        throw StateError('Refusing to overwrite existing data.');
      }
      final program = WorkoutProgram(
        id: draft.programId,
        name: draft.name.trim(),
        createdAt: DateTime.now(),
      );
      // Publish the program only after all its complete days exist. On local
      // failure roll back only freshly allocated draft IDs; no cascade/history.
      try {
        await dayBox.putAll({for (final d in draft.days) d.id: d});
        _checkOwner(draft.ownerUid);
        await programBox.put(program.id, program);
      } catch (_) {
        if (programBox.isOpen) await programBox.delete(draft.programId);
        if (dayBox.isOpen) await dayBox.deleteAll(dayIds);
        rethrow;
      }
      var syncIncomplete = false;
      final syncClock = Stopwatch()..start();
      Duration remainingSyncTime() {
        final remaining = syncTimeout - syncClock.elapsed;
        if (remaining <= Duration.zero) {
          throw StateError('Cloud backup timed out.');
        }
        return remaining;
      }

      // Local save has succeeded. A failed existing cloud backup must not
      // offer "Save again" and accidentally create duplicate programs.
      try {
        _checkOwner(draft.ownerUid);
        final programTimeout = remainingSyncTime();
        await programs.remoteDataSource
            .syncProgram(program.id, program)
            .timeout(programTimeout);
        for (final day in draft.days) {
          _checkOwner(draft.ownerUid);
          final dayTimeout = remainingSyncTime();
          await templates.remoteDataSource
              .syncTemplate(day.id, day)
              .timeout(dayTimeout);
        }
      } catch (_) {
        syncIncomplete = true;
      }
      return WorkoutTemplateImportResult(
        program,
        cloudSyncIncomplete: syncIncomplete,
      );
    } finally {
      _saving.remove(draft.programId);
    }
  }
}
