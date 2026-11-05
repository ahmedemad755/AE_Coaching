import 'package:ae_coaching/core/errors/exception_message_mapper.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'workout_history_state.dart';

/// Drives [WorkoutTemplateHistoryScreen] (Phase 14): the session-card
/// history for exactly one workout day.
///
/// Read-only — this Cubit never creates, edits, or deletes a session;
/// see [WorkoutSessionCubit] for that.
class WorkoutHistoryCubit extends Cubit<WorkoutHistoryState> {
  final WorkoutSessionRepository sessionRepository;
  final SessionExerciseRepository setRepository;

  // Stage 3: see HomeWorkoutOverviewCubit.
  WorkoutHistoryCubit({
    required this.sessionRepository,
    required this.setRepository,
  })
    : super(const WorkoutHistoryInitial());

  Future<void> loadHistory(String workoutTemplateId) async {
    emit(const WorkoutHistoryLoading());
    try {
      final sessionBox = await sessionRepository.getUserBox();
      final sessions = sessionRepository
          .getSessionsForTemplate(sessionBox, workoutTemplateId)
          .where((session) => !session.isCancelled)
          .toList();
      final setsBox = await setRepository.getUserBox();
      final setsBySessionId = <String, List<ExerciseSet>>{
        for (final session in sessions)
          session.id: setRepository
              .getSetsForSession(setsBox, session.id)
              .where(
                (set) =>
                    set.programId == session.programId &&
                    set.workoutTemplateId == session.workoutTemplateId,
              )
              .toList(growable: false),
      };

      emit(
        WorkoutHistoryLoaded(
          sessions: sessions,
          setsBySessionId: setsBySessionId,
        ),
      );
    } catch (error) {
      emit(WorkoutHistoryError(mapGenericExceptionToMessage(error)));
    }
  }
}
