import 'dart:convert';

import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/workout_id_generator.dart';

enum ActiveWorkoutEditScope { sessionOnly, sessionAndProgram }

enum ActiveWorkoutEditAction {
  add,
  replace,
  remove,
  reorder,
  targets,
  applyProgram,
}

enum ActiveWorkoutEditFailure {
  loggedSets,
  conflict,
  duplicate,
  pending,
  inactive,
}

class ActiveWorkoutEditException implements Exception {
  final ActiveWorkoutEditFailure reason;
  const ActiveWorkoutEditException(this.reason);
}

/// All edits are derived from the current persisted session, never a route
/// snapshot. Uses the repositories' existing queues and user-scoped boxes.
/// Assignments, targets and the recovery journal remain entirely local.
class ActiveWorkoutEditService {
  final WorkoutSessionRepository sessions;
  final WorkoutTemplateRepository templates;
  final SessionExerciseRepository sets;

  ActiveWorkoutEditService({
    required this.sessions,
    required this.templates,
    required this.sets,
  });

  Future<WorkoutSession> recover(
    String sessionId, {
    bool keepSessionOnly = false,
  }) => sessions.coordinateExerciseEdit(
    () => templates.coordinateExerciseEdit(() async {
      final sessionBox = await sessions.getUserBox();
      final current = sessionBox.get(sessionId);
      if (current == null || !current.isInProgress) {
        throw const ActiveWorkoutEditException(
          ActiveWorkoutEditFailure.inactive,
        );
      }
      _assertOwner(sessionBox.name);
      if (current.pendingProgramExerciseEdit == null) return current;
      final templateBox = await templates.getUserBox();
      _sameOwner(sessionBox.name, templateBox.name);
      final day = templateBox.get(current.workoutTemplateId);
      if (!keepSessionOnly) {
        final journal = jsonDecode(current.pendingProgramExerciseEdit!) as Map;
        if (day == null ||
            day.programId != current.programId ||
            day.isArchived) {
          throw const ActiveWorkoutEditException(
            ActiveWorkoutEditFailure.conflict,
          );
        }
        final actual = _encode(day.exerciseAssignments);
        final desired = journal['after'] as String;
        if (actual != desired) {
          if (actual != journal['before']) {
            throw const ActiveWorkoutEditException(
              ActiveWorkoutEditFailure.conflict,
            );
          }
          _assertOwner(sessionBox.name);
          await templateBox.put(
            day.id,
            day.copyWith(
              exerciseAssignments: _decode(desired),
              updatedAt: DateTime.now(),
            ),
          );
        }
      }
      final updated = current.copyWith(clearPendingProgramExerciseEdit: true);
      _assertOwner(sessionBox.name);
      _assertOwner(sessionBox.name);
      await sessionBox.put(current.id, updated);
      return updated;
    }),
  );

