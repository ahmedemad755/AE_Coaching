import 'dart:async';

import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/active_workout_edit_service.dart';
import 'package:ae_coaching/core/errors/exception_message_mapper.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/domain/services/personal_record_detection_service.dart';
import 'package:ae_coaching/features/workout/domain/services/workout_progress_comparison_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';

part 'session_exercise_state.dart';

/// Everything Phase 13's Workout Completion Summary screen needs,
/// computed once at the moment a session finishes. Bundled together
/// because both pieces are derived from the exact same current/
/// previous/historical set data — computing them separately would mean
/// fetching that data twice.
class WorkoutCompletionResult {
  final WorkoutProgressSummary progressSummary;
  final List<PersonalRecordResult> personalRecords;

  const WorkoutCompletionResult({
    required this.progressSummary,
    required this.personalRecords,
  });
}

/// Drives the exercise-logging list on [ActiveWorkoutSessionScreen]
/// (Phase 8: auto-loaded structure from the previous same-template
/// session; Phase 9 will add previous performance values per set).
///
/// Never duplicates the previous session's sets as new rows in the
/// current session — [SessionExerciseRepository.addSet] is the only
/// way a real set is created here, and reference rows are purely
/// display suggestions (see [SessionExerciseRow.isReferenceOnly]).
class SessionExerciseCubit extends Cubit<SessionExerciseState> {
  final SessionExerciseRepository repository;
  final WorkoutSessionRepository sessionRepository;
  final ActiveWorkoutEditService? editService;
  int _loadVersion = 0;
  bool _editing = false;
  bool _recovering = false;
  StreamSubscription<BoxEvent>? _sessionChanges;
  StreamSubscription<BoxEvent>? _setChanges;
  String? _watchedSession;
  Box<WorkoutSession>? _observedSessionBox;

  // Stage 3: see HomeWorkoutOverviewCubit.
  SessionExerciseCubit({
    required this.repository,
    required this.sessionRepository,
    this.editService,
  }) : super(const SessionExerciseInitial());

  Future<void> loadForSession(WorkoutSession session) =>
      _loadForSession(session, showLoading: true);

  Future<void> refreshForSession(WorkoutSession session) =>
      _loadForSession(session, showLoading: false);

  Future<void> _loadForSession(
    WorkoutSession session, {
    required bool showLoading,
  }) async {
    final version = ++_loadVersion;
    if (showLoading) emit(const SessionExerciseLoading());
    try {
      final box = await repository.getUserBox();
      final sessionBox = await sessionRepository.getUserBox();
      if (editService != null &&
          (_watchedSession != '${sessionBox.name}/${session.id}' ||
              _observedSessionBox?.isOpen != true)) {
        await _sessionChanges?.cancel();
        await _setChanges?.cancel();
        _watchedSession = '${sessionBox.name}/${session.id}';
        _observedSessionBox = sessionBox;
        void refresh() {
          if (!_editing && !_recovering && !isClosed) {
            unawaited(refreshForSession(session));
          }
        }

        _sessionChanges = sessionBox
            .watch(key: session.id)
            .listen((_) => refresh());
        _setChanges = box.watch().listen((event) {
          if (event.deleted ||
              (event.value is ExerciseSet &&
                  (event.value as ExerciseSet).workoutSessionId ==
                      session.id)) {
            refresh();
          }
        });
      }
      final persisted = sessionBox.get(session.id);
      if (persisted == null && editService != null) {
        throw const ActiveWorkoutEditException(
          ActiveWorkoutEditFailure.inactive,
        );
      }
      var currentSession = persisted ?? session;
      if (showLoading &&
          currentSession.pendingProgramExerciseEdit != null &&
          editService != null) {
        _recovering = true;
        try {
          currentSession = await editService!.recover(session.id);
        } catch (_) {
          // Keep the durable session visible with an explicit pending banner.
          currentSession = sessionBox.get(session.id) ?? currentSession;
        } finally {
          _recovering = false;
        }
      }
      final rows = await _buildRows(box, currentSession);
      if (isClosed || version != _loadVersion) return;
      emit(
        SessionExerciseLoaded(
          rows: rows,
          hasReferenceSession: rows.any((r) => r.isReferenceOnly),
          session: currentSession,
        ),
      );
    } catch (error) {
      if (isClosed || version != _loadVersion) return;
      emit(SessionExerciseError(mapGenericExceptionToMessage(error)));
    }
  }

