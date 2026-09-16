import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/domain/services/program_weekly_overview_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutTemplate _template(String id, String name) {
  return WorkoutTemplate(id: id, programId: 'program_A', name: name, createdAt: DateTime(2025, 1, 1));
}

WorkoutSession _completedSession(String id, String templateId, DateTime completedAt) {
  return WorkoutSession(
    id: id,
    programId: 'program_A',
    workoutTemplateId: templateId,
    workoutNameSnapshot: 'Day',
    date: completedAt,
    startedAt: completedAt.subtract(const Duration(hours: 1)),
    completedAt: completedAt,
    status: WorkoutSessionStatus.completed.value,
    totalVolume: 0,
  );
}

void main() {
  const service = ProgramWeeklyOverviewService();

  // A fixed Wednesday, so the week window is deterministic in tests:
  // Monday 2025-06-02 00:00 through Monday 2025-06-09 00:00 (exclusive).
  final wednesday = DateTime(2025, 6, 4, 15, 0);

  test('week boundaries are Monday 00:00 through the following Monday 00:00, regardless of time of day', () {
    final overview = service.build(now: wednesday, templates: const [], completedSessionsByTemplate: const {});
    expect(overview.weekStart, equals(DateTime(2025, 6, 2)));
    expect(overview.weekEnd, equals(DateTime(2025, 6, 9)));
  });

  test('a session completed this week counts; one from last week or next week does not', () {
    final template = _template('t1', 'Push 1');
    final overview = service.build(
      now: wednesday,
      templates: [template],
      completedSessionsByTemplate: {
        't1': [
          _completedSession('s1', 't1', DateTime(2025, 6, 3)), // this week (Tuesday)
          _completedSession('s2', 't1', DateTime(2025, 5, 30)), // last week (Friday)
          _completedSession('s3', 't1', DateTime(2025, 6, 9)), // next week (boundary is exclusive)
        ],
      },
    );

    expect(overview.templates.single.sessionsThisWeek, equals(1));
    expect(overview.totalSessionsThisWeek, equals(1));
  });

  test('the week start itself (Monday 00:00) counts as this week', () {
    final template = _template('t1', 'Push 1');
    final overview = service.build(
      now: wednesday,
      templates: [template],
      completedSessionsByTemplate: {
        't1': [_completedSession('s1', 't1', DateTime(2025, 6, 2))], // exactly Monday 00:00
      },
    );

    expect(overview.templates.single.sessionsThisWeek, equals(1));
  });

  test('totalSessionsThisWeek sums across every template, each scoped to its own id', () {
    final push1 = _template('t1', 'Push 1');
    final push2 = _template('t2', 'Push 2');

    final overview = service.build(
      now: wednesday,
      templates: [push1, push2],
      completedSessionsByTemplate: {
        't1': [_completedSession('s1', 't1', DateTime(2025, 6, 3))],
        't2': [
          _completedSession('s2', 't2', DateTime(2025, 6, 3)),
          _completedSession('s3', 't2', DateTime(2025, 6, 4)),
        ],
      },
    );

    expect(overview.templates.firstWhere((t) => t.workoutTemplateId == 't1').sessionsThisWeek, equals(1));
    expect(overview.templates.firstWhere((t) => t.workoutTemplateId == 't2').sessionsThisWeek, equals(2));
    expect(overview.totalSessionsThisWeek, equals(3));
  });

  test('lastCompletedAt is the most recent completed session ever, independent of the weekly count', () {
    final template = _template('t1', 'Push 1');
    final overview = service.build(
      now: wednesday,
      templates: [template],
      completedSessionsByTemplate: {
        't1': [
          _completedSession('s1', 't1', DateTime(2025, 5, 1)), // long before this week
        ],
      },
    );

    expect(overview.templates.single.sessionsThisWeek, equals(0));
    expect(overview.templates.single.lastCompletedAt, equals(DateTime(2025, 5, 1)));
  });

  test('a template with no completed sessions at all reports zero and a null lastCompletedAt', () {
    final template = _template('t1', 'Push 1');
    final overview = service.build(
      now: wednesday,
      templates: [template],
      completedSessionsByTemplate: const {},
    );

    expect(overview.templates.single.sessionsThisWeek, equals(0));
    expect(overview.templates.single.lastCompletedAt, isNull);
  });
}
