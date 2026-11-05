import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/domain/services/week_boundary_util.dart';

class WeeklyActivityPoint {
  const WeeklyActivityPoint({
    required this.weekStart,
    required this.completedCount,
  });

  final DateTime weekStart;
  final int completedCount;
}

class MyProgressSummary {
  MyProgressSummary({
    required this.completedWorkouts,
    required this.completedThisWeek,
    required this.completedThisMonth,
    required List<WeeklyActivityPoint> weeklyActivity,
    List<WorkoutSession> completedSessions = const [],
  }) : weeklyActivity = List.unmodifiable(weeklyActivity),
       completedSessions = List.unmodifiable(completedSessions);

  final int completedWorkouts;
  final int completedThisWeek;
  final int completedThisMonth;
  final List<WeeklyActivityPoint> weeklyActivity;
  final List<WorkoutSession> completedSessions;
}

/// Small account-wide activity summary. Detailed exercise and program metrics
/// remain owned by ProgramAnalyticsService and global PR detection.
class MyProgressSummaryService {
  const MyProgressSummaryService();

  static const int displayedWeeks = 6;

  MyProgressSummary summarize({
    required List<WorkoutSession> sessions,
    required List<ExerciseSet> sets,
    required DateTime now,
  }) {
    final completed = sessions.where((session) {
      if (!session.isCompleted) return false;
      return sets.any(
        (set) =>
            set.workoutSessionId == session.id &&
            set.programId == session.programId &&
            set.workoutTemplateId == session.workoutTemplateId &&
            set.weight.isFinite &&
            set.weight >= 0 &&
            set.reps > 0,
      );
    }).toList();
    DateTime completedAt(WorkoutSession session) =>
        session.completedAt ?? session.date;

    final currentWeek = startOfWeek(now);
    final nextWeek = currentWeek.add(const Duration(days: 7));
    final thisMonth = DateTime(now.year, now.month);
    final weeklyActivity = <WeeklyActivityPoint>[];

    for (var index = displayedWeeks - 1; index >= 0; index--) {
      final start = currentWeek.subtract(Duration(days: index * 7));
      final end = start.add(const Duration(days: 7));
      final count = completed.where((session) {
        final at = completedAt(session);
        return !at.isBefore(start) && at.isBefore(end);
      }).length;
      weeklyActivity.add(
        WeeklyActivityPoint(weekStart: start, completedCount: count),
      );
    }

    return MyProgressSummary(
      completedWorkouts: completed.length,
      completedThisWeek: completed.where((session) {
        final at = completedAt(session);
        return !at.isBefore(currentWeek) && at.isBefore(nextWeek);
      }).length,
      completedThisMonth: completed.where((session) {
        final at = completedAt(session);
        return !at.isBefore(thisMonth) &&
            at.month == now.month &&
            at.year == now.year;
      }).length,
      weeklyActivity: weeklyActivity,
      completedSessions: completed,
    );
  }
}