  Future<WorkoutSession> edit({
    required String sessionId,
    required ActiveWorkoutEditAction action,
    ActiveWorkoutEditScope scope = ActiveWorkoutEditScope.sessionOnly,
    String? exerciseName,
    List<ExerciseLibraryItem> exercises = const [],
    String languageCode = 'en',
    List<String> orderedNames = const [],
    WorkoutTemplateExerciseAssignment? targets,
  }) => sessions.coordinateExerciseEdit(
    () => templates.coordinateExerciseEdit(() async {
      final sessionBox = await sessions.getUserBox();
      final setBox = await sets.getUserBox();
      _sameOwner(sessionBox.name, setBox.name);
      final current = sessionBox.get(sessionId);
      if (current == null || !current.isInProgress) {
        throw const ActiveWorkoutEditException(
          ActiveWorkoutEditFailure.inactive,
        );
      }
      if (current.pendingProgramExerciseEdit != null) {
        throw const ActiveWorkoutEditException(
          ActiveWorkoutEditFailure.pending,
        );
      }
      final logged = sets
          .getExerciseNamesForSession(setBox, current.id)
          .map(normalizeExerciseName)
          .toSet();
      final hidden = current.hiddenExerciseNames
          .map(normalizeExerciseName)
          .toSet();
      hidden.removeAll(logged);
      final original = <WorkoutTemplateExerciseAssignment>[];
      final names = <String>{};
      void include(WorkoutTemplateExerciseAssignment item) {
        final name = normalizeExerciseName(item.exerciseNameSnapshot);
        if (!hidden.contains(name) && names.add(name)) original.add(item);
      }

      WorkoutTemplateExerciseAssignment manual(String name) =>
          WorkoutTemplateExerciseAssignment(
            assignmentId: WorkoutIdGenerator.generate('session_assignment'),
            exerciseId: 'manual:${normalizeExerciseName(name)}',
            exerciseNameSnapshot: name,
            referenceType: WorkoutExerciseReferenceType.manual.name,
          );
      for (final item in current.templateExerciseAssignmentsSnapshot) {
        include(item);
      }
      for (final name in sets.getExerciseNamesForSession(setBox, current.id)) {
        include(manual(name));
      }
      for (final name in current.sessionExerciseNames) {
        include(manual(name));
      }
      final previous = sessions.getPreviousCompletedSession(
        sessionBox,
        current.programId,
        current.workoutTemplateId,
        excludeSessionId: current.id,
      );
      if (previous != null) {
        for (final name in sets.getExerciseNamesForSession(
          setBox,
          previous.id,
        )) {
          include(manual(name));
        }
      }
      final order = {
        for (var i = 0; i < current.exerciseOrder.length; i++)
          normalizeExerciseName(current.exerciseOrder[i]): i,
      };
      final naturalOrder = {
        for (var i = 0; i < original.length; i++) original[i].assignmentId: i,
      };
      original.sort(
        (a, b) =>
            (order[normalizeExerciseName(a.exerciseNameSnapshot)] ??
                    (order.length + naturalOrder[a.assignmentId]!))
                .compareTo(
                  order[normalizeExerciseName(b.exerciseNameSnapshot)] ??
                      (order.length + naturalOrder[b.assignmentId]!),
                ),
      );
      final updatedAssignments = [...original];
      final index = original.indexWhere(
        (item) =>
            normalizeExerciseName(item.exerciseNameSnapshot) ==
            normalizeExerciseName(exerciseName ?? ''),
      );
      if ([
            ActiveWorkoutEditAction.remove,
            ActiveWorkoutEditAction.replace,
            ActiveWorkoutEditAction.targets,
          ].contains(action) &&
          index < 0) {
        throw const ActiveWorkoutEditException(
          ActiveWorkoutEditFailure.conflict,
        );
      }
      if ([
            ActiveWorkoutEditAction.remove,
            ActiveWorkoutEditAction.replace,
          ].contains(action) &&
          logged.contains(normalizeExerciseName(exerciseName!))) {
        throw const ActiveWorkoutEditException(
          ActiveWorkoutEditFailure.loggedSets,
        );
      }
      WorkoutTemplateExerciseAssignment assignment(ExerciseLibraryItem item) =>
          WorkoutTemplateExerciseAssignment(
            assignmentId: WorkoutIdGenerator.generate('session_assignment'),
            exerciseId: item.id,
            exerciseNameSnapshot: item.nameForLanguage(languageCode).trim(),
            referenceType: item.source == ExerciseLibraryItemSource.builtIn
                ? WorkoutExerciseReferenceType.builtIn.name
                : WorkoutExerciseReferenceType.custom.name,
          );
      final added = exercises.map(assignment).toList();
      switch (action) {
        case ActiveWorkoutEditAction.add:
          if (added.isEmpty) throw ArgumentError('Select exercises.');
          updatedAssignments.addAll(added);
        case ActiveWorkoutEditAction.replace:
          if (added.length != 1) throw ArgumentError('Select one exercise.');
          updatedAssignments[index] = original[index].copyWith(
            exerciseId: added.single.exerciseId,
            exerciseNameSnapshot: added.single.exerciseNameSnapshot,
            referenceType: added.single.referenceType,
          );
        case ActiveWorkoutEditAction.remove:
          updatedAssignments.removeAt(index);
        case ActiveWorkoutEditAction.reorder:
          final byName = {
            for (final item in original)
              normalizeExerciseName(item.exerciseNameSnapshot): item,
          };
          final requested = orderedNames.map(normalizeExerciseName).toList();
          if (requested.length != byName.length ||
              requested.toSet().length != requested.length ||
              !requested.toSet().containsAll(byName.keys)) {
            throw const ActiveWorkoutEditException(
              ActiveWorkoutEditFailure.conflict,
            );
          }
          updatedAssignments
            ..clear()
            ..addAll(requested.map((name) => byName[name]!));
        case ActiveWorkoutEditAction.targets:
          if (targets == null) throw ArgumentError('Targets required.');
          targets.validateTargets();
          if (!targets.hasTargets) {
            throw ArgumentError('Complete targets required.');
          }
          updatedAssignments[index] = original[index].copyWith(
            workingSets: targets.workingSets,
            targetRepsMin: targets.targetRepsMin,
            targetRepsMax: targets.targetRepsMax,
            restSeconds: targets.restSeconds,
          );
        case ActiveWorkoutEditAction.applyProgram:
          break;
      }
      final templateBox =
          scope == ActiveWorkoutEditScope.sessionAndProgram ||
              action == ActiveWorkoutEditAction.applyProgram
          ? await templates.getUserBox()
          : null;
      if (templateBox != null) _sameOwner(sessionBox.name, templateBox.name);
      final day = templateBox?.get(current.workoutTemplateId);
      if (templateBox != null &&
          (day == null ||
              day.programId != current.programId ||
              day.isArchived)) {
        throw const ActiveWorkoutEditException(
          ActiveWorkoutEditFailure.conflict,
        );
      }
      if (action == ActiveWorkoutEditAction.applyProgram) {
        final incomingNames = day!.exerciseAssignments
            .map((e) => normalizeExerciseName(e.exerciseNameSnapshot))
            .toSet();
        if (!incomingNames.containsAll(logged)) {
          throw const ActiveWorkoutEditException(
            ActiveWorkoutEditFailure.loggedSets,
          );
        }
        updatedAssignments
          ..clear()
          ..addAll(day.exerciseAssignments);
      }
      _validateUnique(updatedAssignments);
      for (final item in updatedAssignments) {
        item.validateTargets();
      }
      String? journal;
      if (scope == ActiveWorkoutEditScope.sessionAndProgram) {
        final program = [...day!.exerciseAssignments];
        if (action == ActiveWorkoutEditAction.add) {
          program.addAll(added);
        } else if (action == ActiveWorkoutEditAction.reorder) {
          final requestedIds = updatedAssignments
              .map((a) => a.assignmentId)
              .toList();
          final matching =
              program
                  .where((a) => requestedIds.contains(a.assignmentId))
                  .toList()
                ..sort(
                  (a, b) => requestedIds
                      .indexOf(a.assignmentId)
                      .compareTo(requestedIds.indexOf(b.assignmentId)),
                );
          var next = 0;
          for (var i = 0; i < program.length; i++) {
            if (requestedIds.contains(program[i].assignmentId)) {
              program[i] = matching[next++];
            }
          }
        } else {
          final old = original[index];
          final programIndex = program.indexWhere(
            (a) => a.assignmentId == old.assignmentId,
          );
          final sessionOnly = current.sessionExerciseNames.any(
            (name) =>
                normalizeExerciseName(name) ==
                normalizeExerciseName(old.exerciseNameSnapshot),
          );
          if (programIndex < 0 && sessionOnly) {
            if (action != ActiveWorkoutEditAction.remove) {
              program.add(updatedAssignments[index]);
            }
          } else if (programIndex < 0 ||
              _encode([program[programIndex]]) != _encode([old])) {
            // Never overwrite a changed/deleted source assignment implicitly.
            throw const ActiveWorkoutEditException(
              ActiveWorkoutEditFailure.conflict,
            );
          } else if (action == ActiveWorkoutEditAction.remove) {
            program.removeAt(programIndex);
          } else {
            program[programIndex] = updatedAssignments[index];
          }
        }
        _validateUnique(program);
        journal = jsonEncode({
          'before': _encode(day.exerciseAssignments),
          'after': _encode(program),
        });
      }
      final visible = updatedAssignments
          .map((a) => normalizeExerciseName(a.exerciseNameSnapshot))
          .toSet();
      final hiddenNames =
          <String>{
                ...current.hiddenExerciseNames,
                for (final old in original)
                  if (!visible.contains(
                    normalizeExerciseName(old.exerciseNameSnapshot),
                  ))
                    old.exerciseNameSnapshot,
              }
              .where((name) => !visible.contains(normalizeExerciseName(name)))
              .toList();
      final sessionOnlyNames = current.sessionExerciseNames
          .map(normalizeExerciseName)
          .toSet();
      if (action == ActiveWorkoutEditAction.add &&
          scope == ActiveWorkoutEditScope.sessionOnly) {
        sessionOnlyNames.addAll(
          added.map((a) => normalizeExerciseName(a.exerciseNameSnapshot)),
        );
      }
      if (index >= 0 &&
          [
            ActiveWorkoutEditAction.replace,
            ActiveWorkoutEditAction.remove,
          ].contains(action)) {
        final wasSessionOnly = sessionOnlyNames.remove(
          normalizeExerciseName(exerciseName!),
        );
        if (wasSessionOnly &&
            action == ActiveWorkoutEditAction.replace &&
            scope == ActiveWorkoutEditScope.sessionOnly) {
          sessionOnlyNames.add(
            normalizeExerciseName(
              updatedAssignments[index].exerciseNameSnapshot,
            ),
          );
        }
      }
      if (scope == ActiveWorkoutEditScope.sessionAndProgram &&
          index >= 0 &&
          action == ActiveWorkoutEditAction.targets) {
        sessionOnlyNames.remove(normalizeExerciseName(exerciseName!));
      }
      if (action == ActiveWorkoutEditAction.applyProgram) {
        sessionOnlyNames.clear();
      }
      final updated = current.copyWith(
        templateExerciseAssignmentsSnapshot: updatedAssignments,
        sessionExerciseNames: updatedAssignments
            .where(
              (a) => sessionOnlyNames.contains(
                normalizeExerciseName(a.exerciseNameSnapshot),
              ),
            )
            .map((a) => a.exerciseNameSnapshot)
            .toList(),
        hiddenExerciseNames: hiddenNames,
        exerciseOrder: updatedAssignments
            .map((a) => a.exerciseNameSnapshot)
            .toList(),
        pendingProgramExerciseEdit: journal,
      );
      // The session + intent are durable before touching the day. A second-box
      // failure is explicitly pending, recoverable, and never a false success.
      await sessionBox.put(current.id, updated);
      if (journal == null) return updated;
      try {
        final latestDay = templateBox!.get(day!.id)!;
        if (_encode(latestDay.exerciseAssignments) !=
            (jsonDecode(journal) as Map)['before']) {
          throw const ActiveWorkoutEditException(
            ActiveWorkoutEditFailure.conflict,
          );
        }
        _assertOwner(sessionBox.name);
        await templateBox.put(
          day.id,
          latestDay.copyWith(
            exerciseAssignments: _decode(
              (jsonDecode(journal) as Map)['after'] as String,
            ),
            updatedAt: DateTime.now(),
          ),
        );
        final committed = updated.copyWith(
          clearPendingProgramExerciseEdit: true,
        );
        _assertOwner(sessionBox.name);
        await sessionBox.put(current.id, committed);
        return committed;
      } catch (_) {
        throw const ActiveWorkoutEditException(
          ActiveWorkoutEditFailure.pending,
        );
      }
    }),
  );

