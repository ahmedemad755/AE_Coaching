import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/domain/services/program_analytics_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_analytics_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_consistency_cubit.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Route arguments for [ProgramAnalyticsScreen].
class ProgramAnalyticsArgs {
  final WorkoutProgram program;
  const ProgramAnalyticsArgs({required this.program});
}

String _fmt(double value) => value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);

/// Phase 15's Program → Day → Exercise analytics browser. Every
/// exercise row shown here is scoped to exactly one workout day
/// (`workoutTemplateId`) — see [ProgramAnalyticsService]'s docs for why
/// Push 1 and Push 2 can never merge here, even for exercises sharing
/// the same name.
class ProgramAnalyticsScreen extends StatefulWidget {
  final WorkoutProgram program;
  const ProgramAnalyticsScreen({super.key, required this.program});

  @override
  State<ProgramAnalyticsScreen> createState() => _ProgramAnalyticsScreenState();
}

class _ProgramAnalyticsScreenState extends State<ProgramAnalyticsScreen> {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  void initState() {
    super.initState();
    context.read<ProgramAnalyticsCubit>().loadAnalytics(widget.program.id);
    context.read<ProgramConsistencyCubit>().loadConsistency(widget.program.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xfff5f9fc),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Text(l10n.programAnalyticsTitle),
      ),
      body: BlocBuilder<ProgramAnalyticsCubit, ProgramAnalyticsState>(
        builder: (context, state) {
          if (state is ProgramAnalyticsError) {
            return Center(child: Text(state.message, style: const TextStyle(color: Colors.redAccent)));
          }
          if (state is! ProgramAnalyticsLoaded) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          final days = state.summary.days;
          final hasAnyData = days.any((d) => d.completedSessionsCount > 0);

          if (!hasAnyData) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.bar_chart, color: _blue, size: 40),
                const SizedBox(height: 14),
                Text(
                  l10n.noAnalyticsYetTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.noAnalyticsYetSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const _ConsistencyCard(),
              const SizedBox(height: 8),
              for (final day in days) _WorkoutDaySection(day: day),
            ],
          );
        },
      ),
    );
  }
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard();

  static const Color _dark = Color(0xff202936);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ProgramConsistencyCubit, ProgramConsistencyState>(
      builder: (context, state) {
        if (state is! ProgramConsistencyLoaded) return const SizedBox.shrink();
        final summary = state.summary;
        if (summary.totalCompletedSessions == 0) return const SizedBox.shrink();

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.consistencyTitle,
                  style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    _ConsistencyStat(
                      label: l10n.currentWeekStreakLabel,
                      value: l10n.weeksUnit(summary.currentWeekStreak),
                    ),
                    _ConsistencyStat(
                      label: l10n.longestWeekStreakLabel,
                      value: l10n.weeksUnit(summary.longestWeekStreak),
                    ),
                    _ConsistencyStat(
                      label: l10n.averagePerWeekLabel,
                      value: _fmt(summary.averageSessionsPerWeek),
                    ),
                    if (summary.daysSinceLastSession != null)
                      _ConsistencyStat(
                        label: l10n.daysSinceLastSessionLabel,
                        value: l10n.daysAgoLabel(summary.daysSinceLastSession!),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConsistencyStat extends StatelessWidget {
  final String label;
  final String value;
  const _ConsistencyStat({required this.label, required this.value});

  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 15)),
        Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
      ],
    );
  }
}

class _WorkoutDaySection extends StatelessWidget {
  final WorkoutDayAnalyticsSummary day;
  const _WorkoutDaySection({required this.day});

  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day.workoutTemplateName,
                  style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 17),
                ),
              ),
              if (day.completedSessionsCount > 0)
                Text(
                  l10n.sessionsLoggedLabel(day.completedSessionsCount),
                  style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700),
                ),
            ],
          ),
          if (day.completedSessionsCount > 0) ...[
            const SizedBox(height: 2),
            Text(
              '${l10n.averageVolumeLabel}: ${_fmt(day.averageSessionVolume)} ${l10n.kgUnit}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          if (day.exercises.isEmpty)
            Text(l10n.noExercisesForDayYetBody, style: const TextStyle(color: _muted, fontSize: 13))
          else
            for (final exercise in day.exercises) _ExerciseAnalyticsTile(exercise: exercise),
        ],
      ),
    );
  }
}

class _ExerciseAnalyticsTile extends StatelessWidget {
  final ExerciseAnalyticsSummary exercise;
  const _ExerciseAnalyticsTile({required this.exercise});

  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);
  static const Color _green = Color(0xff2e9e5b);
  static const Color _red = Color(0xffd64545);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final delta = exercise.overallDeltaPercent;

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
                    exercise.exerciseName,
                    style: const TextStyle(color: _dark, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.exerciseBestLatestSummary(_fmt(exercise.bestWeight), _fmt(exercise.latestVolume)),
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (delta != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (delta >= 0 ? _green : _red).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${delta >= 0 ? '+' : ''}${_fmt(delta)}%',
                  style: TextStyle(
                    color: delta >= 0 ? _green : _red,
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
