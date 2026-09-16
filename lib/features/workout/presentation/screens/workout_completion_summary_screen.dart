import 'package:ae_coaching/features/workout/domain/services/personal_record_detection_service.dart';
import 'package:ae_coaching/features/workout/domain/services/workout_progress_comparison_service.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Route arguments for [WorkoutCompletionSummaryScreen] — built once,
/// right after a session finishes, via
/// `SessionExerciseCubit.buildCompletionSummary`.
class WorkoutCompletionSummaryArgs {
  final String workoutName;
  final WorkoutProgressSummary progressSummary;
  final List<PersonalRecordResult> personalRecords;

  const WorkoutCompletionSummaryArgs({
    required this.workoutName,
    required this.progressSummary,
    required this.personalRecords,
  });
}

String _fmt(double value) => value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);

/// Shown once, right after "Finish Workout" succeeds: total volume,
/// the "Since Last Time" per-exercise comparison (Phase 11), and any
/// new Personal Records (Phase 12). Purely a display of data computed
/// beforehand — no Cubit of its own, no storage access.
class WorkoutCompletionSummaryScreen extends StatelessWidget {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);
  static const Color _green = Color(0xff2e9e5b);
  static const Color _red = Color(0xffd64545);

  final WorkoutCompletionSummaryArgs args;

  const WorkoutCompletionSummaryScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summary = args.progressSummary;

    return Scaffold(
      backgroundColor: const Color(0xfff5f9fc),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Text(args.workoutName),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    l10n.workoutSummaryTitle,
                    style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                  const SizedBox(height: 16),
                  _TotalVolumeCard(summary: summary),
                  const SizedBox(height: 24),
                  if (args.personalRecords.isNotEmpty) ...[
                    Text(
                      l10n.newPersonalRecordsLabel,
                      style: const TextStyle(color: _dark, fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    for (final pr in args.personalRecords) _PersonalRecordTile(record: pr),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    l10n.sinceLastTimeLabel,
                    style: const TextStyle(color: _dark, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  if (!summary.hasPreviousSession)
                    Text(l10n.noPreviousSessionBody, style: const TextStyle(color: _muted))
                  else if (summary.exerciseResults.isEmpty)
                    Text(l10n.noExercisesLoggedYetBody, style: const TextStyle(color: _muted))
                  else
                    for (final result in summary.exerciseResults) _ExerciseComparisonTile(result: result),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(l10n.doneButton, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalVolumeCard extends StatelessWidget {
  final WorkoutProgressSummary summary;
  const _TotalVolumeCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final delta = summary.volumeDeltaPercent;
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sessionTotalVolumeLabel,
              style: const TextStyle(
                  color: WorkoutCompletionSummaryScreen._muted, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_fmt(summary.currentTotalVolume)} ${l10n.kgUnit}',
                  style: const TextStyle(
                      color: WorkoutCompletionSummaryScreen._dark, fontWeight: FontWeight.w900, fontSize: 28),
                ),
                if (delta != null) ...[
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _DeltaBadge(delta: delta),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final double delta;
  const _DeltaBadge({required this.delta});

  @override
  Widget build(BuildContext context) {
    final isPositive = delta >= 0;
    final color = isPositive ? WorkoutCompletionSummaryScreen._green : WorkoutCompletionSummaryScreen._red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(
        '${isPositive ? '+' : ''}${_fmt(delta)}%',
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
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
      color: const Color(0xfffff7e0),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: Color(0xffe0a300)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(body, style: const TextStyle(color: WorkoutCompletionSummaryScreen._dark)),
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
    final String trendLabel;
    final Color trendColor;
    switch (result.trend) {
      case PerformanceTrend.improved:
        trendLabel = l10n.exerciseImprovedLabel;
        trendColor = WorkoutCompletionSummaryScreen._green;
        break;
      case PerformanceTrend.declined:
        trendLabel = l10n.exerciseDeclinedLabel;
        trendColor = WorkoutCompletionSummaryScreen._red;
        break;
      case PerformanceTrend.maintained:
        trendLabel = l10n.exerciseMaintainedLabel;
        trendColor = WorkoutCompletionSummaryScreen._muted;
        break;
      case PerformanceTrend.newExercise:
        trendLabel = l10n.exerciseNewLabel;
        trendColor = WorkoutCompletionSummaryScreen._blue;
        break;
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.exerciseName,
                    style: const TextStyle(color: WorkoutCompletionSummaryScreen._dark, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.previousVolume != null
                        ? l10n.currentVsPreviousVolumeLabel(
                            _fmt(result.currentVolume),
                            _fmt(result.previousVolume!),
                          )
                        : '${_fmt(result.currentVolume)} ${l10n.kgUnit}',
                    style: const TextStyle(color: WorkoutCompletionSummaryScreen._muted, fontSize: 12),
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
              child: Text(trendLabel, style: TextStyle(color: trendColor, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
