import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';

/// Coordinates a real, permanent, cascading delete across the
/// Program → Template → Session → ExerciseSet hierarchy.
///
/// [WorkoutProgramRepository.deleteProgram], [WorkoutTemplateRepository.deleteTemplate],
/// and [WorkoutSessionRepository.deleteSession] each remove ONLY their
/// own record on purpose — calling any of them alone on a record that
/// still has children would silently orphan those children (still in
/// storage, but unreachable from any screen). This class is the ONE
/// place that safely composes all four repositories to delete a whole
/// branch at once, always bottom-up (sets → sessions → template →
/// program) so a failure partway through never leaves a parent gone
/// while its data survives, orphaned.
///
/// This is a deliberate, explicit, user-requested action (via a
/// confirmation dialog in the UI) — not a migration and not automatic;
/// it never runs on its own. [archiveProgram]/[archiveTemplate] remain
/// the normal, non-destructive "I'm done with this" actions.
class WorkoutCascadeDeletionService {
  final WorkoutProgramRepository programRepository;
  final WorkoutTemplateRepository templateRepository;
  final WorkoutSessionRepository sessionRepository;
  final SessionExerciseRepository setRepository;

  WorkoutCascadeDeletionService({
    WorkoutProgramRepository? programRepository,
    WorkoutTemplateRepository? templateRepository,
    WorkoutSessionRepository? sessionRepository,
    SessionExerciseRepository? setRepository,
  })  : programRepository = programRepository ?? WorkoutProgramRepository(),
        templateRepository = templateRepository ?? WorkoutTemplateRepository(),
        sessionRepository = sessionRepository ?? WorkoutSessionRepository(),
        setRepository = setRepository ?? SessionExerciseRepository();

  /// Deletes [templateId] and everything under it: every
  /// [WorkoutSession] for this exact template (a templateId already
  /// uniquely identifies one workout day, so no programId scoping is
  /// needed here — see [WorkoutSessionRepository.getSessionsForTemplate]),
  /// and every ExerciseSet linked to each of those sessions.
  Future<void> deleteTemplateCascade(String templateId) async {
    final sessionBox = await sessionRepository.getUserBox();
    final setBox = await setRepository.getUserBox();

    final sessions = sessionRepository.getSessionsForTemplate(sessionBox, templateId);
    for (final session in sessions) {
      final sets = setRepository.getSetsForSession(setBox, session.id);
      for (final set in sets) {
        await setRepository.deleteSet(set);
      }
      await sessionRepository.deleteSession(session.id);
    }

    await templateRepository.deleteTemplate(templateId);
  }

  /// Deletes [programId] and everything under it: every workout day
  /// template belonging to it — INCLUDING archived ones, since an
  /// archived template is hidden, not gone, and must not be left
  /// orphaned — and, for each, everything [deleteTemplateCascade]
  /// deletes.
  Future<void> deleteProgramCascade(String programId) async {
    final templateBox = await templateRepository.getUserBox();
    final templates = templateRepository.getTemplatesForProgram(
      templateBox,
      programId,
      includeArchived: true,
    );

    for (final template in templates) {
      await deleteTemplateCascade(template.id);
    }

    await programRepository.deleteProgram(programId);
  }
}