  Future<void> editActiveExercises({
    required WorkoutSession session,
    required ActiveWorkoutEditAction action,
    ActiveWorkoutEditScope scope = ActiveWorkoutEditScope.sessionOnly,
    String? exerciseName,
    List<ExerciseLibraryItem> exercises = const [],
    String languageCode = 'en',
    List<String> orderedNames = const [],
    WorkoutTemplateExerciseAssignment? targets,
  }) async {
    if (_editing || editService == null) {
      throw StateError('Exercise editor unavailable or busy.');
    }
    _editing = true;
    try {
      await editService!.edit(
        sessionId: session.id,
        action: action,
        scope: scope,
        exerciseName: exerciseName,
        exercises: exercises,
        languageCode: languageCode,
        orderedNames: orderedNames,
        targets: targets,
      );
    } finally {
      // Read exactly what persisted, including partial-save intent. No optimistic
      // success state and no list-clearing loading state during a mutation.
      _editing = false;
      await refreshForSession(session);
    }
  }

  Future<void> resolvePendingEdit(
    WorkoutSession session, {
    bool keepSessionOnly = false,
  }) async {
    if (_editing || editService == null) {
      throw StateError('Exercise editor unavailable or busy.');
    }
    _editing = true;
    try {
      await editService!.recover(session.id, keepSessionOnly: keepSessionOnly);
    } finally {
      _editing = false;
      await refreshForSession(session);
    }
  }

  @override
  Future<void> close() async {
    await _sessionChanges?.cancel();
    await _setChanges?.cancel();
    return super.close();
  }

  /// Reads persisted sets rather than relying on the currently rendered
  /// rows, which may still be loading when Finish is tapped.
  Future<List<ExerciseSet>> getValidSetsForSession(
    WorkoutSession session,
  ) async {
    final box = await repository.getUserBox();
    return repository
        .getSetsForSession(box, session.id)
        .where(
          (set) =>
              set.programId == session.programId &&
              set.workoutTemplateId == session.workoutTemplateId &&
              set.workoutSessionId == session.id &&
              set.exerciseName.trim().isNotEmpty &&
              set.weight.isFinite &&
              set.weight >= 0 &&
              set.reps > 0,
        )
        .toList();
  }

