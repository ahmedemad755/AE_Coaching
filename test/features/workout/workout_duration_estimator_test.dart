import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/workout_duration_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutTemplateExerciseAssignment strength({
  int? sets,
  int? repsMin,
  int? repsMax,
  int? rest,
}) => WorkoutTemplateExerciseAssignment(
  assignmentId: 's',
  exerciseId: 'repdb:bench-press',
  exerciseNameSnapshot: 'Bench Press',
  referenceType: 'builtIn',
  workingSets: sets,
  targetRepsMin: repsMin,
  targetRepsMax: repsMax,
  restSeconds: rest,
);

WorkoutTemplateExerciseAssignment cardio(CardioPlan plan) =>
    WorkoutTemplateExerciseAssignment(
      assignmentId: 'c',
      exerciseId: 'repdb:running',
      exerciseNameSnapshot: 'Running',
      referenceType: 'builtIn',
    ).withActivity(type: ActivityType.cardio, cardio: plan);

int? seconds(WorkoutTemplateExerciseAssignment a) =>
    WorkoutDurationEstimator.activitySeconds(a);

void main() {
  test('strength: sets × reps × tempo, rest only BETWEEN sets', () {
    // 3 × 10 reps (middle of 8–12) × 3 s = 90 s, plus 2 rests of 90 s.
    expect(seconds(strength(sets: 3, repsMin: 8, repsMax: 12, rest: 90)), 270);
    // One set: no rest after it.
    expect(seconds(strength(sets: 1, repsMin: 10, repsMax: 10, rest: 120)), 30);
  });

  test('strength with missing values: handled safely', () {
    expect(seconds(strength(sets: 3, repsMin: 8, rest: 60)), 3 * 8 * 3 + 120);
    expect(seconds(strength(sets: 3, repsMax: 12, rest: 60)), 3 * 12 * 3 + 120);
    expect(seconds(strength(sets: 3, repsMin: 10, repsMax: 10)), 90); // no rest
    expect(seconds(strength(repsMin: 8, repsMax: 12, rest: 90)), isNull);
    expect(seconds(strength(sets: 3, rest: 90)), isNull);
    expect(seconds(strength(sets: 0, repsMin: 8, rest: 90)), isNull);
    expect(seconds(strength(sets: 2, repsMin: 10, rest: -30)), 60);
  });

  test(
    'cardio: its configured time; a stopwatch without a target is unknown',
    () {
      expect(
        seconds(
          cardio(
            const CardioPlan(mode: CardioMode.countdown, durationSeconds: 1200),
          ),
        ),
        1200,
      );
      expect(
        seconds(
          cardio(
            const CardioPlan(
              mode: CardioMode.intervals,
              workSeconds: 30,
              intervalRestSeconds: 30,
              rounds: 8,
              warmupSeconds: 300,
              cooldownSeconds: 300,
            ),
          ),
        ),
        300 + 8 * 30 + 7 * 30 + 300,
      );
      expect(
        seconds(cardio(const CardioPlan(mode: CardioMode.stopwatch))),
        isNull,
      );
      expect(
        seconds(
          cardio(
            const CardioPlan(mode: CardioMode.stopwatch, durationSeconds: 900),
          ),
        ),
        900,
      );
    },
  );

  test('a mixed day adds up; unknown activities make it "at least"', () {
    final complete = WorkoutDurationEstimator.estimate([
      strength(sets: 3, repsMin: 8, repsMax: 12, rest: 90),
      cardio(
        const CardioPlan(mode: CardioMode.countdown, durationSeconds: 1200),
      ),
    ])!;
    expect(complete.seconds, 1470);
    expect(complete.minutes, 25); // rounded up
    expect(complete.partial, isFalse);
    expect((complete.counted, complete.total), (2, 2));

    final partial = WorkoutDurationEstimator.estimate([
      strength(sets: 3, repsMin: 8, repsMax: 12, rest: 90),
      cardio(const CardioPlan(mode: CardioMode.stopwatch)),
      strength(sets: 3, repsMin: 10), // no rest set
    ])!;
    expect(partial.seconds, 270 + 90);
    expect(partial.partial, isTrue);
    expect((partial.counted, partial.total), (2, 3));
  });

  test('nothing to estimate: no estimate at all', () {
    expect(WorkoutDurationEstimator.estimate(const []), isNull);
    expect(WorkoutDurationEstimator.estimate([strength()]), isNull);
  });

  test('a malformed saved plan never throws', () {
    final malformed = WorkoutTemplateExerciseAssignment.fromActivityMap({
      'id': 'm',
      'type': 'cardio',
      'exerciseId': 'repdb:walking',
      'referenceType': 'builtIn',
      'name': 'Walking',
      'cardio': {'mode': 'countdown', 'durationSeconds': 'twenty'},
    });
    expect(seconds(malformed), isNull);
  });
}
