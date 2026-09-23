import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_exceptions.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Hand-rolled in-memory fake — same pattern as the Program/Template
/// repository tests, no mocking package needed.
class _FakeWorkoutSessionRemoteDataSource implements WorkoutSessionRemoteDataSource {
  final Map<String, Map<String, dynamic>> store = {};

  @override
  Future<void> syncSession(String id, WorkoutSession session) async {
    store[id] = session.toJson();
  }

  @override
  Future<void> deleteSession(String id) async {
    store.remove(id);
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSessions() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

void main() {
  late Directory tempDir;
  late WorkoutSessionRepository repository;

  const programA = 'program_A';
  const programB = 'program_B';
  const push1 = 'template_push1';
  const push2 = 'template_push2';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('workout_session_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(WorkoutSessionAdapter());
    }

    repository = WorkoutSessionRepository(
      remoteDataSource: _FakeWorkoutSessionRemoteDataSource(),
      storageManager: UserStorageManager(),
      uidOverride: () => 'test-uid',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('startWorkoutSession creates an inProgress session with the given identity', () async {
    final session = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );

    expect(session.isInProgress, isTrue);
    expect(session.completedAt, isNull);
    expect(session.totalVolume, equals(0));
    expect(session.programId, equals(programA));
    expect(session.workoutTemplateId, equals(push1));
    expect(session.workoutNameSnapshot, equals('Push 1'));
  });

  test('first ever session for a template has previousSessionId == null', () async {
    final session = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );

    expect(session.previousSessionId, isNull);
  });

  test('starting a second session while one is inProgress is blocked', () async {
    final first = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );

    expect(
      () => repository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push2,
        workoutNameSnapshot: 'Push 2',
      ),
      throwsA(
        isA<ActiveWorkoutSessionExistsException>().having(
          (e) => e.existingSession.id,
          'existingSession.id',
          first.id,
        ),
      ),
    );
  });

  test('completeWorkoutSession sets completed status, completedAt, and totalVolume', () async {
    final session = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );

    final completed = await repository.completeWorkoutSession(
      sessionId: session.id,
      totalVolume: 8450,
    );

    expect(completed.isCompleted, isTrue);
    expect(completed.completedAt, isNotNull);
    expect(completed.totalVolume, equals(8450));
  });

  test('completing a session that is not inProgress throws', () async {
    final session = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    await repository.completeWorkoutSession(sessionId: session.id, totalVolume: 100);

    expect(
      () => repository.completeWorkoutSession(sessionId: session.id, totalVolume: 200),
      throwsA(isA<InvalidWorkoutSessionStateException>()),
    );
  });

  test('cancelled session remains stored (never deleted) and is not treated as previous completed', () async {
    final first = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    await repository.completeWorkoutSession(sessionId: first.id, totalVolume: 1000);

    final second = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    final cancelled = await repository.cancelWorkoutSession(second.id);

    final box = await repository.getUserBox();

    // Still stored.
    final stored = box.get(second.id);
    expect(stored, isNotNull);
    expect(stored!.isCancelled, isTrue);
    expect(cancelled.isCancelled, isTrue);

    // A brand new session for the same template must still see `first`
    // (the completed one) as previous — the cancelled one must never
    // be selected instead.
    final third = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    expect(third.previousSessionId, equals(first.id));
  });

  test('cancelling a session that is not inProgress throws', () async {
    final session = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    await repository.cancelWorkoutSession(session.id);

    expect(
      () => repository.cancelWorkoutSession(session.id),
      throwsA(isA<InvalidWorkoutSessionStateException>()),
    );
  });

  test('previousSessionId points to the previous COMPLETED session of the SAME template', () async {
    final s1 = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    await repository.completeWorkoutSession(sessionId: s1.id, totalVolume: 1000);

    final s2 = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );

    expect(s2.previousSessionId, equals(s1.id));

    final completedS2 = await repository.completeWorkoutSession(sessionId: s2.id, totalVolume: 1100);
    expect(completedS2.previousSessionId, equals(s1.id));
  });

  test('a Push 1 session never uses a Push 2 session as previousSessionId', () async {
    final push1Session = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );
    await repository.completeWorkoutSession(sessionId: push1Session.id, totalVolume: 1000);

    final push2Session = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push2,
      workoutNameSnapshot: 'Push 2',
    );
    await repository.completeWorkoutSession(sessionId: push2Session.id, totalVolume: 2000);

    // A second Push 2 session must only ever see the previous Push 2
    // session — never the completed Push 1 session, even though it's
    // more recent and in the same program.
    final secondPush2 = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push2,
      workoutNameSnapshot: 'Push 2',
    );
    expect(secondPush2.previousSessionId, equals(push2Session.id));
    expect(secondPush2.previousSessionId, isNot(equals(push1Session.id)));
  });

  test('the same template id is never confused across two different programs', () async {
    // Same conceptual workoutTemplateId value reused across two
    // programs would be a data-modeling error in real usage (Phase 2
    // guarantees a template belongs to exactly one program for life),
    // but the repository's own query still guards on programId too —
    // this proves that guard independently.
    const sharedTemplateId = 'template_shared_id';

    final sessionInA = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: sharedTemplateId,
      workoutNameSnapshot: 'Full Body',
    );
    await repository.completeWorkoutSession(sessionId: sessionInA.id, totalVolume: 500);

    final sessionInB = await repository.startWorkoutSession(
      programId: programB,
      workoutTemplateId: sharedTemplateId,
      workoutNameSnapshot: 'Full Body',
    );

    // Program B's session must not see Program A's completed session
    // as its previous one.
    expect(sessionInB.previousSessionId, isNull);
  });

  test('getActiveSession returns only the inProgress session, never completed/cancelled ones', () async {
    final box = await repository.getUserBox();

    expect(repository.getActiveSession(box), isNull);

    final session = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );

    final active = repository.getActiveSession(box);
    expect(active, isNotNull);
    expect(active!.id, equals(session.id));

    await repository.completeWorkoutSession(sessionId: session.id, totalVolume: 100);
    expect(repository.getActiveSession(box), isNull);
  });

  group('updateSessionNote (Phase 18)', () {
    test('sets a trimmed note on an inProgress session without touching any other field', () async {
      final session = await repository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );

      final updated = await repository.updateSessionNote(sessionId: session.id, note: '  Felt strong today  ');

      expect(updated.workoutNote, equals('Felt strong today'));
      expect(updated.isInProgress, isTrue);
      expect(updated.programId, equals(session.programId));
      expect(updated.workoutTemplateId, equals(session.workoutTemplateId));
      expect(updated.startedAt, equals(session.startedAt));
    });

    test('an empty or whitespace-only note is normalized to null, not an empty string', () async {
      final session = await repository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );

      final updated = await repository.updateSessionNote(sessionId: session.id, note: '   ');
      expect(updated.workoutNote, isNull);
    });

    test('a note can be set on a COMPLETED session too — it is an annotation, not a state transition', () async {
      final session = await repository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );
      final completed = await repository.completeWorkoutSession(sessionId: session.id, totalVolume: 480);

      final updated = await repository.updateSessionNote(sessionId: completed.id, note: 'PR on bench!');
      expect(updated.workoutNote, equals('PR on bench!'));
      expect(updated.isCompleted, isTrue);
      expect(updated.totalVolume, equals(480));
    });

    test('a previously-set note can be cleared back to null', () async {
      final session = await repository.startWorkoutSession(
        programId: programA,
        workoutTemplateId: push1,
        workoutNameSnapshot: 'Push 1',
      );
      await repository.updateSessionNote(sessionId: session.id, note: 'first note');

      final cleared = await repository.updateSessionNote(sessionId: session.id, note: '');
      expect(cleared.workoutNote, isNull);
    });

    test('updating the note for a session that does not exist throws', () async {
      expect(
        () => repository.updateSessionNote(sessionId: 'does-not-exist', note: 'x'),
        throwsA(isA<Exception>()),
      );
    });
  });

  test('deleteSession removes the record entirely — not cancelled, gone', () async {
    final session = await repository.startWorkoutSession(
      programId: programA,
      workoutTemplateId: push1,
      workoutNameSnapshot: 'Push 1',
    );

    await repository.deleteSession(session.id);

    final box = await repository.getUserBox();
    expect(box.get(session.id), isNull);
  });
}