  Future<List<SessionExerciseRow>> _buildRows(
    Box<ExerciseSet> box,
    WorkoutSession session,
  ) async {
    final loggedNames = repository.getExerciseNamesForSession(box, session.id);
    final assignedExercises = session.templateExerciseAssignmentsSnapshot;
    final hiddenNames = session.hiddenExerciseNames
        .map(normalizeExerciseName)
        .toSet();
    // Legacy layouts may hide logged exercises. Keep their recorded rows
    // visible, without changing any stored set or analytics calculation.
    hiddenNames.removeAll(loggedNames.map(normalizeExerciseName));

    // Previous performance (Phase 9) is scoped to the previous
    // COMPLETED session sharing the SAME programId + workoutTemplateId
    // — the one guard that keeps Push 1's numbers from ever appearing
    // next to Push 2's.
    final sessionBox = await sessionRepository.getUserBox();
    final previous = sessionRepository.getPreviousCompletedSession(
      sessionBox,
      session.programId,
      session.workoutTemplateId,
      excludeSessionId: session.id,
    );

    List<ExerciseSet> previousSetsFor(String name) {
      if (previous == null) return const [];
      return repository.getSetsForExerciseInSession(box, previous.id, name);
    }

    final rows = <SessionExerciseRow>[
      for (final assignment in assignedExercises)
        if (!hiddenNames.contains(
          normalizeExerciseName(assignment.exerciseNameSnapshot),
        ))
          SessionExerciseRow(
            exerciseName: assignment.exerciseNameSnapshot,
            assignmentId: assignment.assignmentId,
            assignment: assignment,
            isSessionOnly: session.sessionExerciseNames.any(
              (name) =>
                  normalizeExerciseName(name) ==
                  normalizeExerciseName(assignment.exerciseNameSnapshot),
            ),
            sets: repository
                .getSetsForSession(box, session.id)
                .where(
                  (set) =>
                      normalizeExerciseName(set.exerciseName) ==
                      normalizeExerciseName(assignment.exerciseNameSnapshot),
                )
                .toList(),
            isReferenceOnly: !loggedNames.any(
              (name) =>
                  normalizeExerciseName(name) ==
                  normalizeExerciseName(assignment.exerciseNameSnapshot),
            ),
            previousSets: previousSetsFor(assignment.exerciseNameSnapshot),
          ),
    ];

    final representedNames = assignedExercises
        .map(
          (assignment) =>
              normalizeExerciseName(assignment.exerciseNameSnapshot),
        )
        .toSet();
    for (final name in loggedNames) {
      if (!hiddenNames.contains(normalizeExerciseName(name)) &&
          representedNames.add(normalizeExerciseName(name))) {
        rows.add(
          SessionExerciseRow(
            exerciseName: name,
            sets: repository.getSetsForExerciseInSession(box, session.id, name),
            isReferenceOnly: false,
            previousSets: previousSetsFor(name),
          ),
        );
      }
    }

    for (final name in session.sessionExerciseNames) {
      if (!hiddenNames.contains(normalizeExerciseName(name)) &&
          representedNames.add(normalizeExerciseName(name))) {
        rows.add(
          SessionExerciseRow(
            exerciseName: name,
            sets: const [],
            isReferenceOnly: true,
            isSessionOnly: true,
            previousSets: previousSetsFor(name),
          ),
        );
      }
    }

    if (previous != null) {
      final referenceNames = repository.getExerciseNamesForSession(
        box,
        previous.id,
      );
      final currentNames = representedNames;
      for (final name in referenceNames) {
        if (!hiddenNames.contains(normalizeExerciseName(name)) &&
            currentNames.add(normalizeExerciseName(name))) {
          rows.add(
            SessionExerciseRow(
              exerciseName: name,
              sets: const [],
              isReferenceOnly: true,
              previousSets: previousSetsFor(name),
            ),
          );
        }
      }
    }

    if (session.exerciseOrder.isNotEmpty) {
      final naturalOrder = {
        for (var i = 0; i < rows.length; i++)
          normalizeExerciseName(rows[i].exerciseName): i,
      };
      final order = {
        for (var index = 0; index < session.exerciseOrder.length; index++)
          normalizeExerciseName(session.exerciseOrder[index]): index,
      };
      rows.sort((a, b) {
        final aIndex = order[normalizeExerciseName(a.exerciseName)];
        final bIndex = order[normalizeExerciseName(b.exerciseName)];
        if (aIndex == null && bIndex == null) {
          return naturalOrder[normalizeExerciseName(a.exerciseName)]!.compareTo(
            naturalOrder[normalizeExerciseName(b.exerciseName)]!,
          );
        }
        if (aIndex == null) return 1;
        if (bIndex == null) return -1;
        return aIndex.compareTo(bIndex);
      });
    }
    return rows;
  }

  Future<void> logSet({
    required WorkoutSession session,
    required String exerciseName,
    required double weight,
    required int reps,
    String? notes,
  }) async {
    await sessionRepository.coordinateExerciseEdit(() async {
      final current = await _currentSession(session);
      if (current.pendingProgramExerciseEdit != null) {
        throw const ActiveWorkoutEditException(
          ActiveWorkoutEditFailure.pending,
        );
      }
      await repository.addSet(
        programId: session.programId,
        workoutTemplateId: session.workoutTemplateId,
        workoutSessionId: session.id,
        exerciseName: exerciseName,
        weight: weight,
        reps: reps,
        notes: notes,
      );
    });
    await refreshForSession(session);
  }

  Future<void> deleteSet(WorkoutSession session, ExerciseSet set) async {
    await repository.deleteSet(set);
    await refreshForSession(session);
  }

  Future<void> addSessionExercise(WorkoutSession session, String name) async {
    await sessionRepository.addSessionExerciseName(
      sessionId: session.id,
      exerciseName: name,
    );
    await refreshForSession(
      (await sessionRepository.getUserBox()).get(session.id) ?? session,
    );
  }

  Future<void> removeSessionExercise(
    WorkoutSession session,
    String exerciseName,
  ) async {
    await _protectLoggedExercise(session, exerciseName);
    final current = await _currentSession(session);
    final hidden = [...current.hiddenExerciseNames];
    if (!hidden.any(
      (name) =>
          normalizeExerciseName(name) == normalizeExerciseName(exerciseName),
    )) {
      hidden.add(exerciseName);
    }
    final order = state is SessionExerciseLoaded
        ? (state as SessionExerciseLoaded).rows
              .where(
                (row) =>
                    normalizeExerciseName(row.exerciseName) !=
                    normalizeExerciseName(exerciseName),
              )
              .map((row) => row.exerciseName)
              .toList()
        : current.exerciseOrder
              .where(
                (name) =>
                    normalizeExerciseName(name) !=
                    normalizeExerciseName(exerciseName),
              )
              .toList();
    await sessionRepository.updateActiveExerciseLayout(
      sessionId: current.id,
      sessionExerciseNames: current.sessionExerciseNames,
      hiddenExerciseNames: hidden,
      exerciseOrder: order,
    );
    await refreshForSession(current);
  }

