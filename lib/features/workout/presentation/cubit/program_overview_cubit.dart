import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/services/program_weekly_overview_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'program_overview_state.dart';

/// Drives the "This Week" card on the Workout Days screen (Phase 16).
/// Read-only, and deliberately reports only real counted sessions —
/// see [ProgramWeeklyOverviewService]'s class docs for why no
/// adherence percentage is ever computed here.
class ProgramOverviewCubit extends Cubit<ProgramOverviewState> {
  final WorkoutTemplateRepository templateRepository;
  final WorkoutSessionRepository sessionRepository;
  final ProgramWeeklyOverviewService service;

  // Stage 3: see HomeWorkoutOverviewCubit.
  ProgramOverviewCubit({
    required this.templateRepository,
    required this.sessionRepository,
    ProgramWeeklyOverviewService? service,
  })  : service = service ?? const ProgramWeeklyOverviewService(),
        super(const ProgramOverviewInitial());

  Future<void> loadOverview(String programId) async {
    emit(const ProgramOverviewLoading());
    try {
      final templateBox = await templateRepository.getUserBox();
      final templates = templateRepository.getTemplatesForProgram(templateBox, programId);

      final sessionBox = await sessionRepository.getUserBox();
      final completedSessionsByTemplate = <String, List<WorkoutSession>>{
        for (final template in templates)
          template.id: sessionRepository.getCompletedSessionsForTemplate(sessionBox, template.id),
      };

      final overview = service.build(
        now: DateTime.now(),
        templates: templates,
        completedSessionsByTemplate: completedSessionsByTemplate,
      );

      emit(ProgramOverviewLoaded(overview));
    } catch (error) {
      emit(ProgramOverviewError(error.toString()));
    }
  }
}
