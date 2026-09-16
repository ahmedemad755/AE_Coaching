import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/domain/services/program_consistency_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'program_consistency_state.dart';

/// Drives the "Consistency" card on the Program Analytics screen
/// (Phase 19). Read-only; fetches every completed session across the
/// whole program (any workout day) and hands it to the pure
/// [ProgramConsistencyService].
class ProgramConsistencyCubit extends Cubit<ProgramConsistencyState> {
  final WorkoutSessionRepository sessionRepository;
  final ProgramConsistencyService service;

  ProgramConsistencyCubit({
    WorkoutSessionRepository? sessionRepository,
    ProgramConsistencyService? service,
  })  : sessionRepository = sessionRepository ?? WorkoutSessionRepository(),
        service = service ?? const ProgramConsistencyService(),
        super(const ProgramConsistencyInitial());

  Future<void> loadConsistency(String programId) async {
    emit(const ProgramConsistencyLoading());
    try {
      final box = await sessionRepository.getUserBox();
      final completedSessions = sessionRepository.getCompletedSessionsForProgram(box, programId);
      final summary = service.build(now: DateTime.now(), completedSessions: completedSessions);
      emit(ProgramConsistencyLoaded(summary));
    } catch (error) {
      emit(ProgramConsistencyError(error.toString()));
    }
  }
}
