import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
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

  const WorkoutCompletionResult({required this.progressSummary, required this.personalRecords});
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

  // Stage 3: see HomeWorkoutOverviewCubit.
  SessionExerciseCubit({
    required this.repository,
    required this.sessionRepository,
  }) : super(const SessionExerciseInitial());

  Future<void> loadForSession(WorkoutSession session) async {
    emit(const SessionExerciseLoading());
    try {
      final box = await repository.getUserBox();
      final rows = await _buildRows(box, session);
      emit(SessionExerciseLoaded(rows: rows, hasReferenceSession: rows.any((r) => r.isReferenceOnly)));
    } catch (error) {
      emit(SessionExerciseError(error.toString()));
    }
  }

  Future<List<SessionExerciseRow>> _buildRows(Box<ExerciseSet> box, WorkoutSession session) async {
    final loggedNames = repository.getExerciseNamesForSession(box, session.id);

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
      for (final name in loggedNames)
        SessionExerciseRow(
          exerciseName: name,
          sets: repository.getSetsForExerciseInSession(box, session.id, name),
          isReferenceOnly: false,
          previousSets: previousSetsFor(name),
        ),
    ];

    if (previous != null) {
      final referenceNames = repository.getExerciseNamesForSession(box, previous.id);
      final loggedSet = loggedNames.toSet();
      for (final name in referenceNames) {
        if (!loggedSet.contains(name)) {
          rows.add(SessionExerciseRow(
            exerciseName: name,
            sets: const [],
            isReferenceOnly: true,
            previousSets: previousSetsFor(name),
          ));
        }
      }
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
    await repository.addSet(
      programId: session.programId,
      workoutTemplateId: session.workoutTemplateId,
      workoutSessionId: session.id,
      exerciseName: exerciseName,
      weight: weight,
      reps: reps,
      notes: notes,
    );
    await loadForSession(session);
  }

  Future<void> deleteSet(WorkoutSession session, ExerciseSet set) async {
    await repository.deleteSet(set);
    await loadForSession(session);
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
  Future<WorkoutCompletionResult> buildCompletionSummary(WorkoutSession finishedSession) async {
    final box = await repository.getUserBox();
    final currentSets = repository.getSetsForSession(box, finishedSession.id);

    final sessionBox = await sessionRepository.getUserBox();
    final previous = sessionRepository.getPreviousCompletedSession(
      sessionBox,
      finishedSession.programId,
      finishedSession.workoutTemplateId,
      excludeSessionId: finishedSession.id,
    );
    final previousSets = previous == null ? const <ExerciseSet>[] : repository.getSetsForSession(box, previous.id);

    final progressSummary = const WorkoutProgressComparisonService().compare(
      currentSession: finishedSession,
      currentSets: currentSets,
      previousSession: previous,
      previousSets: previousSets,
    );

    final historicalSets = box.values.where((s) => s.workoutSessionId != finishedSession.id).toList();
    final personalRecords = const PersonalRecordDetectionService().detect(
      newSets: currentSets,
      historicalSets: historicalSets,
    );

    return WorkoutCompletionResult(progressSummary: progressSummary, personalRecords: personalRecords);
  }
}
