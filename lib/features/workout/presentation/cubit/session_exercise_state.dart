part of 'session_exercise_cubit.dart';

/// One row shown in the active-workout exercise list.
///
/// [isReferenceOnly] means this name came from the previous completed
/// session for the same program+template (Phase 8's "auto-loaded
/// structure") and has NOT been logged yet in the current session —
/// it is a suggestion, not a real set. It disappears from that
/// category the moment the user logs a real set for it, at which
/// point it moves into [sets] like any other exercise.
class SessionExerciseRow {
  final String exerciseName;
  final List<ExerciseSet> sets;
  final bool isReferenceOnly;

  /// Sets logged for this exact exercise name in the previous
  /// COMPLETED session sharing the same programId + workoutTemplateId
  /// (Phase 9) — empty when there is no previous session, or the
  /// exercise wasn't logged in it. Purely informational: never copied
  /// into [sets] automatically, and never sourced from a different
  /// template's session (so Push 1 never shows Push 2's numbers).
  final List<ExerciseSet> previousSets;

  const SessionExerciseRow({
    required this.exerciseName,
    required this.sets,
    required this.isReferenceOnly,
    this.previousSets = const [],
  });
}

abstract class SessionExerciseState {
  const SessionExerciseState();
}

class SessionExerciseInitial extends SessionExerciseState {
  const SessionExerciseInitial();
}

class SessionExerciseLoading extends SessionExerciseState {
  const SessionExerciseLoading();
}

/// [rows] preserves this order: exercises already logged in the
/// current session (in first-logged order) first, then any
/// reference-only suggestions from the previous session that have not
/// been logged yet, appended at the end.
class SessionExerciseLoaded extends SessionExerciseState {
  final List<SessionExerciseRow> rows;
  final bool hasReferenceSession;

  const SessionExerciseLoaded({required this.rows, required this.hasReferenceSession});

  /// Sum of weight × reps across every REAL set logged in the current
  /// session (reference-only rows never contribute — they have no
  /// sets). This is what Phase 10's Finish Workout flow passes as
  /// [WorkoutSession.totalVolume]; nothing from a previous session is
  /// ever included.
  double get totalVolume {
    return rows.expand((r) => r.sets).fold(0.0, (sum, s) => sum + s.weight * s.reps);
  }

  SessionExerciseLoaded copyWith({List<SessionExerciseRow>? rows}) {
    return SessionExerciseLoaded(
      rows: rows ?? this.rows,
      hasReferenceSession: hasReferenceSession,
    );
  }
}

class SessionExerciseError extends SessionExerciseState {
  final String message;
  const SessionExerciseError(this.message);
}
