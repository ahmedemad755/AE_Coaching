import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';

/// An ESTIMATE of how long a workout day takes, from its plan (never the
/// time a workout actually took; session history is not involved).
class WorkoutDurationEstimate {
  const WorkoutDurationEstimate({
    required this.seconds,
    required this.counted,
    required this.total,
    required this.partial,
  });

  final int seconds;

  /// Activities that contributed / activities in the day.
  final int counted;
  final int total;

  /// Some activity had no usable plan, or a strength exercise had no rest
  /// set: the real time is likely longer ("at least").
  final bool partial;

  /// Whole minutes, rounded up (at least one).
  int get minutes => seconds <= 0 ? 0 : (seconds + 59) ~/ 60;
}

/// Pure and deterministic.
///
/// - Cardio and timed activities: their planned time.
/// - Strength: sets × reps × [secondsPerRep] of work, plus the rest between
///   sets (none after the last set). Reps: the middle of the target range.
///   A missing rest counts as none (and marks the estimate partial); missing
///   sets or reps leave the exercise out (partial).
///
/// Not included (no assumed numbers, by decision): the time between
/// activities (moving, setting up equipment) and any general warm-up that is
/// not planned as an activity. A cardio activity's own warm-up and cool-down
/// (intervals) are part of its plan and are included.
abstract final class WorkoutDurationEstimator {
  /// A controlled repetition (lifting and lowering), on average.
  static const secondsPerRep = 3;

  /// Seconds for one activity, or null when it can't be estimated.
  static int? activitySeconds(WorkoutTemplateExerciseAssignment activity) =>
      switch (activity.type) {
        ActivityType.cardio => _positive(activity.cardio?.plannedSeconds),
        ActivityType.timed => _positive(activity.timed?.plannedSeconds),
        ActivityType.strength => _strengthSeconds(activity),
      };

  static int? _strengthSeconds(WorkoutTemplateExerciseAssignment activity) {
    final sets = activity.workingSets;
    final reps = _reps(activity.targetRepsMin, activity.targetRepsMax);
    if (sets == null || sets <= 0 || reps == null) return null;
    final rest = activity.restSeconds;
    final restBetween = rest == null || rest < 0 ? 0 : rest;
    return sets * reps * secondsPerRep + (sets - 1) * restBetween;
  }

  static int? _reps(int? min, int? max) {
    final low = min != null && min > 0 ? min : null;
    final high = max != null && max > 0 ? max : null;
    if (low != null && high != null) return ((low + high) / 2).round();
    return low ?? high;
  }

  static int? _positive(int? seconds) =>
      seconds != null && seconds > 0 ? seconds : null;

  /// Null when no activity of the day can be estimated.
  static WorkoutDurationEstimate? estimate(
    List<WorkoutTemplateExerciseAssignment> activities,
  ) {
    var seconds = 0;
    var counted = 0;
    var partial = false;
    for (final activity in activities) {
      final value = activitySeconds(activity);
      if (value == null) {
        partial = true;
        continue;
      }
      seconds += value;
      counted++;
      if (activity.type == ActivityType.strength &&
          (activity.workingSets ?? 0) > 1 &&
          activity.restSeconds == null) {
        partial = true;
      }
    }
    if (counted == 0) return null;
    return WorkoutDurationEstimate(
      seconds: seconds,
      counted: counted,
      total: activities.length,
      partial: partial,
    );
  }
}
