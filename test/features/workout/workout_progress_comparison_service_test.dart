import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/domain/services/workout_progress_comparison_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session({
  required String id,
  required String programId,
  required String workoutTemplateId,
  WorkoutSessionStatus status = WorkoutSessionStatus.completed,
}) {
  final now = DateTime(2025, 1, 1);
  return WorkoutSession(
    id: id,
    programId: programId,
    workoutTemplateId: workoutTemplateId,
    workoutNameSnapshot: 'Push 1',
    date: now,
    startedAt: now,
    completedAt: status == WorkoutSessionStatus.completed ? now : null,
    status: status.value,
  );
}

ExerciseSet _set({
  required String sessionId,
  required String exerciseName,
  required double weight,
  required int reps,
  String programId = 'program_A',
  String workoutTemplateId = 'template_push1',
}) {
  return ExerciseSet(
    exerciseName: exerciseName,
    weight: weight,
    reps: reps,
    date: DateTime(2025, 1, 1),
    programId: programId,
    workoutTemplateId: workoutTemplateId,
    workoutSessionId: sessionId,
  );
}

void main() {
  const service = WorkoutProgressComparisonService();
  const programA = 'program_A';
  const push1 = 'template_push1';
  const push2 = 'template_push2';

  test('with no previous session, every exercise is newExercise and previous* fields are null', () {
    final current = _session(id: 's2', programId: programA, workoutTemplateId: push1);
    final summary = service.compare(
      currentSession: current,
      currentSets: [_set(sessionId: 's2', exerciseName: 'Bench Press', weight: 60, reps: 8)],
    );

    expect(summary.hasPreviousSession, isFalse);
    expect(summary.previousTotalVolume, isNull);
    expect(summary.volumeDeltaPercent, isNull);
    expect(summary.exerciseResults, hasLength(1));
    expect(summary.exerciseResults.single.trend, equals(PerformanceTrend.newExercise));
    expect(summary.exerciseResults.single.previousVolume, isNull);
  });

  test('higher volume than last time is improved, with a positive delta percent', () {
    final previous = _session(id: 's1', programId: programA, workoutTemplateId: push1);
    final current = _session(id: 's2', programId: programA, workoutTemplateId: push1);

    final summary = service.compare(
      currentSession: current,
      currentSets: [_set(sessionId: 's2', exerciseName: 'Bench Press', weight: 65, reps: 8)], // 520
      previousSession: previous,
      previousSets: [_set(sessionId: 's1', exerciseName: 'Bench Press', weight: 60, reps: 8)], // 480
    );

    final result = summary.exerciseResults.single;
    expect(result.trend, equals(PerformanceTrend.improved));
    expect(result.currentVolume, equals(520));
    expect(result.previousVolume, equals(480));
    expect(result.volumeDeltaPercent, closeTo(8.33, 0.01));
    expect(summary.volumeDeltaPercent, closeTo(8.33, 0.01));
  });

  test('identical volume is maintained; lower volume is declined', () {
    final previous = _session(id: 's1', programId: programA, workoutTemplateId: push1);
    final current = _session(id: 's2', programId: programA, workoutTemplateId: push1);

    final maintained = service.compare(
      currentSession: current,
      currentSets: [_set(sessionId: 's2', exerciseName: 'Bench Press', weight: 60, reps: 8)],
      previousSession: previous,
      previousSets: [_set(sessionId: 's1', exerciseName: 'Bench Press', weight: 60, reps: 8)],
    );
    expect(maintained.exerciseResults.single.trend, equals(PerformanceTrend.maintained));

    final declined = service.compare(
      currentSession: current,
      currentSets: [_set(sessionId: 's2', exerciseName: 'Bench Press', weight: 50, reps: 8)],
      previousSession: previous,
      previousSets: [_set(sessionId: 's1', exerciseName: 'Bench Press', weight: 60, reps: 8)],
    );
    expect(declined.exerciseResults.single.trend, equals(PerformanceTrend.declined));
  });

  test(
    'passing a previousSession from a DIFFERENT workoutTemplateId throws — Push 1 must never be '
    'compared to Push 2, even by caller mistake',
    () {
      final push1Session = _session(id: 's1', programId: programA, workoutTemplateId: push1);
      final push2Session = _session(id: 's2', programId: programA, workoutTemplateId: push2);

      expect(
        () => service.compare(
          currentSession: push2Session,
          currentSets: const [],
          previousSession: push1Session,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'stray sets belonging to unrelated sessions are filtered out even if the caller passes '
    'them by mistake (defense in depth)',
    () {
      final previous = _session(id: 's1', programId: programA, workoutTemplateId: push1);
      final current = _session(id: 's2', programId: programA, workoutTemplateId: push1);
      final unrelated = _session(id: 's_unrelated', programId: programA, workoutTemplateId: push2);

      final summary = service.compare(
        currentSession: current,
        currentSets: [
          _set(sessionId: 's2', exerciseName: 'Bench Press', weight: 65, reps: 8),
          _set(sessionId: unrelated.id, exerciseName: 'Overhead Press', weight: 999, reps: 99),
        ],
        previousSession: previous,
        previousSets: [_set(sessionId: 's1', exerciseName: 'Bench Press', weight: 60, reps: 8)],
      );

      expect(summary.exerciseResults, hasLength(1));
      expect(summary.exerciseResults.single.exerciseName, equals('Bench Press'));
      expect(summary.currentTotalVolume, equals(520));
    },
  );

  test('a reference-only exercise (no current sets) never appears in exerciseResults', () {
    final previous = _session(id: 's1', programId: programA, workoutTemplateId: push1);
    final current = _session(id: 's2', programId: programA, workoutTemplateId: push1);

    final summary = service.compare(
      currentSession: current,
      currentSets: const [], // nothing logged yet this session
      previousSession: previous,
      previousSets: [_set(sessionId: 's1', exerciseName: 'Bench Press', weight: 60, reps: 8)],
    );

    expect(summary.exerciseResults, isEmpty);
    expect(summary.currentTotalVolume, equals(0));
    expect(summary.previousTotalVolume, equals(480));
  });
}
