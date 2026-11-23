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

/// Completed workouts on one local calendar day.
class DailyActivityPoint {
  const DailyActivityPoint({required this.day, required this.completedCount});

  /// Local midnight of the day.
  final DateTime day;
  final int completedCount;
}

class MyProgressSummary {
  MyProgressSummary({
    required this.completedWorkouts,
    required this.completedThisWeek,
    required this.completedThisMonth,
    required List<WeeklyActivityPoint> weeklyActivity,
    List<DailyActivityPoint> dailyActivity = const [],
    List<WorkoutSession> completedSessions = const [],
  }) : weeklyActivity = List.unmodifiable(weeklyActivity),
       dailyActivity = List.unmodifiable(dailyActivity),
       completedSessions = List.unmodifiable(completedSessions);

  final int completedWorkouts;
  final int completedThisWeek;
  final int completedThisMonth;

  /// The last [MyProgressSummaryService.displayedWeeks] Monday-based weeks,
  /// oldest first.
  final List<WeeklyActivityPoint> weeklyActivity;

  /// The last [MyProgressSummaryService.displayedDays] calendar days ending
  /// today, oldest first.
  final List<DailyActivityPoint> dailyActivity;

  /// Every completed workout, newest first (by completion time).
  final List<WorkoutSession> completedSessions;
}

/// Small account-wide activity summary. Detailed exercise and program metrics
/// remain owned by ProgramAnalyticsService and global PR detection.
class MyProgressSummaryService {
  const MyProgressSummaryService();

  static const int displayedWeeks = 6;
  static const int displayedDays = 7;

  /// When a workout counts: its completion time, or its date for older
  /// sessions saved without one.
  static DateTime completedAt(WorkoutSession session) =>
      session.completedAt ?? session.date;

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
    }).toList()..sort((a, b) => completedAt(b).compareTo(completedAt(a)));

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

    // Calendar days (not 24 h steps), so DST changes never shift a day.
    final dailyActivity = <DailyActivityPoint>[
      for (var index = displayedDays - 1; index >= 0; index--)
        _dailyPoint(completed, DateTime(now.year, now.month, now.day - index)),
    ];

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
      dailyActivity: dailyActivity,
      completedSessions: completed,
    );
  }

  DailyActivityPoint _dailyPoint(List<WorkoutSession> completed, DateTime day) {
    final next = DateTime(day.year, day.month, day.day + 1);
    final count = completed.where((session) {
      final at = completedAt(session);
      return !at.isBefore(day) && at.isBefore(next);
    }).length;
    return DailyActivityPoint(day: day, completedCount: count);
  }
}
