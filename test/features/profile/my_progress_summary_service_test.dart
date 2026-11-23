import 'package:ae_coaching/features/profile/domain/my_progress_summary_service.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  required String id,
  required DateTime completedAt,
  String status = 'completed',
}) => WorkoutSession(
  id: id,
  programId: 'program-a',
  workoutTemplateId: 'template-a',
  workoutNameSnapshot: 'Push A',
  date: completedAt,
  startedAt: completedAt.subtract(const Duration(minutes: 45)),
  completedAt: status == 'completed' ? completedAt : null,
  status: status,
  totalVolume: 0,
);

ExerciseSet _validSet(WorkoutSession session) => ExerciseSet(
  exerciseName: 'Bench Press',
  weight: 0,
  reps: 10,
  date: session.completedAt ?? session.date,
  programId: session.programId,
  workoutTemplateId: session.workoutTemplateId,
  workoutSessionId: session.id,
);

void main() {
  const service = MyProgressSummaryService();
  final now = DateTime(2026, 10, 25, 12);

  test('counts only completed sessions in total, week, month, and trend', () {
    final sessions = [
      _session(id: 'today', completedAt: now),
      _session(
        id: 'last-week',
        completedAt: now.subtract(const Duration(days: 8)),
      ),
      _session(id: 'last-month', completedAt: DateTime(2026, 9, 29)),
      _session(id: 'cancelled', completedAt: now, status: 'cancelled'),
      _session(id: 'in-progress', completedAt: now, status: 'inProgress'),
    ];
    final sets = sessions.take(3).map(_validSet).toList();

    final result = service.summarize(sessions: sessions, sets: sets, now: now);

    expect(result.completedWorkouts, 3);
    expect(result.completedThisWeek, 1);
    expect(result.completedThisMonth, 2);
    expect(
      result.weeklyActivity,
      hasLength(MyProgressSummaryService.displayedWeeks),
    );
    expect(result.weeklyActivity.last.completedCount, 1);
    expect(result.weeklyActivity[4].completedCount, 1);
  });

  test(
    'empty history stays genuinely empty with six zero-valued trend buckets',
    () {
      final result = service.summarize(
        sessions: const [],
        sets: const [],
        now: now,
      );

      expect(result.completedWorkouts, 0);
      expect(result.completedThisWeek, 0);
      expect(result.completedThisMonth, 0);
      expect(result.weeklyActivity, hasLength(6));
      expect(
        result.weeklyActivity.every((point) => point.completedCount == 0),
        isTrue,
      );
    },
  );

  test(
    'does not count completed sessions without valid matching set history',
    () {
      final valid = _session(id: 'valid', completedAt: now);
      final empty = _session(id: 'empty', completedAt: now);
      final mismatched = ExerciseSet(
        exerciseName: 'Bench Press',
        weight: 40,
        reps: 8,
        date: now,
        programId: 'other-program',
        workoutTemplateId: 'template-a',
        workoutSessionId: valid.id,
      );

      final result = service.summarize(
        sessions: [valid, empty],
        sets: [mismatched],
        now: now,
      );

      expect(result.completedWorkouts, 0);
      expect(result.completedSessions, isEmpty);
    },
  );

  group('daily activity (last 7 calendar days)', () {
    // now = Sunday 25 Oct 2026, 12:00.
    test('seven days ending today, oldest first, zero days kept', () {
      final result = service.summarize(
        sessions: const [],
        sets: const [],
        now: now,
      );
      expect(result.dailyActivity, hasLength(7));
      expect(result.dailyActivity.first.day, DateTime(2026, 10, 19));
      expect(result.dailyActivity.last.day, DateTime(2026, 10, 25));
      for (var i = 1; i < 7; i++) {
        expect(
          result.dailyActivity[i].day
              .difference(result.dailyActivity[i - 1].day)
              .inHours,
          inInclusiveRange(23, 25), // calendar days, DST-safe
        );
      }
      expect(result.dailyActivity.every((p) => p.completedCount == 0), isTrue);
    });

    test(
      'counts completed workouts per local calendar day by completion time',
      () {
        final sessions = [
          _session(id: 'today-1', completedAt: DateTime(2026, 10, 25, 7)),
          _session(id: 'today-2', completedAt: DateTime(2026, 10, 25, 11, 59)),
          // Midnight belongs to the new day; 23:59 to the old one.
          _session(id: 'mon-start', completedAt: DateTime(2026, 10, 19)),
          _session(id: 'sat-end', completedAt: DateTime(2026, 10, 24, 23, 59)),
          // Outside the window.
          _session(id: 'too-old', completedAt: DateTime(2026, 10, 18, 23, 59)),
          // Not counted: cancelled / in progress / no logged set.
          _session(id: 'cancelled', completedAt: now, status: 'cancelled'),
          _session(id: 'in-progress', completedAt: now, status: 'inProgress'),
          _session(id: 'no-sets', completedAt: now),
        ];
        final sets = sessions
            .where((s) => s.id != 'no-sets')
            .map(_validSet)
            .toList();

        final daily = service
            .summarize(sessions: sessions, sets: sets, now: now)
            .dailyActivity;

        expect(daily.map((p) => p.completedCount).toList(), [
          1,
          0,
          0,
          0,
          0,
          1,
          2,
        ]);
        final total = daily.fold<int>(0, (sum, p) => sum + p.completedCount);
        expect(total, 4); // the same definition as the summary numbers
      },
    );

    test('a session saved without a completion time counts on its date', () {
      final legacy = WorkoutSession(
        id: 'legacy',
        programId: 'program-a',
        workoutTemplateId: 'template-a',
        workoutNameSnapshot: 'Push A',
        date: DateTime(2026, 10, 23, 18),
        startedAt: DateTime(2026, 10, 23, 17),
        status: 'completed',
        totalVolume: 0,
      );
      final daily = service
          .summarize(sessions: [legacy], sets: [_validSet(legacy)], now: now)
          .dailyActivity;
      expect(daily[4].day, DateTime(2026, 10, 23));
      expect(daily[4].completedCount, 1);
    });
  });

  test('completed sessions are listed newest first', () {
    final sessions = [
      _session(id: 'middle', completedAt: DateTime(2026, 10, 20)),
      _session(id: 'newest', completedAt: DateTime(2026, 10, 24)),
      _session(id: 'oldest', completedAt: DateTime(2026, 9, 1)),
    ];
    final result = service.summarize(
      sessions: sessions,
      sets: sessions.map(_validSet).toList(),
      now: now,
    );
    expect(result.completedSessions.map((s) => s.id), [
      'newest',
      'middle',
      'oldest',
    ]);
  });
}
