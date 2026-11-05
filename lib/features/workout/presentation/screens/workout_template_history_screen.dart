import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_history_cubit.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Route arguments for [WorkoutTemplateHistoryScreen].
class WorkoutTemplateHistoryArgs {
  final WorkoutTemplate template;
  const WorkoutTemplateHistoryArgs({required this.template});
}

String _fmtVolume(double value) =>
    value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);

String _fmtWeight(double value) =>
    value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);

String _fmtDuration(Duration d, AppLocalizations l10n) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours > 0) return l10n.durationHoursMinutesLabel(hours, minutes);
  return l10n.durationMinutesOnlyLabel(minutes);
}

/// Session-card history for exactly one workout day (Phase 14) — every
/// [WorkoutSession] recorded for this template, newest first. Never
/// mixes in another template's sessions.
class WorkoutTemplateHistoryScreen extends StatefulWidget {
  final WorkoutTemplate template;

  const WorkoutTemplateHistoryScreen({super.key, required this.template});

  @override
  State<WorkoutTemplateHistoryScreen> createState() =>
      _WorkoutTemplateHistoryScreenState();
}

class _WorkoutTemplateHistoryScreenState
    extends State<WorkoutTemplateHistoryScreen> {
  static const Color _blue = Color(0xff2f80ed);

  @override
  void initState() {
    super.initState();
    context.read<WorkoutHistoryCubit>().loadHistory(widget.template.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: isDark ? colors.canvas : _blue,
        foregroundColor: isDark ? colors.textPrimary : Colors.white,
        title: Text(l10n.workoutHistoryTitle(widget.template.name)),
      ),
      body: BlocBuilder<WorkoutHistoryCubit, WorkoutHistoryState>(
        builder: (context, state) {
          if (state is WorkoutHistoryError) {
            return Center(
              child: Text(state.message, style: TextStyle(color: colors.error)),
            );
          }
          if (state is! WorkoutHistoryLoaded) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          if (state.sessions.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                  size: 40,
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.noSessionsYetTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.noSessionsYetSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            children: [
              for (final session in state.sessions)
                _SessionCard(
                  session: session,
                  sets: state.setsBySessionId[session.id] ?? const [],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final WorkoutSession session;
  final List<ExerciseSet> sets;
  const _SessionCard({required this.session, required this.sets});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final String statusLabel;
    final Color statusColor;
    switch (session.statusValue) {
      case WorkoutSessionStatus.completed:
        statusLabel = l10n.sessionCompletedLabel;
        statusColor = colors.success;
        break;
      case WorkoutSessionStatus.cancelled:
        statusLabel = l10n.sessionCancelledLabel;
        statusColor = colors.error;
        break;
      case WorkoutSessionStatus.inProgress:
        statusLabel = l10n.sessionInProgressLabel;
        statusColor = scheme.primary;
        break;
    }

    final setsByExercise = <String, List<ExerciseSet>>{};
    for (final set in sets) {
      setsByExercise.putIfAbsent(set.exerciseName, () => []).add(set);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat.yMMMd().format(session.date),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        subtitle: session.isCompleted
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${_fmtVolume(session.totalVolume)} ${l10n.kgUnit}',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (session.completedAt != null)
                      Text(
                        '${l10n.sessionDurationLabel}: '
                        '${_fmtDuration(session.completedAt!.difference(session.startedAt), l10n)}',
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              )
            : null,
        children: [
          if (session.workoutNote?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.sessionNoteTooltip,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 18,
                        color: colors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.workoutNote!.trim(),
                          style: TextStyle(color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          for (final entry in setsByExercise.entries) ...[
            if (entry.key != setsByExercise.keys.first)
              const Divider(height: 20),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                entry.key,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (var index = 0; index < entry.value.length; index++)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 8,
                  top: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_fmtWeight(entry.value[index].weight)}${l10n.kgUnit} × ${entry.value[index].reps}',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat.Hm().format(entry.value[index].date),
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (entry.value[index].notes?.trim().isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 28,
                          top: 4,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 16,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                entry.value[index].notes!.trim(),
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
