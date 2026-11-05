import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/domain/services/home_progress_comparison_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutProgram _program(String id, String name) =>
    WorkoutProgram(id: id, name: name, createdAt: DateTime(2025));

WorkoutTemplate _template(String id, String programId, String name) =>
    WorkoutTemplate(
      id: id,
      programId: programId,
      name: name,
      createdAt: DateTime(2025),
    );

WorkoutSession _session(
  String id,
  String programId,
  String templateId,
  DateTime completedAt, {
  bool completed = true,
}) => WorkoutSession(
  id: id,
  programId: programId,
  workoutTemplateId: templateId,
  workoutNameSnapshot: templateId,
  date: completedAt,
  startedAt: completedAt,
  completedAt: completed ? completedAt : null,
  status: completed
      ? WorkoutSessionStatus.completed.value
      : WorkoutSessionStatus.inProgress.value,
);

ExerciseSet _set(
  String name,
  String sessionId,
  String programId,
  String templateId,
  double weight,
) => ExerciseSet(
  exerciseName: name,
  weight: weight,
  reps: 10,
  date: DateTime(2025),
  workoutSessionId: sessionId,
  programId: programId,
  workoutTemplateId: templateId,
);

void main() {
  const service = HomeProgressComparisonService();
  final programA = _program('program-a', 'Program A');
  final programB = _program('program-b', 'Program B');
  final pushA = _template('push-a', programA.id, 'Push A');
  final pushB = _template('push-b', programA.id, 'Push B');
  final otherProgramPushA = _template('other-push-a', programB.id, 'Push A');

  test('same exercise in Push A and Push B stays in separate histories', () {
    final sessions = [
      _session('a1', programA.id, pushA.id, DateTime(2025, 1, 1)),
      _session('b1', programA.id, pushB.id, DateTime(2025, 1, 2)),
    ];
    final histories = service.build(
      programs: [programA],
      templates: [pushA, pushB],
      sessions: sessions,
      sets: [
        _set('Bench Press', 'a1', programA.id, pushA.id, 50),
        _set('Bench Press', 'b1', programA.id, pushB.id, 90),
      ],
    );

    expect(histories, hasLength(2));
    expect(
      histories.map((item) => item.workoutTemplateId),
      containsAll([pushA.id, pushB.id]),
    );
    expect(
      histories.map((item) => item.currentVolume),
      containsAll([500, 900]),
    );
  });

  test('same exercise across programs remains separate', () {
    final histories = service.build(
      programs: [programA, programB],
      templates: [pushA, otherProgramPushA],
      sessions: [
        _session('a1', programA.id, pushA.id, DateTime(2025, 1, 1)),
        _session('b1', programB.id, otherProgramPushA.id, DateTime(2025, 1, 2)),
      ],
      sets: [
        _set('Bench Press', 'a1', programA.id, pushA.id, 50),
        _set(' bench press ', 'b1', programB.id, otherProgramPushA.id, 90),
      ],
    );

    expect(histories, hasLength(2));
    expect(
      histories.map((item) => item.programId),
      containsAll([programA.id, programB.id]),
    );
  });

  test('multiple sessions of the same template compare newest two only', () {
    final histories = service.build(
      programs: [programA],
      templates: [pushA, pushB],
      sessions: [
        _session('old', programA.id, pushA.id, DateTime(2025, 1, 1)),
        _session('latest', programA.id, pushA.id, DateTime(2025, 1, 3)),
        _session('middle', programA.id, pushA.id, DateTime(2025, 1, 2)),
      ],
      sets: [
        _set('Bench Press', 'old', programA.id, pushA.id, 40),
        _set('Bench Press', 'middle', programA.id, pushA.id, 50),
        _set('Bench Press', 'latest', programA.id, pushA.id, 60),
      ],
    );

    final history = histories.single;
    expect(history.sessions.map((item) => item.sessionId), [
      'old',
      'middle',
      'latest',
    ]);
    expect(history.previousVolume, 500);
    expect(history.currentVolume, 600);
  });

  test('unlinked legacy sets and incomplete sessions are excluded', () {
    final histories = service.build(
      programs: [programA],
      templates: [pushA],
      sessions: [
        _session('done', programA.id, pushA.id, DateTime(2025, 1, 1)),
        _session(
          'active',
          programA.id,
          pushA.id,
          DateTime(2025, 1, 2),
          completed: false,
        ),
      ],
      sets: [
        _set('Bench Press', 'done', programA.id, pushA.id, 50),
        ExerciseSet(
          exerciseName: 'Bench Press',
          weight: 999,
          reps: 10,
          date: DateTime(2025, 1, 1),
        ),
        _set('Bench Press', 'active', programA.id, pushA.id, 999),
      ],
    );

    expect(histories, hasLength(1));
    expect(histories.single.sessions, hasLength(1));
    expect(histories.single.currentVolume, 500);
  });

  test('mismatched set linkage or template ownership is excluded', () {
    final wrongProgramTemplate = _template(
      'wrong-template',
      programB.id,
      'Wrong',
    );
    final histories = service.build(
      programs: [programA, programB],
      templates: [pushA, wrongProgramTemplate],
      sessions: [
        _session('session', programA.id, pushA.id, DateTime(2025, 1, 1)),
      ],
      sets: [_set('Bench Press', 'session', programB.id, pushA.id, 50)],
    );

    expect(histories, isEmpty);
  });
}
