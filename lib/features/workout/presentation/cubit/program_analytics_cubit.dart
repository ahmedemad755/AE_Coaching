import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/services/program_analytics_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'program_analytics_state.dart';

/// Drives Phase 15's Program → Day → Exercise analytics screen.
/// Read-only: fetches already-stored data (non-archived templates,
/// their completed sessions, those sessions' sets) and hands it to the
/// pure [ProgramAnalyticsService] — no aggregation logic lives here.
class ProgramAnalyticsCubit extends Cubit<ProgramAnalyticsState> {
  final WorkoutTemplateRepository templateRepository;
  final WorkoutSessionRepository sessionRepository;
  final SessionExerciseRepository setRepository;
  final ProgramAnalyticsService service;

  // Stage 3: see HomeWorkoutOverviewCubit — required rather than
  // defaulted, since the zero-arg repository fallback is dead code
  // nothing exercises.
  ProgramAnalyticsCubit({
    required this.templateRepository,
    required this.sessionRepository,
    required this.setRepository,
    ProgramAnalyticsService? service,
  })  : service = service ?? const ProgramAnalyticsService(),
        super(const ProgramAnalyticsInitial());

  Future<void> loadAnalytics(String programId) async {
    emit(const ProgramAnalyticsLoading());
    try {
      final templateBox = await templateRepository.getUserBox();
      final templates = templateRepository.getTemplatesForProgram(templateBox, programId);

      final sessionBox = await sessionRepository.getUserBox();
      final setBox = await setRepository.getUserBox();

      final completedSessionsByTemplate = <String, List<WorkoutSession>>{};
      final setsBySessionId = <String, List<ExerciseSet>>{};

      for (final template in templates) {
        final completed = sessionRepository.getCompletedSessionsForTemplate(sessionBox, template.id);
        completedSessionsByTemplate[template.id] = completed;
        for (final session in completed) {
          setsBySessionId[session.id] = setRepository.getSetsForSession(setBox, session.id);
        }
      }

      final summary = service.build(
        programId: programId,
        templates: templates,
        completedSessionsByTemplate: completedSessionsByTemplate,
        setsBySessionId: setsBySessionId,
      );

      emit(ProgramAnalyticsLoaded(summary));
    } catch (error) {
      emit(ProgramAnalyticsError(error.toString()));
    }
  }
}
