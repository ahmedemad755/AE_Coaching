import 'package:ae_coaching/features/profile/domain/my_progress_summary_service.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';

/// The completed workouts of one calendar month.
class WorkoutHistoryMonth {
  const WorkoutHistoryMonth({required this.month, required this.sessions});

  /// The first day of the month (local time).
  final DateTime month;

  /// Newest first.
  final List<WorkoutSession> sessions;
}

/// Groups completed workouts by the month they were completed in, newest
/// month first and newest workout first within a month. With [programId],
/// only that program's workouts are kept.
List<WorkoutHistoryMonth> groupWorkoutHistoryByMonth(
  Iterable<WorkoutSession> sessions, {
  String? programId,
}) {
  final byMonth = <DateTime, List<WorkoutSession>>{};
  for (final session in sessions) {
    if (programId != null && session.programId != programId) continue;
    final at = MyProgressSummaryService.completedAt(session);
    byMonth.putIfAbsent(DateTime(at.year, at.month), () => []).add(session);
  }
  final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final month in months)
      WorkoutHistoryMonth(
        month: month,
        sessions: byMonth[month]!
          ..sort(
            (a, b) => MyProgressSummaryService.completedAt(
              b,
            ).compareTo(MyProgressSummaryService.completedAt(a)),
          ),
      ),
  ];
}