  Future<void> replaceSessionExercise({
    required WorkoutSession session,
    required String oldName,
    required String newName,
  }) async {
    await _protectLoggedExercise(session, oldName);
    final current = await _currentSession(session);
    final hidden = [...current.hiddenExerciseNames];
    if (!hidden.any(
      (name) => normalizeExerciseName(name) == normalizeExerciseName(oldName),
    )) {
      hidden.add(oldName);
    }
    final names = [...current.sessionExerciseNames];
    if (!names.any(
      (name) => normalizeExerciseName(name) == normalizeExerciseName(newName),
    )) {
      names.add(newName);
    }
    final order = state is SessionExerciseLoaded
        ? (state as SessionExerciseLoaded).rows.map((row) {
            return normalizeExerciseName(row.exerciseName) ==
                    normalizeExerciseName(oldName)
                ? newName
                : row.exerciseName;
          }).toList()
        : [...current.exerciseOrder, newName];
    await sessionRepository.updateActiveExerciseLayout(
      sessionId: current.id,
      sessionExerciseNames: names,
      hiddenExerciseNames: hidden,
      exerciseOrder: order,
    );
    await refreshForSession(current);
  }

  Future<void> reorderSessionExercises(
    WorkoutSession session,
    List<String> exerciseNames,
  ) async {
    final current = await _currentSession(session);
    await sessionRepository.updateActiveExerciseLayout(
      sessionId: current.id,
      sessionExerciseNames: current.sessionExerciseNames,
      hiddenExerciseNames: current.hiddenExerciseNames,
      exerciseOrder: exerciseNames,
    );
    await refreshForSession(current);
  }

  Future<WorkoutSession> _currentSession(WorkoutSession session) async {
    final box = await sessionRepository.getUserBox();
    final current = box.get(session.id);
    if (current == null || !current.isInProgress) {
      throw StateError('Workout session is no longer active.');
    }
    return current;
  }

  Future<void> _protectLoggedExercise(
    WorkoutSession session,
    String name,
  ) async {
    final box = await repository.getUserBox();
    if (repository
        .getSetsForSession(box, session.id)
        .any(
          (set) =>
              normalizeExerciseName(set.exerciseName) ==
              normalizeExerciseName(name),
        )) {
      throw const ActiveWorkoutEditException(
        ActiveWorkoutEditFailure.loggedSets,
      );
    }
  }

  /// Builds the Phase 11 progress comparison + Phase 12 PR list for a
  /// session that has just been marked completed (call this AFTER
  /// [WorkoutSessionCubit.finishWorkout] succeeds, passing the
  /// completed session it returns — not the pre-completion one — so
  /// [WorkoutProgressSummary.currentTotalVolume] and the finished
  /// record's own `completedAt` line up).
  ///
  /// PR detection deliberately looks at the user's ENTIRE set history
  /// except this session's own sets — see
  /// [PersonalRecordDetectionService]'s class docs for why that is
  /// global-across-programs by design, unlike the strictly
  /// same-program/same-template progress comparison right above it.
  Future<WorkoutCompletionResult> buildCompletionSummary(
    WorkoutSession finishedSession,
  ) async {
    final box = await repository.getUserBox();
    final currentSets = repository.getSetsForSession(box, finishedSession.id);

    final sessionBox = await sessionRepository.getUserBox();
    final previous = sessionRepository.getPreviousCompletedSession(
      sessionBox,
      finishedSession.programId,
      finishedSession.workoutTemplateId,
      excludeSessionId: finishedSession.id,
    );
    final previousSets = previous == null
        ? const <ExerciseSet>[]
        : repository.getSetsForSession(box, previous.id);

    final progressSummary = const WorkoutProgressComparisonService().compare(
      currentSession: finishedSession,
      currentSets: currentSets,
      previousSession: previous,
      previousSets: previousSets,
    );

    final historicalSets = box.values
        .where((s) => s.workoutSessionId != finishedSession.id)
        .toList();
    final personalRecords = const PersonalRecordDetectionService().detect(
      newSets: currentSets,
      historicalSets: historicalSets,
    );

    return WorkoutCompletionResult(
      progressSummary: progressSummary,
      personalRecords: personalRecords,
    );
  }
}
