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
}
