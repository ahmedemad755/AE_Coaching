import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/domain/services/week_boundary_util.dart';

/// Real, honest consistency stats for one program — aggregated across
/// EVERY workout day in it (unlike Phase 15/16, which are scoped to
/// one `workoutTemplateId` at a time). Consistency is deliberately a
/// whole-program question — "am I showing up" — not a per-day one.
///
/// Nothing here is a percentage of some assumed target: there is no
/// "sessions per week goal" anywhere in the data model, and computing
/// one against a made-up target is exactly the "fake adherence number"
/// this app avoids (see [ProgramWeeklyOverviewService]'s docs for the
/// same rule at the per-day level). Every field here is either a plain
/// count, a real calendar streak, or a real historical average — all
/// verifiable directly against the session history, never against an
/// invented expectation.
class ProgramConsistencySummary {
  final int totalCompletedSessions;

  /// Date of the earliest / most recent completed session, or `null`
  /// if there are none yet.
  final DateTime? firstSessionDate;
  final DateTime? lastSessionDate;

  /// How many consecutive weeks — counting backward from the current
  /// week, inclusive — have had at least one completed session. Zero
  /// if the current week has none yet, regardless of past history.
  final int currentWeekStreak;

  /// The longest such run of consecutive weeks anywhere in this
  /// program's history (always >= [currentWeekStreak]).
  final int longestWeekStreak;

  /// Total completed sessions divided by the number of calendar weeks
  /// (Monday-based, see [startOfWeek]) from the first completed
  /// session's week through the current week, inclusive. Zero when
  /// there are no completed sessions.
  final double averageSessionsPerWeek;

  /// Days since [lastSessionDate], or `null` if there are no completed
  /// sessions yet.
  final int? daysSinceLastSession;

  const ProgramConsistencySummary({
    required this.totalCompletedSessions,
    required this.firstSessionDate,
    required this.lastSessionDate,
    required this.currentWeekStreak,
    required this.longestWeekStreak,
    required this.averageSessionsPerWeek,
    required this.daysSinceLastSession,
  });

  static const empty = ProgramConsistencySummary(
    totalCompletedSessions: 0,
    firstSessionDate: null,
    lastSessionDate: null,
    currentWeekStreak: 0,
    longestWeekStreak: 0,
    averageSessionsPerWeek: 0,
    daysSinceLastSession: null,
  );
}

/// Builds [ProgramConsistencySummary] from already-fetched completed
/// sessions — pure, no storage access, same shape as every other
/// domain service in this feature.
class ProgramConsistencyService {
  const ProgramConsistencyService();

  ProgramConsistencySummary build({
    required DateTime now,
    required List<WorkoutSession> completedSessions,
  }) {
    if (completedSessions.isEmpty) return ProgramConsistencySummary.empty;

    final dates = completedSessions.map((s) => s.completedAt ?? s.date).toList()..sort();
    final first = dates.first;
    final last = dates.last;

    final weeksWithSession = <DateTime>{for (final d in dates) startOfWeek(d)};

    var currentStreak = 0;
    var cursor = startOfWeek(now);
    while (weeksWithSession.contains(cursor)) {
      currentStreak++;
      cursor = cursor.subtract(const Duration(days: 7));
    }

    final sortedWeeks = weeksWithSession.toList()..sort();
    var longestStreak = 0;
    var running = 0;
    DateTime? previousWeek;
    for (final week in sortedWeeks) {
      running = (previousWeek != null && week.difference(previousWeek).inDays == 7) ? running + 1 : 1;
      if (running > longestStreak) longestStreak = running;
      previousWeek = week;
    }

    final weeksSpan = (startOfWeek(now).difference(startOfWeek(first)).inDays / 7).floor() + 1;
    final averagePerWeek = completedSessions.length / weeksSpan;

    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(last.year, last.month, last.day);
    final daysSinceLast = today.difference(lastDay).inDays;

    return ProgramConsistencySummary(
      totalCompletedSessions: completedSessions.length,
      firstSessionDate: first,
      lastSessionDate: last,
      currentWeekStreak: currentStreak,
      longestWeekStreak: longestStreak,
      averageSessionsPerWeek: averagePerWeek,
      daysSinceLastSession: daysSinceLast,
    );
  }
}
