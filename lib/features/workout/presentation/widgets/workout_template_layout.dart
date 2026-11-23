import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/cardio_activity_visuals.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_exercise_targets_dialog.dart';
import 'package:flutter/material.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';

/// Logical pixels shared by the template browser, preview and customization UI.
abstract final class WorkoutTemplateSpacing {
  static const double screen = 16;
  static const double programCard = 16;
  static const double variant = 8;
  static const double dayCard = 14;
  static const double exercise = 8;
  static const double cardPadding = 16;
  static const double section = 24;
  static const double heading = 12;
  static const double nameToTargets = 6;
  static const double tapTarget = 48;
}

/// Content can grow vertically for long names and localized target summaries.
/// The enclosing ListTile keeps selection/editing semantics and controls.
class WorkoutTemplateExerciseContent extends StatelessWidget {
  final WorkoutTemplateExerciseAssignment assignment;
  const WorkoutTemplateExerciseContent({super.key, required this.assignment});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        assignment.exerciseNameSnapshot,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (assignment.type == ActivityType.cardio) ...[
        const SizedBox(height: WorkoutTemplateSpacing.nameToTargets),
        _CardioSummary(assignment: assignment),
      ] else if (assignment.hasTargets) ...[
        const SizedBox(height: WorkoutTemplateSpacing.nameToTargets),
        ExerciseTargetsSummary(assignment: assignment),
      ],
      if (assignment.referenceType == 'builtIn' &&
          assignment.exerciseId.startsWith('ex_')) ...[
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.repdbLegacyReference,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ],
  );
}

/// "Cardio · Countdown · 20 min" (just "Cardio" without a readable plan).
class _CardioSummary extends StatelessWidget {
  const _CardioSummary({required this.assignment});
  final WorkoutTemplateExerciseAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final plan = assignment.cardio;
    final theme = Theme.of(context);
    return Text(
      plan == null
          ? l10n.activityTypeCardio
          : '${l10n.activityTypeCardio} · ${cardioPlanSummary(l10n, plan)}',
      key: ValueKey('cardio-summary-${assignment.assignmentId}'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
