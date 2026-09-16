import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
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

String _fmtVolume(double value) => value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);

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
  State<WorkoutTemplateHistoryScreen> createState() => _WorkoutTemplateHistoryScreenState();
}

class _WorkoutTemplateHistoryScreenState extends State<WorkoutTemplateHistoryScreen> {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  void initState() {
    super.initState();
    context.read<WorkoutHistoryCubit>().loadHistory(widget.template.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xfff5f9fc),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Text(l10n.workoutHistoryTitle(widget.template.name)),
      ),
      body: BlocBuilder<WorkoutHistoryCubit, WorkoutHistoryState>(
        builder: (context, state) {
          if (state is WorkoutHistoryError) {
            return Center(child: Text(state.message, style: const TextStyle(color: Colors.redAccent)));
          }
          if (state is! WorkoutHistoryLoaded) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          if (state.sessions.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.history, color: _blue, size: 40),
                const SizedBox(height: 14),
                Text(
                  l10n.noSessionsYetTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.noSessionsYetSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            children: [
              for (final session in state.sessions) _SessionCard(session: session),
            ],
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final WorkoutSession session;
  const _SessionCard({required this.session});

  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);
  static const Color _green = Color(0xff2e9e5b);
  static const Color _red = Color(0xffd64545);
  static const Color _blue = Color(0xff2f80ed);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final String statusLabel;
    final Color statusColor;
    switch (session.statusValue) {
      case WorkoutSessionStatus.completed:
        statusLabel = l10n.sessionCompletedLabel;
        statusColor = _green;
        break;
      case WorkoutSessionStatus.cancelled:
        statusLabel = l10n.sessionCancelledLabel;
        statusColor = _red;
        break;
      case WorkoutSessionStatus.inProgress:
        statusLabel = l10n.sessionInProgressLabel;
        statusColor = _blue;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat.yMMMd().format(session.date),
                    style: const TextStyle(color: _dark, fontWeight: FontWeight.w800, fontSize: 15),
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
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (session.isCompleted) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${_fmtVolume(session.totalVolume)} ${l10n.kgUnit}',
                    style: const TextStyle(color: _dark, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  if (session.completedAt != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      '${l10n.sessionDurationLabel}: '
                      '${_fmtDuration(session.completedAt!.difference(session.startedAt), l10n)}',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