  static String _encode(List<WorkoutTemplateExerciseAssignment> assignments) =>
      jsonEncode(assignments.map((a) => a.toJson()).toList());

  void _assertOwner(String boxName) {
    final uid = sessions.currentUserId;
    if (uid == null || boxName != 'workout_sessions_${uid.toLowerCase()}') {
      throw StateError('Account changed.');
    }
  }

  static List<WorkoutTemplateExerciseAssignment> _decode(String value) =>
      (jsonDecode(value) as List)
          .map(
            (item) => WorkoutTemplateExerciseAssignment.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
  static void _sameOwner(String first, String second) {
    String owner(String name) => name.replaceFirst(
      RegExp(r'^(workout_sessions|workout_templates|sets)_'),
      '',
    );
    if (owner(first) != owner(second)) throw StateError('Account changed.');
  }

  static void _validateUnique(List<WorkoutTemplateExerciseAssignment> items) {
    final names = <String>{};
    final ids = <String>{};
    for (final item in items) {
      if (item.exerciseNameSnapshot.trim().isEmpty ||
          item.exerciseId.trim().isEmpty ||
          !names.add(normalizeExerciseName(item.exerciseNameSnapshot)) ||
          !ids.add(item.exerciseId)) {
        throw const ActiveWorkoutEditException(
          ActiveWorkoutEditFailure.duplicate,
        );
      }
    }
  }
}
