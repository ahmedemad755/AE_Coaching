import 'package:ae_coaching/features/workout/data/models/workout_session.dart';

/// Thrown by `startWorkoutSession` when an inProgress session already
/// exists. Carries the existing session so a future Cubit/UI can offer
/// "resume it" instead of just failing silently or creating a second
/// one.
class ActiveWorkoutSessionExistsException implements Exception {
  final WorkoutSession existingSession;

  const ActiveWorkoutSessionExistsException(this.existingSession);

  @override
  String toString() =>
      'An active workout session already exists (id: ${existingSession.id}, '
      'template: ${existingSession.workoutTemplateId}).';
}

/// Thrown by `completeWorkoutSession` / `cancelWorkoutSession` when the
/// target session isn't in the state that operation requires (e.g.
/// trying to complete a session that was already cancelled).
class InvalidWorkoutSessionStateException implements Exception {
  final String sessionId;
  final WorkoutSessionStatus actualStatus;
  final String reason;

  const InvalidWorkoutSessionStateException({
    required this.sessionId,
    required this.actualStatus,
    required this.reason,
  });

  @override
  String toString() => reason;
}
