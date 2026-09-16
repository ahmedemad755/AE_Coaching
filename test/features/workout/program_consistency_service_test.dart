import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/domain/services/program_consistency_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _completedSession(String id, DateTime completedAt) {
  return WorkoutSession(
    id: id,
    programId: 'program_A',
    workoutTemplateId: 'template_A',
    workoutNameSnapshot: 'Day',
    date: completedAt,
    startedAt: completedAt.subtract(const Duration(hours: 1)),
    completedAt: completedAt,
    status: WorkoutSessionStatus.completed.value,
    totalVolume: 0,
  );
}

void main() {
  const service = ProgramConsistencyService();

  // A fixed Wednesday: week is Monday 2025-06-02 through Sunday 2025-06-08.
  final wednesday = DateTime(2025, 6, 4, 15, 0);

  test('no completed sessions produces the empty summary', () {
    final summary = service.build(now: wednesday, completedSessions: const []);
    expect(summary.totalCompletedSessions, equals(0));
    expect(summary.firstSessionDate, isNull);
    expect(summary.lastSessionDate, isNull);
    expect(summary.currentWeekStreak, equals(0));
    expect(summary.longestWeekStreak, equals(0));
    expect(summary.averageSessionsPerWeek, equals(0));
    expect(summary.daysSinceLastSession, isNull);
  });

  test('a session logged this week gives a currentWeekStreak of 1', () {
    final summary = service.build(
      now: wednesday,
      completedSessions: [_completedSession('s1', DateTime(2025, 6, 3))],
    );
    expect(summary.currentWeekStreak, equals(1));
    expect(summary.longestWeekStreak, equals(1));
  });

  test('no session yet this week gives a currentWeekStreak of 0, even with recent history', () {
    final summary = service.build(
      now: wednesday,
      completedSessions: [_completedSession('s1', DateTime(2025, 5, 26))], // last week
    );
    expect(summary.currentWeekStreak, equals(0));
  });

  test('three consecutive weeks with a session gives currentWeekStreak == longestWeekStreak == 3', () {
    final summary = service.build(
      now: wednesday,
      completedSessions: [
        _completedSession('s1', DateTime(2025, 6, 3)), // this week
        _completedSession('s2', DateTime(2025, 5, 27)), // last week
        _completedSession('s3', DateTime(2025, 5, 20)), // two weeks ago
      ],
    );
    expect(summary.currentWeekStreak, equals(3));
    expect(summary.longestWeekStreak, equals(3));
  });

  test('a gap week breaks the current streak but longestWeekStreak still reflects the earlier run', () {
    final summary = service.build(
      now: wednesday,
      completedSessions: [
        _completedSession('s1', DateTime(2025, 6, 3)), // this week
        // gap: no session the week of 2025-05-26
        _completedSession('s2', DateTime(2025, 5, 20)), // two weeks ago
        _completedSession('s3', DateTime(2025, 5, 13)), // three weeks ago
      ],
    );
    expect(summary.currentWeekStreak, equals(1)); // only this week counts, gap breaks the chain
    expect(summary.longestWeekStreak, equals(2)); // the two-week run before the gap
  });

  test('multiple sessions in the same week count once toward that week\'s streak', () {
    final summary = service.build(
      now: wednesday,
      completedSessions: [
        _completedSession('s1', DateTime(2025, 6, 2)),
        _completedSession('s2', DateTime(2025, 6, 4)),
        _completedSession('s3', DateTime(2025, 6, 6)),
      ],
    );
    expect(summary.totalCompletedSessions, equals(3));
    expect(summary.currentWeekStreak, equals(1));
  });

  test('averageSessionsPerWeek divides total sessions by weeks since the first one, inclusive', () {
    final summary = service.build(
      now: wednesday, // week of 2025-06-02
      completedSessions: [
        _completedSession('s1', DateTime(2025, 5, 20)), // week of 2025-05-19 -> 3 weeks span total
        _completedSession('s2', DateTime(2025, 6, 3)),
      ],
    );
    expect(summary.averageSessionsPerWeek, closeTo(2 / 3, 0.001));
  });

  test('a single session gives an average of exactly 1 for its own week', () {
    final summary = service.build(
      now: wednesday,
      completedSessions: [_completedSession('s1', DateTime(2025, 6, 3))],
    );
    expect(summary.averageSessionsPerWeek, equals(1));
  });

  test('daysSinceLastSession is computed from calendar dates, ignoring time of day', () {
    final summary = service.build(
      now: wednesday, // 2025-06-04 15:00
      completedSessions: [_completedSession('s1', DateTime(2025, 6, 1, 23, 59))], // 3 days earlier
    );
    expect(summary.daysSinceLastSession, equals(3));
  });

  test('first/lastSessionDate correctly identify earliest and most recent regardless of input order', () {
    final summary = service.build(
      now: wednesday,
      completedSessions: [
        _completedSession('s2', DateTime(2025, 6, 3)),
        _completedSession('s1', DateTime(2025, 5, 20)),
      ],
    );
    expect(summary.firstSessionDate, equals(DateTime(2025, 5, 20)));
    expect(summary.lastSessionDate, equals(DateTime(2025, 6, 3)));
  });
}
