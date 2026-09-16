import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/domain/services/week_boundary_util.dart';

/// One workout day's real, counted activity this week — nothing here
/// is an estimate or a percentage of some assumed target; there is no
/// "how many times a week is this day supposed to happen" field
/// anywhere in the data model, so this deliberately never computes or
/// displays anything shaped like "80% adherence". It shows what
/// actually happened, and nothing else.
class WeeklyTemplateOverview {
  final String workoutTemplateId;
  final String workoutTemplateName;

  /// Count of COMPLETED sessions for this template whose date falls
  /// within the current week (see [ProgramWeeklyOverview.weekStart]/
  /// [weekEnd]). Cancelled and in-progress sessions are never counted.
  final int sessionsThisWeek;

  /// The most recent completed session for this template, of any
  /// week — purely informational ("last done: ..."), not part of the
  /// weekly count.
  final DateTime? lastCompletedAt;

  const WeeklyTemplateOverview({
    required this.workoutTemplateId,
    required this.workoutTemplateName,
    required this.sessionsThisWeek,
    required this.lastCompletedAt,
  });
}

/// This week's real completion counts for one program, per workout
/// day. [weekStart] is always a Monday 00:00 and [weekEnd] the
/// following Monday 00:00 (exclusive) — a fixed, honest calendar
/// window, not a rolling "last 7 days" that would silently shift
/// depending on when the user happens to open the app.
class ProgramWeeklyOverview {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalSessionsThisWeek;
  final List<WeeklyTemplateOverview> templates;

  const ProgramWeeklyOverview({
    required this.weekStart,
    required this.weekEnd,
    required this.totalSessionsThisWeek,
    required this.templates,
  });
}

/// Builds the Phase 16 Program Overview — pure aggregation, no
/// Hive/Firestore access, same shape as the other domain services in
/// this feature. [now] is passed in (rather than read internally via
/// `DateTime.now()`) purely so the week boundary is deterministic and
/// testable; callers pass the real current time in production.
///
/// Every count here is scoped to one `workoutTemplateId` via
/// [completedSessionsByTemplate] — a caller mistake mixing two
/// templates' sessions under the same key is the only way this could
/// misattribute a count, same defense boundary as
/// [ProgramAnalyticsService].
class ProgramWeeklyOverviewService {
  const ProgramWeeklyOverviewService();

  ProgramWeeklyOverview build({
    required DateTime now,
    required List<WorkoutTemplate> templates,
    required Map<String, List<WorkoutSession>> completedSessionsByTemplate,
  }) {
    final weekStart = startOfWeek(now);
    final weekEnd = weekStart.add(const Duration(days: 7));

    var total = 0;
    final templateOverviews = <WeeklyTemplateOverview>[];

    for (final template in templates) {
      final sessions = completedSessionsByTemplate[template.id] ?? const <WorkoutSession>[];

      var sessionsThisWeek = 0;
      DateTime? lastCompletedAt;

      for (final session in sessions) {
        final at = session.completedAt ?? session.date;
        if (!at.isBefore(weekStart) && at.isBefore(weekEnd)) {
          sessionsThisWeek++;
        }
        if (lastCompletedAt == null || at.isAfter(lastCompletedAt)) {
          lastCompletedAt = at;
        }
      }

      total += sessionsThisWeek;
      templateOverviews.add(WeeklyTemplateOverview(
        workoutTemplateId: template.id,
        workoutTemplateName: template.name,
        sessionsThisWeek: sessionsThisWeek,
        lastCompletedAt: lastCompletedAt,
      ));
    }

    return ProgramWeeklyOverview(
      weekStart: weekStart,
      weekEnd: weekEnd,
      totalSessionsThisWeek: total,
      templates: templateOverviews,
    );
  }
}
