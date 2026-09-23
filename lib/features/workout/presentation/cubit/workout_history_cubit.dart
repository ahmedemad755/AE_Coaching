import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
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

  // Stage 3: see HomeWorkoutOverviewCubit.
  WorkoutHistoryCubit({required this.sessionRepository})
    : super(const WorkoutHistoryInitial());

  Future<void> loadHistory(String workoutTemplateId) async {
    emit(const WorkoutHistoryLoading());
    try {
      final sessionBox = await sessionRepository.getUserBox();
      final sessions = sessionRepository.getSessionsForTemplate(sessionBox, workoutTemplateId);

      emit(WorkoutHistoryLoaded(sessions: sessions));
    } catch (error) {
      emit(WorkoutHistoryError(error.toString()));
    }
  }
}
