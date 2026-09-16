import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_exceptions.dart';
import 'package:ae_coaching/features/workout/data/workout_id_generator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Data layer for [WorkoutSession] — Hive (offline-first) + Firestore
/// sync, same shape as the Program/Template repositories.
///
/// Storage:
/// - Local: `workout_sessions_$uid` Hive box, keyed by the session's
///   own `id`.
/// - Cloud: `users/{uid}/workout_sessions/{id}` (every document
///   includes `programId` + `workoutTemplateId`).
///
/// Does not touch ExerciseSet, hom.dart, or existing workout analytics
/// — no UI/Cubit wiring in this phase.
class WorkoutSessionRepository {
  final WorkoutSessionRemoteDataSource remoteDataSource;

  @visibleForTesting
  final String? Function()? uidOverride;

  WorkoutSessionRepository({
    WorkoutSessionRemoteDataSource? remoteDataSource,
    @visibleForTesting this.uidOverride,
  }) : remoteDataSource = remoteDataSource ?? WorkoutSessionRemoteDataSourceImpl();

  Future<Box<WorkoutSession>> getUserBox() async {
    final uid = uidOverride?.call() ?? FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    final boxName = 'workout_sessions_$uid';
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<WorkoutSession>(boxName);
    }

    return Hive.openBox<WorkoutSession>(boxName);
  }

  // ==================== Start / Complete / Cancel ====================

  /// Starts a new session for [workoutTemplateId] within [programId].
  ///
  /// Enforces the one-active-session rule: if an inProgress session
  /// already exists (for *any* template/program — a user trains one
  /// workout at a time), this throws
  /// [ActiveWorkoutSessionExistsException] carrying that session,
  /// rather than silently creating a second one. It is up to the
  /// caller (a future Cubit) to decide what to do with it — e.g. offer
  /// to resume.
  Future<WorkoutSession> startWorkoutSession({
    required String programId,
    required String workoutTemplateId,
    required String workoutNameSnapshot,
  }) async {
    final box = await getUserBox();

    final existingActive = getActiveSession(box);
    if (existingActive != null) {
      throw ActiveWorkoutSessionExistsException(existingActive);
    }

    final now = DateTime.now();
    final id = WorkoutIdGenerator.generate('session');
    final previous = getPreviousCompletedSession(box, programId, workoutTemplateId);

    final session = WorkoutSession(
      id: id,
      programId: programId,
      workoutTemplateId: workoutTemplateId,
      workoutNameSnapshot: workoutNameSnapshot,
      date: now,
      startedAt: now,
      completedAt: null,
      status: WorkoutSessionStatus.inProgress.value,
      totalVolume: 0,
      previousSessionId: previous?.id,
    );

    await box.put(id, session);
    await _syncSafely(id, session);
    return session;
  }

  /// Completes an inProgress session. Throws
  /// [InvalidWorkoutSessionStateException] if the session doesn't
  /// exist or isn't currently inProgress (e.g. already completed or
  /// cancelled).
  ///
  /// [totalVolume] is taken as given — this phase does not calculate it
  /// from ExerciseSet (that integration comes later, Phase 4+).
  ///
  /// [previousSessionId] is recalculated here (not just reused from
  /// start time) so the final, permanent record reflects the most
  /// accurate "previous completed session" at the moment this one
  /// actually finishes — this is the value later analytics phases will
  /// read.
  Future<WorkoutSession> completeWorkoutSession({
    required String sessionId,
    required double totalVolume,
  }) async {
    final box = await getUserBox();
    final target = box.get(sessionId);

    if (target == null) {
      throw Exception('Workout session not found.');
    }
    if (!target.isInProgress) {
      throw InvalidWorkoutSessionStateException(
        sessionId: sessionId,
        actualStatus: target.statusValue,
        reason: 'Only an inProgress session can be completed '
            '(current status: ${target.status}).',
      );
    }

    final previous = getPreviousCompletedSession(
      box,
      target.programId,
      target.workoutTemplateId,
      excludeSessionId: sessionId,
    );

    final completed = target.copyWith(
      status: WorkoutSessionStatus.completed.value,
      completedAt: DateTime.now(),
      totalVolume: totalVolume,
      previousSessionId: previous?.id,
    );
    await box.put(sessionId, completed);
    await _syncSafely(sessionId, completed);
    return completed;
  }

  /// Cancels an inProgress session. Throws
  /// [InvalidWorkoutSessionStateException] if it isn't currently
  /// inProgress. The record is preserved — never deleted — and is
  /// permanently excluded from previous-completed-session lookups.
  Future<WorkoutSession> cancelWorkoutSession(String sessionId) async {
    final box = await getUserBox();
    final target = box.get(sessionId);

    if (target == null) {
      throw Exception('Workout session not found.');
    }
    if (!target.isInProgress) {
      throw InvalidWorkoutSessionStateException(
        sessionId: sessionId,
        actualStatus: target.statusValue,
        reason: 'Only an inProgress session can be cancelled '
            '(current status: ${target.status}).',
      );
    }

    final cancelled = target.copyWith(status: WorkoutSessionStatus.cancelled.value);
    await box.put(sessionId, cancelled);
    await _syncSafely(sessionId, cancelled);
    return cancelled;
  }

  /// Deletes ONLY this session's own record (local + remote) — never
  /// its linked ExerciseSets. [cancelWorkoutSession] remains the
  /// normal, non-destructive way to end a session early; use this only
  /// as part of a full cascade delete (see
  /// `WorkoutCascadeDeletionService.deleteTemplateCascade`, which
  /// deletes every set under this session FIRST, then calls this).
  Future<void> deleteSession(String sessionId) async {
    final box = await getUserBox();
    await box.delete(sessionId);

    try {
      await remoteDataSource.deleteSession(sessionId);
    } catch (error, stackTrace) {
      debugPrint('WorkoutSession remote delete failed: $error\n$stackTrace');
      rethrow;
    }
  }

  /// Sets or clears the free-text note for a session (Phase 18) — any
  /// status, not just inProgress; a note is an annotation, not part of
  /// the start/complete/cancel state machine. [note] is trimmed and
  /// normalized to `null` when empty/whitespace-only, so clearing the
  /// text field always results in a real `null`, not a stored empty
  /// string. Built via the direct constructor (not `copyWith`, which
  /// can't null out a field — same reasoning as
  /// `WorkoutProgramRepository.setActiveProgram`).
  Future<WorkoutSession> updateSessionNote({required String sessionId, required String? note}) async {
    final box = await getUserBox();
    final target = box.get(sessionId);
    if (target == null) {
      throw Exception('Workout session not found.');
    }

    final trimmed = note?.trim();
    final normalizedNote = (trimmed == null || trimmed.isEmpty) ? null : trimmed;

    final updated = WorkoutSession(
      id: target.id,
      programId: target.programId,
      workoutTemplateId: target.workoutTemplateId,
      workoutNameSnapshot: target.workoutNameSnapshot,
      date: target.date,
      startedAt: target.startedAt,
      completedAt: target.completedAt,
      status: target.status,
      totalVolume: target.totalVolume,
      previousSessionId: target.previousSessionId,
      workoutNote: normalizedNote,
    );
    await box.put(sessionId, updated);
    await _syncSafely(sessionId, updated);
    return updated;
  }

  // ==================== Retrieval ====================

  WorkoutSession? getSessionById(Box<WorkoutSession> box, String sessionId) {
    return box.get(sessionId);
  }

  /// The single inProgress session, if any. There is only ever meant
  /// to be at most one — see [findConflictingActiveSessions] for what
  /// happens if reconciliation ever finds more.
  WorkoutSession? getActiveSession(Box<WorkoutSession> box) {
    for (final session in box.values) {
      if (session.isInProgress) return session;
    }
    return null;
  }

  /// Every session for [workoutTemplateId] regardless of status,
  /// newest first by [WorkoutSession.date].
  List<WorkoutSession> getSessionsForTemplate(Box<WorkoutSession> box, String workoutTemplateId) {
    final matches = box.values.where((s) => s.workoutTemplateId == workoutTemplateId).toList();
    matches.sort((a, b) => b.date.compareTo(a.date));
    return matches;
  }

  /// Only completed sessions for [workoutTemplateId], newest first.
  List<WorkoutSession> getCompletedSessionsForTemplate(Box<WorkoutSession> box, String workoutTemplateId) {
    final matches = box.values.where((s) => s.workoutTemplateId == workoutTemplateId && s.isCompleted).toList();
    matches.sort((a, b) => b.date.compareTo(a.date));
    return matches;
  }

  /// Every completed session anywhere in [programId], across ALL of
  /// its workout templates — unlike [getCompletedSessionsForTemplate],
  /// this is deliberately NOT scoped to one day. Used by Phase 19's
  /// program-wide consistency analytics, where "am I showing up" is a
  /// whole-program question, not a per-day one.
  List<WorkoutSession> getCompletedSessionsForProgram(Box<WorkoutSession> box, String programId) {
    final matches = box.values.where((s) => s.programId == programId && s.isCompleted).toList();
    matches.sort((a, b) => b.date.compareTo(a.date));
    return matches;
  }

  /// Every completed session across the WHOLE account — every program,
  /// every workout day. Used by the Home overview's "Recent Workouts"
  /// feed, which is deliberately a global activity feed, not scoped to
  /// one program. Newest first; ordering/limiting to "recent N" is the
  /// caller's job (see `HomeWorkoutOverviewService`).
  List<WorkoutSession> getAllCompletedSessions(Box<WorkoutSession> box) {
    final matches = box.values.where((s) => s.isCompleted).toList();
    matches.sort((a, b) => (b.completedAt ?? b.date).compareTo(a.completedAt ?? a.date));
    return matches;
  }

  /// The most recent COMPLETED session sharing both [programId] and
  /// [workoutTemplateId] — inProgress and cancelled sessions are never
  /// candidates. This is the one guard that keeps "Push 1" from ever
  /// being compared against "Push 2": they have different
  /// workoutTemplateId values, so this query simply never matches
  /// across them.
  ///
  /// [excludeSessionId] lets `completeWorkoutSession` search without
  /// matching itself.
  WorkoutSession? getPreviousCompletedSession(
    Box<WorkoutSession> box,
    String programId,
    String workoutTemplateId, {
    String? excludeSessionId,
  }) {
    final candidates = box.values
        .where((s) =>
            s.programId == programId &&
            s.workoutTemplateId == workoutTemplateId &&
            s.isCompleted &&
            s.id != excludeSessionId)
        .toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => (b.completedAt ?? b.date).compareTo(a.completedAt ?? a.date));
    return candidates.first;
  }

  /// Returns every inProgress session currently stored. Normally this
  /// list has 0 or 1 entries. See class docs / Phase report for how a
  /// 2+ result (a sync conflict) is handled.
  List<WorkoutSession> findConflictingActiveSessions(Box<WorkoutSession> box) {
    return box.values.where((s) => s.isInProgress).toList();
  }

  // ==================== Sync ====================

  /// Pulls every session stored in the cloud into the local box, then
  /// pushes up any local-only session the cloud doesn't know about yet
  /// — same merge pattern as Program/Template/Workout/Measurement sync.
  ///
  /// Conflict handling (rule 16): merging never deletes or silently
  /// "fixes" anything. If this reconciliation results in more than one
  /// inProgress session (e.g. the same account was left mid-workout on
  /// two devices), both records are kept exactly as they are. Nothing
  /// in this phase auto-cancels or auto-merges them — call
  /// [findConflictingActiveSessions] after this to detect that state;
  /// resolving it is left to a future Cubit/UI (e.g. ask the user which
  /// one to keep).
  Future<void> fetchAndSyncFromRemote(Box<WorkoutSession> box) async {
    try {
      final remoteDocs = await remoteDataSource.fetchAllRemoteSessions();
      final remoteIds = remoteDocs.map((doc) => doc.id).toSet();

      for (final doc in remoteDocs) {
        final session = WorkoutSession.fromJson(doc.data());
        await box.put(doc.id, session);
      }

      for (final localId in box.keys) {
        final localSession = box.get(localId);
        if (localSession == null || remoteIds.contains(localId)) {
          continue;
        }
        await remoteDataSource.syncSession(localId as String, localSession);
      }

      final conflicts = findConflictingActiveSessions(box);
      if (conflicts.length > 1) {
        debugPrint(
          'WorkoutSession sync found ${conflicts.length} inProgress sessions '
          '(ids: ${conflicts.map((s) => s.id).join(', ')}). Left untouched — '
          'not auto-resolved. Surface this to the user once a Cubit exists.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch and sync workout sessions from cloud: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> _syncSafely(String id, WorkoutSession session) async {
    try {
      await remoteDataSource.syncSession(id, session);
    } catch (error, stackTrace) {
      debugPrint('WorkoutSession remote sync failed: $error\n$stackTrace');
      rethrow;
    }
  }
}
