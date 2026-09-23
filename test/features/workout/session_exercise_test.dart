import 'dart:io';

import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/domain/services/personal_record_detection_service.dart';
import 'package:ae_coaching/features/workout/domain/services/workout_progress_comparison_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Hand-rolled fakes — no mocking package, same pattern as every other
/// repository test in this suite.
class _FakeWorkoutRemoteDataSource implements WorkoutRemoteDataSource {
  @override
  Future<void> syncSet(String key, ExerciseSet set) async {}

  @override
  Future<void> deleteSet(String key) async {}

  @override
  Future<void> deleteMultipleSets(List<String> keys) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSets() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

class _FakeWorkoutSessionRemoteDataSource implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSessions() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

void main() {
  late Directory tempDir;
  late SessionExerciseRepository setRepository;
  late WorkoutSessionRepository sessionRepository;

  const programA = 'program_A';
  const push1 = 'template_push1';
  const push2 = 'template_push2';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_exercise_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ExerciseSetAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(WorkoutSessionAdapter());

    final storageManager = UserStorageManager();
    setRepository = SessionExerciseRepository(
      remoteDataSource: _FakeWorkoutRemoteDataSource(),
      storageManager: storageManager,
      uidOverride: () => 'test-uid',
    );
    sessionRepository = WorkoutSessionRepository(
      remoteDataSource: _FakeWorkoutSessionRemoteDataSource(),
      storageManager: storageManager,
      uidOverride: () => 'test-uid',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('addSet links exerciseName/weight/reps to the given session/program/template', () async {
    final sessionBox = await sessionRepository.getUserBox();
    final session = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );

    final set = await setRepository.addSet(
      programId: programA,
      workoutTemplateId: push1,
      workoutSessionId: session.id,
      exerciseName: 'Bench Press',
      weight: 60,
      reps: 8,
    );

    expect(set.programId, equals(programA));
    expect(set.workoutTemplateId, equals(push1));
    expect(set.workoutSessionId, equals(session.id));
    expect(set.hasConsistentSessionLinkage, isTrue);

    final box = await setRepository.getUserBox();
    expect(setRepository.getSetsForSession(box, session.id), hasLength(1));
    sessionBox.close();
  });

  test('getExerciseNamesForSession preserves first-appearance order with no duplicates', () async {
    final session = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );

    Future<void> log(String name, double w, int r) => setRepository
        .addSet(
          programId: programA,
          workoutTemplateId: push1,
          workoutSessionId: session.id,
          exerciseName: name,
          weight: w,
          reps: r,
        )
        .then((_) {});

    await log('Bench Press', 60, 8);
    await log('Incline Press', 40, 10);
    await log('Bench Press', 62.5, 8); // second set, same exercise — must not duplicate the name

    final box = await setRepository.getUserBox();
    expect(
      setRepository.getExerciseNamesForSession(box, session.id),
      equals(['Bench Press', 'Incline Press']),
    );
    expect(setRepository.getSetsForExerciseInSession(box, session.id, 'Bench Press'), hasLength(2));
  });

  test(
    'Push 1 and Push 2 sessions never mix exercises even though both link to the same programId',
    () async {
      final push1Session = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );
      await setRepository.addSet(
        programId: programA,
        workoutTemplateId: push1,
        workoutSessionId: push1Session.id,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );
      await sessionRepository.completeWorkoutSession(sessionId: push1Session.id, totalVolume: 480);

      final push2Session = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push2,
        workoutNameSnapshot: 'Push 2',
      );
      await setRepository.addSet(
        programId: programA,
        workoutTemplateId: push2,
        workoutSessionId: push2Session.id,
        exerciseName: 'Overhead Press',
        weight: 30,
        reps: 10,
      );

