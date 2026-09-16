import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/services/home_workout_overview_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'home_workout_overview_state.dart';

/// Drives the redesigned Home workout section — the active session (if
/// any), the active program's real "this week" count, and the most
/// recent completed sessions as a global activity feed.
///
/// This Cubit (and the pure [HomeWorkoutOverviewService] it delegates
/// to) is the ONLY place this data is assembled — `hom.dart` never
/// touches a Hive box or repository directly for this section, only
/// renders whatever state this Cubit emits. Read-only: it never
/// creates, edits, or deletes a program/template/session/set.
class HomeWorkoutOverviewCubit extends Cubit<HomeWorkoutOverviewState> {
  final WorkoutSessionRepository sessionRepository;
  final WorkoutProgramRepository programRepository;
  final WorkoutTemplateRepository templateRepository;
  final SessionExerciseRepository setRepository;
  final HomeWorkoutOverviewService service;

  HomeWorkoutOverviewCubit({
    WorkoutSessionRepository? sessionRepository,
    WorkoutProgramRepository? programRepository,
    WorkoutTemplateRepository? templateRepository,
    SessionExerciseRepository? setRepository,
    HomeWorkoutOverviewService? service,
  })  : sessionRepository = sessionRepository ?? WorkoutSessionRepository(),
        programRepository = programRepository ?? WorkoutProgramRepository(),
        templateRepository = templateRepository ?? WorkoutTemplateRepository(),
        setRepository = setRepository ?? SessionExerciseRepository(),
        service = service ?? const HomeWorkoutOverviewService(),
        super(const HomeWorkoutOverviewInitial());

  Future<void> loadOverview() async {
    emit(const HomeWorkoutOverviewLoading());
    try {
      final sessionBox = await sessionRepository.getUserBox();
      final activeSession = sessionRepository.getActiveSession(sessionBox);

      final programBox = await programRepository.getUserBox();
      final activeProgram = programRepository.getActiveProgram(programBox);

      final activeProgramCompletedSessions = activeProgram == null
          ? const <WorkoutSession>[]
          : sessionRepository.getCompletedSessionsForProgram(sessionBox, activeProgram.id);

      final allCompletedSessions = sessionRepository.getAllCompletedSessions(sessionBox);

      final templateBox = await templateRepository.getUserBox();
      final setBox = await setRepository.getUserBox();

      final templatesByTemplateId = <String, WorkoutTemplate>{};
      final setsBySessionId = <String, List<ExerciseSet>>{};
      for (final session in allCompletedSessions) {
        final template = templateRepository.getTemplateById(templateBox, session.workoutTemplateId);
        if (template != null) templatesByTemplateId[session.workoutTemplateId] = template;
        setsBySessionId[session.id] = setRepository.getSetsForSession(setBox, session.id);
      }

      final overview = service.build(
        now: DateTime.now(),
        activeSession: activeSession,
        activeProgram: activeProgram,
        activeProgramCompletedSessions: activeProgramCompletedSessions,
        allCompletedSessions: allCompletedSessions,
        templatesByTemplateId: templatesByTemplateId,
        setsBySessionId: setsBySessionId,
      );

      emit(HomeWorkoutOverviewLoaded(overview));
    } catch (error) {
      emit(HomeWorkoutOverviewError(error.toString()));
    }
  }
}
