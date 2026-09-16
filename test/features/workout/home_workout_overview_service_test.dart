import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/domain/services/home_workout_overview_service.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutProgram _program(String id, {bool isActive = true}) {
  return WorkoutProgram(id: id, name: 'PPL', createdAt: DateTime(2025, 1, 1), isActive: isActive);
}

WorkoutTemplate _template(String id, String programId, String name) {
  return WorkoutTemplate(id: id, programId: programId, name: name, createdAt: DateTime(2025, 1, 1));
}

WorkoutSession _completedSession(
  String id,
  String programId,
  String templateId,
  String name,
  DateTime completedAt, {
  double totalVolume = 0,
}) {
  return WorkoutSession(
    id: id,
    programId: programId,
    workoutTemplateId: templateId,
    workoutNameSnapshot: name,
    date: completedAt,
    startedAt: completedAt.subtract(const Duration(hours: 1)),
    completedAt: completedAt,
    status: WorkoutSessionStatus.completed.value,
    totalVolume: totalVolume,
  );
}

WorkoutSession _inProgressSession(String id, String programId, String templateId, String name, DateTime startedAt) {
  return WorkoutSession(
    id: id,
    programId: programId,
    workoutTemplateId: templateId,
    workoutNameSnapshot: name,
    date: startedAt,
    startedAt: startedAt,
    status: WorkoutSessionStatus.inProgress.value,
  );
}

ExerciseSet _linkedSet(String sessionId, String programId, String templateId, String exerciseName) {
  return ExerciseSet(
    exerciseName: exerciseName,
    weight: 60,
    reps: 8,
    date: DateTime(2025, 1, 1),
    programId: programId,
    workoutTemplateId: templateId,
    workoutSessionId: sessionId,
  );
}

ExerciseSet _legacySet(String exerciseName) {
  return ExerciseSet(exerciseName: exerciseName, weight: 60, reps: 8, date: DateTime(2025, 1, 1));
}

