import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/domain/services/personal_record_detection_service.dart';
import 'package:ae_coaching/features/workout/domain/services/workout_progress_comparison_service.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Display data is assembled only after the completed session is persisted.
class WorkoutCompletionSummaryArgs {
  final WorkoutSession session;
  final int recordedExerciseCount;
  final int validSetCount;
  final WorkoutProgressSummary progressSummary;
  final List<PersonalRecordResult> personalRecords;

  const WorkoutCompletionSummaryArgs({
    required this.session,
    required this.recordedExerciseCount,
    required this.validSetCount,
    required this.progressSummary,
    required this.personalRecords,
  });
}

String _fmt(double value) =>
    value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);

/// One completion dialog keeps the celebration, persisted metrics, and the
/// existing PR/progress results together without a second summary screen.
class WorkoutCompletionSummaryScreen extends StatelessWidget {
  final WorkoutCompletionSummaryArgs args;

  const WorkoutCompletionSummaryScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final summary = args.progressSummary;
    final completedAt = args.session.completedAt;
    final elapsed = args.session.isCompleted && completedAt != null
        ? completedAt.difference(args.session.startedAt)
        : null;
    final duration = elapsed == null || elapsed.isNegative
        ? null
        : l10n.completionDurationMinutes(elapsed.inMinutes);
    final volume = args.session.totalVolume;
    final hasVolume =
        args.session.isCompleted && volume.isFinite && volume >= 0;
    final volumeDelta = summary.volumeDeltaPercent;

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.celebration_rounded,
                    color: colors.warning,
                    size: 29,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  l10n.workoutCelebrationHeading,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.workoutCelebrationSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  args.session.workoutNameSnapshot,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CompletionMetric(
                          width: width,
                          label: l10n.completionExercisesLabel,
                          value: '${args.recordedExerciseCount}',
                        ),
                        _CompletionMetric(
                          width: width,
                          label: l10n.completionSetsLabel,
                          value: '${args.validSetCount}',
                        ),
                        if (hasVolume)
                          _CompletionMetric(
                            width: width,
                            label: l10n.completionVolumeLabel,
                            value: '${_fmt(volume)} ${l10n.kgUnit}',
                            detail: volumeDelta == null
                                ? null
                                : '${volumeDelta >= 0 ? '+' : ''}${_fmt(volumeDelta)}%',
                          ),
                        if (duration != null)
                          _CompletionMetric(
                            width: width,
                            label: l10n.workoutDurationLabel,
                            value: duration,
                          ),
                      ],
                    );
                  },
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (args.personalRecords.isNotEmpty) ...[
                        Text(
                          l10n.newPersonalRecordsLabel,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final record in args.personalRecords)
                          _PersonalRecordTile(record: record),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        l10n.sinceLastTimeLabel,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!summary.hasPreviousSession)
                        Text(
                          l10n.noPreviousSessionBody,
                          style: TextStyle(color: colors.textMuted),
                        )
                      else if (summary.exerciseResults.isEmpty)
                        Text(
                          l10n.noExercisesLoggedYetBody,
                          style: TextStyle(color: colors.textMuted),
                        )
                      else
                        for (final result in summary.exerciseResults)
                          _ExerciseComparisonTile(result: result),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil(AppNavigator.home, (_) => false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      l10n.backToHomeButton,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionMetric extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final String? detail;

  const _CompletionMetric({
    required this.width,
    required this.label,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      width: width,
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalRecordTile extends StatelessWidget {
  final PersonalRecordResult record;
  const _PersonalRecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String body;
    if (record.previousBest <= 0) {
      body = l10n.firstTimePrBody(record.exerciseName);
    } else if (record.type == PersonalRecordType.heaviestWeight) {
      body = l10n.heaviestWeightPrBody(
        record.exerciseName,
        _fmt(record.newBest),
        _fmt(record.previousBest),
      );
    } else {
      body = l10n.highestSetVolumePrBody(
        record.exerciseName,
        _fmt(record.recordSet.weight),
        record.recordSet.reps,
      );
    }

    return Card(
      color: context.appColors.warning.withValues(alpha: 0.16),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            Icon(Icons.emoji_events, color: context.appColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                body,
                style: TextStyle(color: context.appColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseComparisonTile extends StatelessWidget {
  final ExerciseProgressResult result;
  const _ExerciseComparisonTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final String trendLabel;
    final Color trendColor;
    switch (result.trend) {
      case PerformanceTrend.improved:
        trendLabel = l10n.exerciseImprovedLabel;
        trendColor = colors.success;
        break;
      case PerformanceTrend.declined:
        trendLabel = l10n.exerciseDeclinedLabel;
        trendColor = colors.error;
        break;
      case PerformanceTrend.maintained:
        trendLabel = l10n.exerciseMaintainedLabel;
        trendColor = colors.textMuted;
        break;
      case PerformanceTrend.newExercise:
        trendLabel = l10n.exerciseNewLabel;
        trendColor = Theme.of(context).colorScheme.primary;
        break;
    }

    final volumeText = result.previousVolume != null
        ? l10n.currentVsPreviousVolumeLabel(
            _fmt(result.currentVolume),
            _fmt(result.previousVolume!),
          )
        : '${_fmt(result.currentVolume)} ${l10n.kgUnit}';

    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.exerciseName,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    volumeText,
                    style: TextStyle(color: colors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trendLabel,
                style: TextStyle(
                  color: trendColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
