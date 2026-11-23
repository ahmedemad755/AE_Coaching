import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/domain/services/program_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutTemplate _template(String id, String programId, String name) {
  return WorkoutTemplate(
    id: id,
    programId: programId,
    name: name,
    createdAt: DateTime(2025, 1, 1),
  );
}

WorkoutSession _completedSession(
  String id,
  String programId,
  String templateId,
  DateTime completedAt,
) {
  return WorkoutSession(
    id: id,
    programId: programId,
    workoutTemplateId: templateId,
    workoutNameSnapshot: 'Day',
    date: completedAt,
    startedAt: completedAt.subtract(const Duration(hours: 1)),
    completedAt: completedAt,
    status: WorkoutSessionStatus.completed.value,
    totalVolume: 0,
  );
}

ExerciseSet _set(
  String sessionId,
  String exerciseName,
  double weight,
  int reps, {
  String programId = 'program_A',
  String templateId = 't1',
}) {
  return ExerciseSet(
    exerciseName: exerciseName,
    weight: weight,
    reps: reps,
    date: DateTime(2025, 1, 1),
    workoutSessionId: sessionId,
    programId: programId,
    workoutTemplateId: templateId,
  );
}

void main() {
  const service = ProgramAnalyticsService();
  const programA = 'program_A';

  test(
    'a template with no completed sessions produces an empty exercise list and zero average volume',
    () {
      final template = _template('t1', programA, 'Push 1');
      final summary = service.build(
        programId: programA,
        templates: [template],
        completedSessionsByTemplate: const {},
        setsBySessionId: const {},
      );

      expect(summary.days, hasLength(1));
      expect(summary.days.single.completedSessionsCount, equals(0));
      expect(summary.days.single.averageSessionVolume, equals(0));
      expect(summary.days.single.exercises, isEmpty);
    },
  );

  test(
    'a single-session exercise has firstVolume == latestVolume and a null overallDeltaPercent',
    () {
      final template = _template('t1', programA, 'Push 1');
      final session = _completedSession(
        's1',
        programA,
        't1',
        DateTime(2025, 1, 1),
      );

      final summary = service.build(
        programId: programA,
        templates: [template],
        completedSessionsByTemplate: {
          't1': [session],
        },
        setsBySessionId: {
          's1': [_set('s1', 'Bench Press', 60, 8)],
        },
      );

      final exercise = summary.days.single.exercises.single;
      expect(exercise.sessionsLogged, equals(1));
      expect(exercise.firstVolume, equals(480));
      expect(exercise.latestVolume, equals(480));
      expect(exercise.overallDeltaPercent, isNull);
    },
  );

  test(
    'across multiple sessions, first/latest volume and delta are computed oldest-vs-newest',
    () {
      final template = _template('t1', programA, 'Push 1');
      final oldest = _completedSession(
        's1',
        programA,
        't1',
        DateTime(2025, 1, 1),
      );
      final newest = _completedSession(
        's2',
        programA,
        't1',
        DateTime(2025, 1, 8),
      );

      final summary = service.build(
        programId: programA,
        templates: [template],
        completedSessionsByTemplate: {
          't1': [
            newest,
            oldest,
          ], // deliberately out of order — service must sort internally
        },
        setsBySessionId: {
          's1': [_set('s1', 'Bench Press', 60, 8)], // 480
          's2': [_set('s2', 'Bench Press', 65, 8)], // 520
        },
      );

      final exercise = summary.days.single.exercises.single;
      expect(exercise.sessionsLogged, equals(2));
      expect(exercise.firstVolume, equals(480));
      expect(exercise.latestVolume, equals(520));
      expect(exercise.overallDeltaPercent, closeTo(8.33, 0.01));
      expect(exercise.bestSetVolume, equals(520));
      expect(exercise.bestWeight, equals(65));
    },
  );

  test(
    'averageSessionVolume trusts each session\'s own stored totalVolume, not a recomputation',
    () {
      final template = _template('t1', programA, 'Push 1');
      final s1 = _completedSession(
        's1',
        programA,
        't1',
        DateTime(2025, 1, 1),
      ).copyWith(totalVolume: 400);
      final s2 = _completedSession(
        's2',
        programA,
        't1',
        DateTime(2025, 1, 8),
      ).copyWith(totalVolume: 600);

      final summary = service.build(
        programId: programA,
        templates: [template],
        completedSessionsByTemplate: {
          't1': [s1, s2],
        },
        setsBySessionId: const {},
      );

      expect(summary.days.single.averageSessionVolume, equals(500));
    },
  );

  test(
    'Push 1 and Push 2 are built as fully separate WorkoutDayAnalyticsSummary entries — '
    'their exercises never merge even when both are named "Bench Press"',
    () {
      final push1 = _template('t1', programA, 'Push 1');
      final push2 = _template('t2', programA, 'Push 2');
      final push1Session = _completedSession(
        's1',
        programA,
        't1',
        DateTime(2025, 1, 1),
      );
      final push2Session = _completedSession(
        's2',
        programA,
        't2',
        DateTime(2025, 1, 2),
      );

      final summary = service.build(
        programId: programA,
        templates: [push1, push2],
        completedSessionsByTemplate: {
          't1': [push1Session],
          't2': [push2Session],
        },
        setsBySessionId: {
          's1': [_set('s1', 'Bench Press', 60, 8)],
          's2': [_set('s2', 'Bench Press', 100, 3, templateId: 't2')],
        },
      );

      expect(summary.days, hasLength(2));
      final push1Day = summary.days.firstWhere(
        (d) => d.workoutTemplateId == 't1',
      );
      final push2Day = summary.days.firstWhere(
        (d) => d.workoutTemplateId == 't2',
      );

      expect(push1Day.exercises.single.bestWeight, equals(60));
      expect(push2Day.exercises.single.bestWeight, equals(100));
    },
  );

  test(
    'exercises are ordered by first appearance across sessions, oldest session first',
    () {
      final template = _template('t1', programA, 'Push 1');
      final s1 = _completedSession('s1', programA, 't1', DateTime(2025, 1, 1));
      final s2 = _completedSession('s2', programA, 't1', DateTime(2025, 1, 8));

      final summary = service.build(
        programId: programA,
        templates: [template],
        completedSessionsByTemplate: {
          't1': [s1, s2],
        },
        setsBySessionId: {
          's1': [_set('s1', 'Incline Press', 40, 10)],
          's2': [
            _set('s2', 'Bench Press', 60, 8),
            _set('s2', 'Incline Press', 42, 10),
          ],
        },
      );

      final names = summary.days.single.exercises
          .map((e) => e.exerciseName)
          .toList();
      expect(names, equals(['Incline Press', 'Bench Press']));
    },
  );

  test(
    'per-session weight, comparable reps, and volume progressions are calculated',
    () {
      final template = _template('t1', programA, 'Push 1');
      final oldest = _completedSession(
        's1',
        programA,
        't1',
        DateTime(2025, 1, 1),
      );
      final latest = _completedSession(
        's2',
        programA,
        't1',
        DateTime(2025, 1, 8),
      );
      final summary = service.build(
        programId: programA,
        templates: [template],
        completedSessionsByTemplate: {
          't1': [oldest, latest],
        },
        setsBySessionId: {
          's1': [
            _set('s1', 'Bench Press', 60, 8),
            _set('s1', ' bench press ', 60, 7),
            _set('s1', 'Bench Press', 70, 4),
          ],
          's2': [
            _set('s2', 'BENCH PRESS', 60, 9),
            _set('s2', 'Bench Press', 75, 3),
          ],
        },
      );

      final exercise = summary.days.single.exercises.single;
      expect(exercise.normalizedExerciseName, 'bench press');
      expect(exercise.sessionMetrics.map((session) => session.maxWeight), [
        70,
        75,
      ]);
      expect(exercise.sessionMetrics.map((session) => session.volume), [
        1180,
        765,
      ]);
      expect(exercise.comparableRepsWeight, 60);
      expect(exercise.previousComparableReps, 8);
      expect(exercise.latestComparableReps, 9);
      expect(exercise.repsProgression.map((point) => point.value), [8, 9]);
      expect(exercise.weightDelta, 5);
      expect(exercise.weightDeltaPercent, closeTo(7.1428, 0.001));
      expect(exercise.volumeDelta, -415);
      expect(exercise.volumeDeltaPercent, closeTo(-35.1694, 0.001));
      expect(exercise.repsDelta, 1);
      expect(exercise.repsDeltaPercent, 12.5);
    },
  );

  test('reps are unavailable when the latest two sessions share no load', () {
    final template = _template('t1', programA, 'Push 1');
    final first = _completedSession('s1', programA, 't1', DateTime(2025, 1, 1));
    final second = _completedSession(
      's2',
      programA,
      't1',
      DateTime(2025, 1, 8),
    );
    final summary = service.build(
      programId: programA,
      templates: [template],
      completedSessionsByTemplate: {
        't1': [first, second],
      },
      setsBySessionId: {
        's1': [_set('s1', 'Bench Press', 60, 8)],
        's2': [_set('s2', 'Bench Press', 65, 8)],
      },
    );

    final exercise = summary.days.single.exercises.single;
    expect(exercise.comparableRepsWeight, isNull);
    expect(exercise.repsDelta, isNull);
    expect(exercise.repsProgression, isEmpty);
  });

  test(
    'zero previous volume has an absolute delta but no misleading percentage',
    () {
      final template = _template('t1', programA, 'Push 1');
      final first = _completedSession(
        's1',
        programA,
        't1',
        DateTime(2025, 1, 1),
      );
      final second = _completedSession(
        's2',
        programA,
        't1',
        DateTime(2025, 1, 8),
      );
      final summary = service.build(
        programId: programA,
        templates: [template],
        completedSessionsByTemplate: {
          't1': [first, second],
        },
        setsBySessionId: {
          's1': [_set('s1', 'Bench Press', 0, 8)],
          's2': [_set('s2', 'Bench Press', 20, 8)],
        },
      );

      final exercise = summary.days.single.exercises.single;
      expect(exercise.volumeDelta, 160);
      expect(exercise.volumeDeltaPercent, isNull);
    },
  );

  test(
    'incomplete sessions, foreign-program templates, and mismatched sets are excluded',
    () {
      final template = _template('t1', programA, 'Push 1');
      final foreignTemplate = _template('foreign', 'program_B', 'Other');
      final completed = _completedSession(
        'done',
        programA,
        't1',
        DateTime(2025, 1, 1),
      );
      final incomplete = WorkoutSession(
        id: 'active',
        programId: programA,
        workoutTemplateId: 't1',
        workoutNameSnapshot: 'Push 1',
        date: DateTime(2025, 1, 2),
        startedAt: DateTime(2025, 1, 2),
        status: WorkoutSessionStatus.inProgress.value,
      );
      final summary = service.build(
        programId: programA,
        templates: [template, foreignTemplate],
        completedSessionsByTemplate: {
          't1': [completed, incomplete],
          'foreign': [
            _completedSession(
              'foreign-session',
              'program_B',
              'foreign',
              DateTime(2025, 1, 3),
            ),
          ],
        },
        setsBySessionId: {
          'done': [
            _set('done', 'Bench Press', 50, 8, programId: 'program_B'),
            _set('wrong-session', 'Bench Press', 500, 8),
          ],
          'active': [_set('active', 'Bench Press', 500, 8)],
          'foreign-session': [
            _set(
              'foreign-session',
              'Bench Press',
              500,
              8,
              programId: 'program_B',
              templateId: 'foreign',
            ),
          ],
        },
      );

      expect(summary.days, hasLength(1));
      expect(summary.days.single.workoutTemplateId, 't1');
      expect(summary.days.single.completedSessionsCount, 1);
      expect(summary.days.single.exercises, isEmpty);
    },
  );
}