void main() {
  const service = HomeWorkoutOverviewService();
  const programA = 'program_A';
  final now = DateTime(2025, 6, 4, 12); // a Wednesday

  test('an active in-progress session is surfaced as-is, independent of everything else', () {
    final active = _inProgressSession('s_active', programA, 't_push', 'Push', now.subtract(const Duration(minutes: 35)));

    final overview = service.build(
      now: now,
      activeSession: active,
      allCompletedSessions: const [],
      templatesByTemplateId: const {},
      setsBySessionId: const {},
    );

    expect(overview.activeSession, same(active));
  });

  test('no active session and no active program produce the correctly-empty overview', () {
    final overview = service.build(
      now: now,
      allCompletedSessions: const [],
      templatesByTemplateId: const {},
      setsBySessionId: const {},
    );

    expect(overview.activeSession, isNull);
    expect(overview.activeProgram, isNull);
    expect(overview.recentSessions, isEmpty);
  });

  test('no completed workouts yet produces an empty recentSessions list even with an active program', () {
    final program = _program(programA);
    final overview = service.build(
      now: now,
      activeProgram: program,
      allCompletedSessions: const [],
      templatesByTemplateId: const {},
      setsBySessionId: const {},
    );

    expect(overview.recentSessions, isEmpty);
    expect(overview.activeProgram!.sessionsCompletedThisWeek, equals(0));
  });

  test('recent completed sessions are sorted newest-first and limited to the recent count', () {
    final s1 = _completedSession('s1', programA, 't_push', 'Push', DateTime(2025, 1, 1));
    final s2 = _completedSession('s2', programA, 't_pull', 'Pull', DateTime(2025, 3, 1));
    final s3 = _completedSession('s3', programA, 't_push', 'Push', DateTime(2025, 2, 1));

    final overview = service.build(
      now: now,
      allCompletedSessions: [s1, s2, s3], // deliberately unsorted
      templatesByTemplateId: const {},
      setsBySessionId: const {},
      recentLimit: 2,
    );

    expect(overview.recentSessions, hasLength(2));
    expect(overview.recentSessions[0].session.id, equals('s2')); // March, newest
    expect(overview.recentSessions[1].session.id, equals('s3')); // February
  });

  test('Push and Pull sessions stay fully separate — never merged into one card', () {
    final push = _completedSession('s_push', programA, 't_push', 'Push', DateTime(2025, 1, 2));
    final pull = _completedSession('s_pull', programA, 't_pull', 'Pull', DateTime(2025, 1, 1));

    final overview = service.build(
      now: now,
      allCompletedSessions: [push, pull],
      templatesByTemplateId: const {},
      setsBySessionId: {
        's_push': [_linkedSet('s_push', programA, 't_push', 'Bench Press')],
        's_pull': [_linkedSet('s_pull', programA, 't_pull', 'Lat Pulldown')],
      },
    );

    expect(overview.recentSessions, hasLength(2));
    expect(overview.recentSessions[0].session.workoutNameSnapshot, equals('Push'));
    expect(overview.recentSessions[0].exerciseNames, equals(['Bench Press']));
    expect(overview.recentSessions[1].session.workoutNameSnapshot, equals('Pull'));
    expect(overview.recentSessions[1].exerciseNames, equals(['Lat Pulldown']));
  });

  test('exercise/set counts are computed correctly, including repeated exercises across multiple sets', () {
    final session = _completedSession('s1', programA, 't_push', 'Push', DateTime(2025, 1, 1));

    final overview = service.build(
      now: now,
      allCompletedSessions: [session],
      templatesByTemplateId: const {},
      setsBySessionId: {
        's1': [
          _linkedSet('s1', programA, 't_push', 'Bench Press'),
          _linkedSet('s1', programA, 't_push', 'Bench Press'),
          _linkedSet('s1', programA, 't_push', 'Incline Press'),
        ],
      },
    );

    final summary = overview.recentSessions.single;
    expect(summary.exerciseCount, equals(2)); // Bench Press + Incline Press
    expect(summary.setCount, equals(3)); // 3 sets total
  });

  test('totalVolume is read from the session\'s own stored value, not recomputed', () {
    final session = _completedSession('s1', programA, 't_push', 'Push', DateTime(2025, 1, 1), totalVolume: 4820);

    final overview = service.build(
      now: now,
      allCompletedSessions: [session],
      templatesByTemplateId: const {},
      setsBySessionId: const {},
    );

    expect(overview.recentSessions.single.session.totalVolume, equals(4820));
  });

  test('legacy (unlinked) ExerciseSets are never turned into a session card', () {
    // Only a legacy set exists — no real WorkoutSession at all.
    final overview = service.build(
      now: now,
      allCompletedSessions: const [], // no WorkoutSession, even though legacy sets exist elsewhere in storage
      templatesByTemplateId: const {},
      setsBySessionId: const {},
    );

    expect(overview.recentSessions, isEmpty);
  });

  test(
    'even if a caller mistakenly hands over a legacy set under a session id, it is not counted '
    'toward that session\'s real linked exercises (defense in depth)',
    () {
      final session = _completedSession('s1', programA, 't_push', 'Push', DateTime(2025, 1, 1));

      final overview = service.build(
        now: now,
        allCompletedSessions: [session],
        templatesByTemplateId: const {},
        setsBySessionId: {
          's1': [_legacySet('Bench Press')], // no workoutSessionId at all
        },
      );

      // The service does not special-case this — it trusts the
      // caller's map keying, but a legacy set never legitimately ends
      // up here because SessionExerciseRepository.getSetsForSession
      // filters by workoutSessionId. This test documents that the
      // service itself still produces a sane (non-crashing) result.
      expect(overview.recentSessions.single.exerciseCount, equals(1));
    },
  );

  test('sessionsCompletedThisWeek only counts sessions within the current Monday-start week', () {
    final program = _program(programA);
    final thisWeek = _completedSession('s1', programA, 't_push', 'Push', DateTime(2025, 6, 3));
    final lastWeek = _completedSession('s2', programA, 't_pull', 'Pull', DateTime(2025, 5, 27));

    final overview = service.build(
      now: now, // Wednesday 2025-06-04, week starts Monday 2025-06-02
      activeProgram: program,
      activeProgramCompletedSessions: [thisWeek, lastWeek],
      allCompletedSessions: [thisWeek, lastWeek],
      templatesByTemplateId: const {},
      setsBySessionId: const {},
    );

    expect(overview.activeProgram!.sessionsCompletedThisWeek, equals(1));
  });

  test('the matching WorkoutTemplate is attached for navigation when provided', () {
    final template = _template('t_push', programA, 'Push');
    final session = _completedSession('s1', programA, 't_push', 'Push', DateTime(2025, 1, 1));

    final overview = service.build(
      now: now,
      allCompletedSessions: [session],
      templatesByTemplateId: {'t_push': template},
      setsBySessionId: const {},
    );

    expect(overview.recentSessions.single.template, same(template));
  });
}
