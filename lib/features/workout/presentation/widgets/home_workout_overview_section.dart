import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/domain/services/home_workout_overview_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/home_workout_overview_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/active_workout_session_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_template_history_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/home_workout_plans_section.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

String _fmtVolume(double value) =>
    value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);

String _fmtAgo(Duration d, AppLocalizations l10n) {
  if (d.inMinutes < 1) return l10n.durationSecondsOnlyLabel(d.inSeconds);
  if (d.inHours < 1) return l10n.durationMinutesOnlyLabel(d.inMinutes);
  return l10n.durationHoursMinutesLabel(d.inHours, d.inMinutes.remainder(60));
}

/// The redesigned Home workout section (replaces the old flat
/// exercise-card list): the active session banner (if any), the
/// active program's real "this week" count, and the most recent
/// completed sessions as session-level cards — never a per-exercise
/// card again.
///
/// Purely a consumer of [HomeWorkoutOverviewCubit]'s prepared state —
/// no business logic, no Hive access, nothing computed here beyond
/// simple string formatting. `hom.dart` only has to drop this widget
/// in and provide the Cubit.
class HomeWorkoutOverviewSection extends StatelessWidget {
  const HomeWorkoutOverviewSection({
    super.key,
    this.header,
    this.afterPlans,
    this.volume,
    this.onExploreTemplates,
    this.controller,
  });

  final Widget? header;
  final Widget? afterPlans;
  final Widget? volume;
  final VoidCallback? onExploreTemplates;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return BlocBuilder<HomeWorkoutOverviewCubit, HomeWorkoutOverviewState>(
      builder: (context, state) {
        final overview = state is HomeWorkoutOverviewLoaded
            ? state.overview
            : null;
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait<void>([
              context.read<HomeWorkoutOverviewCubit>().loadOverview(),
              context.read<WorkoutProgramCubit>().loadPrograms(),
            ]);
          },
          child: ListView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (header != null) ...[header!, const SizedBox(height: 24)],
              if (overview?.activeSession != null)
                _ActiveSessionCard(session: overview!.activeSession!),
              if (overview?.activeSession != null) const SizedBox(height: 14),
              HomeWorkoutPlansSection(
                activeProgramSummary: overview?.activeProgram,
                onExploreTemplates: onExploreTemplates,
                onProgramsChanged: () =>
                    context.read<HomeWorkoutOverviewCubit>().loadOverview(),
              ),
              if (afterPlans != null) ...[
                const SizedBox(height: 24),
                afterPlans!,
              ],
              if (volume != null) ...[const SizedBox(height: 24), volume!],
              const SizedBox(height: 24),
              Text(
                l10n.homeRecentWorkoutsTitle,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              if (state is HomeWorkoutOverviewError) ...[
                Text(state.message, style: TextStyle(color: colors.textMuted)),
                TextButton.icon(
                  onPressed: context
                      .read<HomeWorkoutOverviewCubit>()
                      .loadOverview,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
              ] else if (overview == null)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (overview.recentSessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    l10n.homeNoRecentWorkoutsBody,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                for (final session in overview.recentSessions)
                  _RecentSessionCard(summary: session),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  final WorkoutSession session;
  const _ActiveSessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final elapsed = DateTime.now().difference(session.startedAt);
    return Container(
      key: ValueKey('home-active-session-${session.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.timer_outlined, color: scheme.onPrimary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeWorkoutInProgressLabel,
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      session.workoutNameSnapshot,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      l10n.homeStartedAgoLabel(_fmtAgo(elapsed, l10n)),
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppNavigator.activeWorkoutSession,
                arguments: ActiveWorkoutSessionArgs(session: session),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: scheme.surface,
                foregroundColor: scheme.primary,
              ),
              child: Text(
                l10n.resumeWorkoutButton,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSessionCard extends StatefulWidget {
  final HomeSessionSummary summary;
  const _RecentSessionCard({required this.summary});

  @override
  State<_RecentSessionCard> createState() => _RecentSessionCardState();
}

class _RecentSessionCardState extends State<_RecentSessionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summary = widget.summary;
    final session = summary.session;
    final colors = context.appColors;

    return Card(
      key: ValueKey('home-recent-session-${session.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.workoutNameSnapshot,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat.yMMMd().format(session.date),
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text(
                  l10n.homeExerciseCountLabel(summary.exerciseCount),
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
                Text(
                  l10n.homeSetCountLabel(summary.setCount),
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.homeTotalVolumeLabel(_fmtVolume(session.totalVolume)),
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (_expanded && summary.exerciseNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                summary.exerciseNames.join(' • '),
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                if (summary.exerciseNames.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded
                          ? l10n.homeHideExercisesButton
                          : l10n.homeShowExercisesButton,
                    ),
                  ),
                ElevatedButton(
                  onPressed: summary.template == null
                      ? null
                      : () => Navigator.pushNamed(
                          context,
                          AppNavigator.workoutTemplateHistory,
                          arguments: WorkoutTemplateHistoryArgs(
                            template: summary.template!,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: Text(l10n.homeViewSessionButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
