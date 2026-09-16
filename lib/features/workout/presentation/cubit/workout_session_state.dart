part of 'workout_session_cubit.dart';

enum WorkoutSessionOperation { load, start, cancel, finish }

abstract class WorkoutSessionState {
  const WorkoutSessionState();
}

class WorkoutSessionInitial extends WorkoutSessionState {
  const WorkoutSessionInitial();
}

class WorkoutSessionLoading extends WorkoutSessionState {
  final WorkoutSessionOperation operation;
  const WorkoutSessionLoading({required this.operation});
}

/// An inProgress session exists right now — drives both the "Resume
/// Workout" banner and the active session screen itself.
class WorkoutSessionActive extends WorkoutSessionState {
  final WorkoutSession session;
  const WorkoutSessionActive({required this.session});
}

/// No active session — starting a new one is safe.
class WorkoutSessionNone extends WorkoutSessionState {
  const WorkoutSessionNone();
}

/// Emitted when `startWorkout` was attempted but an active session
/// already existed — never silently created a second one. Carries the
/// existing session so the UI can offer "Resume Current Workout".
class WorkoutSessionConflict extends WorkoutSessionState {
  final WorkoutSession existingSession;
  const WorkoutSessionConflict({required this.existingSession});
}

class WorkoutSessionError extends WorkoutSessionState {
  final WorkoutSessionOperation operation;
  final String message;
  const WorkoutSessionError({required this.operation, required this.message});
}
