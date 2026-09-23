import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_exceptions.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'workout_session_state.dart';

/// App-wide Cubit for the single active workout session — registered
/// as a GetIt singleton (not a factory) since "is a workout currently
/// active" is a cross-cutting concern shared by the Programs hub, the
/// Workout Days screen, and the active-session screen itself; all of
/// them must observe the exact same Cubit instance to stay in sync.
///
/// Never creates a second inProgress session silently — see
/// [startWorkout].
class WorkoutSessionCubit extends Cubit<WorkoutSessionState> {
  final WorkoutSessionRepository repository;

  // Stage 3: see HomeWorkoutOverviewCubit.
  WorkoutSessionCubit({required this.repository})
    : super(const WorkoutSessionInitial());

  /// Checks whether an inProgress session already exists. Safe to call
  /// repeatedly (e.g. every time the Programs hub is opened) — this is
  /// what makes an active session "survive" app restart: Hive already
  /// persisted it, this just re-reads it.
  Future<void> checkActiveSession() async {
    emit(const WorkoutSessionLoading(operation: WorkoutSessionOperation.load));
    try {
      final box = await repository.getUserBox();
      final active = repository.getActiveSession(box);
      emit(active != null ? WorkoutSessionActive(session: active) : const WorkoutSessionNone());
    } catch (error) {
      emit(WorkoutSessionError(operation: WorkoutSessionOperation.load, message: _mapExceptionToMessage(error)));
    }
  }

  /// Starts a new session. If one is already inProgress, this never
  /// silently creates a second one — it emits [WorkoutSessionConflict]
  /// carrying the existing session so the caller can offer "Resume".
  Future<void> startWorkout({
    required String programId,
    required String workoutTemplateId,
    required String workoutNameSnapshot,
  }) async {
    emit(const WorkoutSessionLoading(operation: WorkoutSessionOperation.start));
    try {
      final session = await repository.startWorkoutSession(
        programId: programId,
        workoutTemplateId: workoutTemplateId,
        workoutNameSnapshot: workoutNameSnapshot,
      );
      emit(WorkoutSessionActive(session: session));
    } on ActiveWorkoutSessionExistsException catch (e) {
      emit(WorkoutSessionConflict(existingSession: e.existingSession));
    } catch (error) {
      emit(WorkoutSessionError(operation: WorkoutSessionOperation.start, message: _mapExceptionToMessage(error)));
    }
  }

  /// Cancels an inProgress session — only ever called from an explicit
  /// user action (a confirmed "Cancel Workout" button), never
  /// automatically.
  Future<void> cancelWorkout(String sessionId) async {
    emit(const WorkoutSessionLoading(operation: WorkoutSessionOperation.cancel));
    try {
      await repository.cancelWorkoutSession(sessionId);
      emit(const WorkoutSessionNone());
    } catch (error) {
      emit(WorkoutSessionError(operation: WorkoutSessionOperation.cancel, message: _mapExceptionToMessage(error)));
    }
  }

  /// Completes an inProgress session with the caller-computed
  /// [totalVolume] (summed from that session's linked ExerciseSets —
  /// see [SessionExerciseRepository]/[SessionExerciseLoaded]; this
  /// Cubit never touches ExerciseSet storage itself). Emits
  /// [WorkoutSessionNone] on success — same terminal state as
  /// [cancelWorkout], since neither leaves a session active — and
  /// [WorkoutSessionError] on failure so the caller can keep the
  /// screen open and show the error instead of navigating away.
  ///
  /// Returns the completed [WorkoutSession] (with its final
  /// `completedAt`/`totalVolume`/`previousSessionId`) on success, or
  /// `null` on failure — Phase 13's completion summary needs the
  /// finished record itself, not just a "did it work" signal.
  Future<WorkoutSession?> finishWorkout({required String sessionId, required double totalVolume}) async {
    emit(const WorkoutSessionLoading(operation: WorkoutSessionOperation.finish));
    try {
      final completed = await repository.completeWorkoutSession(sessionId: sessionId, totalVolume: totalVolume);
      emit(const WorkoutSessionNone());
      return completed;
    } catch (error) {
      emit(WorkoutSessionError(operation: WorkoutSessionOperation.finish, message: _mapExceptionToMessage(error)));
      return null;
    }
  }

  /// Sets or clears the session-level note (Phase 18). Deliberately
  /// never `emit`s a new [WorkoutSessionState] — this Cubit is a
  /// shared app-wide SINGLETON that the Programs hub and Workout Days
  /// screen also listen to for session-lifecycle events (Active/
  /// Conflict/Error) to drive navigation and dialogs; a note edit is
  /// not a lifecycle event; emitting one here would risk misfiring
  /// those unrelated listeners on whichever other screen happens to be
  /// mounted at the time. The caller (the active session screen) awaits
  /// this directly and handles its own success/failure feedback.
  Future<WorkoutSession> updateSessionNote({required String sessionId, required String? note}) {
    return repository.updateSessionNote(sessionId: sessionId, note: note);
  }

  /// Resets back to [WorkoutSessionInitial] (Phase 21 audit finding).
  ///
  /// This Cubit is a GetIt `registerLazySingleton` — one instance for
  /// the entire app process lifetime, deliberately, so every screen
  /// observing "is a workout active" stays in sync (see the class
  /// docs). That means its in-memory `state` is NOT inherently scoped
  /// to whichever user is currently signed in: every read/write it
  /// triggers is correctly re-scoped per-uid at the repository/Hive
  /// layer, but the Cubit's own last-emitted `state` object (e.g. a
  /// `WorkoutSessionActive` holding a specific session) would
  /// otherwise persist across a logout, and could be shown — briefly,
  /// until the next explicit [checkActiveSession] call — to a
  /// DIFFERENT user who logs in afterward in the same app process.
  /// Call this on sign-out to close that window. No Hive/Firestore
  /// data is ever at risk either way (this only affects an in-memory
  /// Dart object), but this keeps the UI honest immediately rather
  /// than "eventually, once something else happens to re-check".
  void reset() {
    if (state is! WorkoutSessionInitial) emit(const WorkoutSessionInitial());
  }

  String _mapExceptionToMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
