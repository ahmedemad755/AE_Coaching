part of 'workout_history_cubit.dart';

abstract class WorkoutHistoryState {
  const WorkoutHistoryState();
}

class WorkoutHistoryInitial extends WorkoutHistoryState {
  const WorkoutHistoryInitial();
}

class WorkoutHistoryLoading extends WorkoutHistoryState {
  const WorkoutHistoryLoading();
}

/// [sessions] is every session for one workoutTemplateId — every
/// status (completed, cancelled, and, in the rare case sync left one
/// mid-flight, inProgress), newest first by [WorkoutSession.date]; see
/// [WorkoutSessionRepository.getSessionsForTemplate]. Never includes a
/// different template's sessions.
class WorkoutHistoryLoaded extends WorkoutHistoryState {
  final List<WorkoutSession> sessions;

  const WorkoutHistoryLoaded({required this.sessions});
}

class WorkoutHistoryError extends WorkoutHistoryState {
  final String message;
  const WorkoutHistoryError(this.message);
}