      final box = await setRepository.getUserBox();
      expect(setRepository.getExerciseNamesForSession(box, push1Session.id), equals(['Bench Press']));
      expect(setRepository.getExerciseNamesForSession(box, push2Session.id), equals(['Overhead Press']));
    },
  );

  test('deleteSet removes only that set, never cascades to the rest of the session', () async {
    final session = await sessionRepository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    final first = await setRepository.addSet(
      programId: programA,
      workoutTemplateId: push1,
      workoutSessionId: session.id,
      exerciseName: 'Bench Press',
      weight: 60,
      reps: 8,
    );
    await setRepository.addSet(
      programId: programA,
      workoutTemplateId: push1,
      workoutSessionId: session.id,
      exerciseName: 'Bench Press',
      weight: 62.5,
      reps: 8,
    );

    await setRepository.deleteSet(first);

    final box = await setRepository.getUserBox();
    final remaining = setRepository.getSetsForExerciseInSession(box, session.id, 'Bench Press');
    expect(remaining, hasLength(1));
    expect(remaining.first.weight, equals(62.5));
  });

  group('SessionExerciseCubit — auto-loaded structure (Phase 8)', () {
    test('a brand-new session with no previous history has no reference rows', () async {
      final session = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );

      final cubit = SessionExerciseCubit(repository: setRepository, sessionRepository: sessionRepository);
      await cubit.loadForSession(session);

      final state = cubit.state as SessionExerciseLoaded;
      expect(state.rows, isEmpty);
      expect(state.hasReferenceSession, isFalse);
      await cubit.close();
    });

    test(
      'the previous COMPLETED same-template session\'s exercises appear as reference-only '
      'suggestions, and never as already-logged sets',
      () async {
        final firstSession = await sessionRepository.startWorkoutSession(
          programId: programA,
          workoutTemplateId: push1,
          workoutNameSnapshot: 'Push 1',
        );
        await setRepository.addSet(
          programId: programA,
          workoutTemplateId: push1,
          workoutSessionId: firstSession.id,
          exerciseName: 'Bench Press',
          weight: 60,
          reps: 8,
        );
        await sessionRepository.completeWorkoutSession(sessionId: firstSession.id, totalVolume: 480);

        final secondSession = await sessionRepository.startWorkoutSession(
          programId: programA,
          workoutTemplateId: push1,
          workoutNameSnapshot: 'Push 1',
        );

        final cubit = SessionExerciseCubit(repository: setRepository, sessionRepository: sessionRepository);
        await cubit.loadForSession(secondSession);

        final state = cubit.state as SessionExerciseLoaded;
        expect(state.hasReferenceSession, isTrue);
        expect(state.rows, hasLength(1));
        expect(state.rows.single.exerciseName, equals('Bench Press'));
        expect(state.rows.single.isReferenceOnly, isTrue);
        expect(state.rows.single.sets, isEmpty);

        await cubit.close();
      },
    );

    test('logging a set for a reference-only exercise moves it out of the suggestion list', () async {
      final firstSession = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );
      await setRepository.addSet(
        programId: programA,
        workoutTemplateId: push1,
        workoutSessionId: firstSession.id,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );
      await sessionRepository.completeWorkoutSession(sessionId: firstSession.id, totalVolume: 480);

      final secondSession = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );

      final cubit = SessionExerciseCubit(repository: setRepository, sessionRepository: sessionRepository);
      await cubit.loadForSession(secondSession);

      await cubit.logSet(session: secondSession, exerciseName: 'Bench Press', weight: 65, reps: 8);

      final state = cubit.state as SessionExerciseLoaded;
      expect(state.rows, hasLength(1));
      expect(state.rows.single.isReferenceOnly, isFalse);
      expect(state.rows.single.sets, hasLength(1));
      expect(state.rows.single.sets.single.weight, equals(65));

      await cubit.close();
    });

    test(
      'previousSets carries the previous COMPLETED session\'s actual weight/reps for that '
      'exact exercise, for both already-logged and reference-only rows',
      () async {
        final firstSession = await sessionRepository.startWorkoutSession(
          programId: programA,
          workoutTemplateId: push1,
          workoutNameSnapshot: 'Push 1',
        );
        await setRepository.addSet(
          programId: programA,
          workoutTemplateId: push1,
          workoutSessionId: firstSession.id,
          exerciseName: 'Bench Press',
          weight: 60,
          reps: 8,
        );
        await setRepository.addSet(
          programId: programA,
          workoutTemplateId: push1,
          workoutSessionId: firstSession.id,
          exerciseName: 'Bench Press',
          weight: 62.5,
          reps: 8,
        );
        await sessionRepository.completeWorkoutSession(sessionId: firstSession.id, totalVolume: 980);

        final secondSession = await sessionRepository.startWorkoutSession(
          programId: programA,
          workoutTemplateId: push1,
          workoutNameSnapshot: 'Push 1',
        );

        final cubit = SessionExerciseCubit(repository: setRepository, sessionRepository: sessionRepository);
        await cubit.loadForSession(secondSession);

        // Reference-only row: not logged yet in this session, but its
        // previousSets should already show last time's two sets.
        var state = cubit.state as SessionExerciseLoaded;
        final referenceRow = state.rows.single;
        expect(referenceRow.isReferenceOnly, isTrue);
        expect(referenceRow.previousSets, hasLength(2));
        expect(referenceRow.previousSets.map((s) => s.weight), equals([60.0, 62.5]));

        // After logging a new set for it, previousSets must still show
        // (never disappear once it's no longer reference-only).
        await cubit.logSet(session: secondSession, exerciseName: 'Bench Press', weight: 65, reps: 8);
        state = cubit.state as SessionExerciseLoaded;
        final loggedRow = state.rows.single;
        expect(loggedRow.isReferenceOnly, isFalse);
        expect(loggedRow.previousSets, hasLength(2));

        await cubit.close();
      },
    );

    test(
      'Push 1 never suggests Push 2\'s exercises as reference rows, even within the same program',
      () async {
        final push1First = await sessionRepository.startWorkoutSession(
          programId: programA,
          workoutTemplateId: push1,
          workoutNameSnapshot: 'Push 1',
        );
        await setRepository.addSet(
          programId: programA,
          workoutTemplateId: push1,
          workoutSessionId: push1First.id,
          exerciseName: 'Bench Press',
          weight: 60,
          reps: 8,
        );
        await sessionRepository.completeWorkoutSession(sessionId: push1First.id, totalVolume: 480);

        final push2Session = await sessionRepository.startWorkoutSession(
          programId: programA,
          workoutTemplateId: push2,
          workoutNameSnapshot: 'Push 2',
        );

        final cubit = SessionExerciseCubit(repository: setRepository, sessionRepository: sessionRepository);
        await cubit.loadForSession(push2Session);

        final state = cubit.state as SessionExerciseLoaded;
        expect(state.rows, isEmpty);
        expect(state.hasReferenceSession, isFalse);

        await cubit.close();
      },
    );
  });

  group('SessionExerciseLoaded.totalVolume (Phase 10)', () {
    test('sums weight × reps across every real set, ignoring reference-only rows', () async {
      final firstSession = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );
      await setRepository.addSet(
        programId: programA,
        workoutTemplateId: push1,
        workoutSessionId: firstSession.id,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );
      await setRepository.addSet(
        programId: programA,
        workoutTemplateId: push1,
        workoutSessionId: firstSession.id,
        exerciseName: 'Incline Press',
        weight: 40,
        reps: 10,
      );
      await sessionRepository.completeWorkoutSession(sessionId: firstSession.id, totalVolume: 880);

      final secondSession = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );

      final cubit = SessionExerciseCubit(repository: setRepository, sessionRepository: sessionRepository);
      await cubit.loadForSession(secondSession);

      // Both exercises from the previous session are reference-only —
      // no real sets yet, so volume must be zero.
      var state = cubit.state as SessionExerciseLoaded;
      expect(state.totalVolume, equals(0));

      // Logging one real set (65kg × 8 = 520) must count; the
      // remaining reference-only suggestion must not contribute.
      await cubit.logSet(session: secondSession, exerciseName: 'Bench Press', weight: 65, reps: 8);
      state = cubit.state as SessionExerciseLoaded;
      expect(state.totalVolume, equals(520));

      await cubit.close();
    });
  });

  group('SessionExerciseCubit.buildCompletionSummary (Phase 13)', () {
    test(
      'bundles a progress summary scoped to the same program+template and PRs scoped '
      'across the user\'s whole history',
      () async {
        final firstSession = await sessionRepository.startWorkoutSession(
          programId: programA,
          workoutTemplateId: push1,
          workoutNameSnapshot: 'Push 1',
        );
        await setRepository.addSet(
          programId: programA,
          workoutTemplateId: push1,
          workoutSessionId: firstSession.id,
          exerciseName: 'Bench Press',
          weight: 60,
          reps: 8,
        );
        await sessionRepository.completeWorkoutSession(sessionId: firstSession.id, totalVolume: 480);

        final secondSession = await sessionRepository.startWorkoutSession(
          programId: programA,
          workoutTemplateId: push1,
          workoutNameSnapshot: 'Push 1',
        );
        await setRepository.addSet(
          programId: programA,
          workoutTemplateId: push1,
          workoutSessionId: secondSession.id,
          exerciseName: 'Bench Press',
          weight: 65, // heavier than ever before -> PR
          reps: 8,
        );
        final completedSecond = await sessionRepository.completeWorkoutSession(
          sessionId: secondSession.id,
          totalVolume: 520,
        );

        final cubit = SessionExerciseCubit(repository: setRepository, sessionRepository: sessionRepository);
        final result = await cubit.buildCompletionSummary(completedSecond);

        expect(result.progressSummary.hasPreviousSession, isTrue);
        expect(result.progressSummary.exerciseResults.single.trend, equals(PerformanceTrend.improved));
        expect(result.progressSummary.currentTotalVolume, equals(520));

        expect(result.personalRecords, isNotEmpty);
        final weightPr = result.personalRecords.firstWhere((r) => r.type == PersonalRecordType.heaviestWeight);
        expect(weightPr.previousBest, equals(60));
        expect(weightPr.newBest, equals(65));

        await cubit.close();
      },
    );

    test(
      'Push 1 and Push 2 never cross-contaminate: comparison stays isolated even though PR '
      'detection deliberately looks at the whole account',
      () async {
        final push1Session = await sessionRepository.startWorkoutSession(
          programId: programA,
          workoutTemplateId: push1,
          workoutNameSnapshot: 'Push 1',
        );
        await setRepository.addSet(
          programId: programA,
          workoutTemplateId: push1,
          workoutSessionId: push1Session.id,
          exerciseName: 'Bench Press',
          weight: 60,
          reps: 8,
        );
        await sessionRepository.completeWorkoutSession(sessionId: push1Session.id, totalVolume: 480);

        final push2Session = await sessionRepository.startWorkoutSession(
          programId: programA,
          workoutTemplateId: push2,
          workoutNameSnapshot: 'Push 2',
        );
        await setRepository.addSet(
          programId: programA,
          workoutTemplateId: push2,
          workoutSessionId: push2Session.id,
          exerciseName: 'Bench Press',
          weight: 70, // heavier than Push 1's ever -> still a valid PR (global by design)
          reps: 5,
        );
        final completedPush2 = await sessionRepository.completeWorkoutSession(
          sessionId: push2Session.id,
          totalVolume: 350,
        );

        final cubit = SessionExerciseCubit(repository: setRepository, sessionRepository: sessionRepository);
        final result = await cubit.buildCompletionSummary(completedPush2);

        // No previous Push 2 session exists yet — Push 1's session must
        // never be picked up as "previous" for the progress comparison.
        expect(result.progressSummary.hasPreviousSession, isFalse);
        expect(result.progressSummary.exerciseResults.single.trend, equals(PerformanceTrend.newExercise));

        // But the PR check is correctly global: 70kg beats Push 1's 60kg.
        final weightPr = result.personalRecords.firstWhere((r) => r.type == PersonalRecordType.heaviestWeight);
        expect(weightPr.previousBest, equals(60));
        expect(weightPr.newBest, equals(70));

        await cubit.close();
      },
    );
  });

  group('exercise-level notes (Phase 18)', () {
    test('addSet stores a trimmed note on the resulting ExerciseSet', () async {
      final session = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );

      final set = await setRepository.addSet(
        programId: programA,
        workoutTemplateId: push1,
        workoutSessionId: session.id,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
        notes: '  felt easy  ',
      );

      expect(set.notes, equals('felt easy'));
    });

    test('omitting notes leaves it null, exactly like every legacy set before this phase', () async {
      final session = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );

      final set = await setRepository.addSet(
        programId: programA,
        workoutTemplateId: push1,
        workoutSessionId: session.id,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );

      expect(set.notes, isNull);
    });

    test('an empty or whitespace-only note is normalized to null', () async {
      final session = await sessionRepository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );

      final set = await setRepository.addSet(
        programId: programA,
        workoutTemplateId: push1,
        workoutSessionId: session.id,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
        notes: '   ',
      );

      expect(set.notes, isNull);
    });
  });
}
