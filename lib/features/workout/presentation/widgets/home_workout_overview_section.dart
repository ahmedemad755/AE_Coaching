import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/domain/services/home_workout_overview_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/home_workout_overview_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/active_workout_session_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_program_details_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_template_history_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

const Color _blue = Color(0xff2f80ed);
const Color _dark = Color(0xff202936);
const Color _muted = Color(0xff7d8792);

String _fmtVolume(double value) => value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);

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
  const HomeWorkoutOverviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<HomeWorkoutOverviewCubit, HomeWorkoutOverviewState>(
      builder: (context, state) {
        if (state is HomeWorkoutOverviewError) {
          return Center(
            child: Text(state.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          );
        }
        if (state is! HomeWorkoutOverviewLoaded) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        final overview = state.overview;
        return RefreshIndicator(
          onRefresh: () => context.read<HomeWorkoutOverviewCubit>().loadOverview(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
            children: [
              if (overview.activeSession != null) _ActiveSessionCard(session: overview.activeSession!),
              if (overview.activeSession != null) const SizedBox(height: 14),
              if (overview.activeProgram != null)
                _ActiveProgramCard(summary: overview.activeProgram!)
              else
                _NoActiveProgramCard(),
              const SizedBox(height: 18),
              Text(
                l10n.homeRecentWorkoutsTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (overview.recentSessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    l10n.homeNoRecentWorkoutsBody,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                )
              else
                for (final session in overview.recentSessions) _RecentSessionCard(summary: session),
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
    final elapsed = DateTime.now().difference(session.startedAt);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 9))],
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeWorkoutInProgressLabel,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11),
                ),
                Text(
                  session.workoutNameSnapshot,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                ),
                Text(
                  l10n.homeStartedAgoLabel(_fmtAgo(elapsed, l10n)),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(
              context,
              AppNavigator.activeWorkoutSession,
              arguments: ActiveWorkoutSessionArgs(session: session),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _blue),
            child: Text(l10n.resumeWorkoutButton, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _ActiveProgramCard extends StatelessWidget {
  final HomeActiveProgramSummary summary;
  const _ActiveProgramCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.homeCurrentProgramLabel, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(summary.program.name, style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 10),
          Text(l10n.thisWeekTitle, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
          Text(
            l10n.homeWorkoutsCompletedThisWeekLabel(summary.sessionsCompletedThisWeek),
            style: const TextStyle(color: _dark, fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppNavigator.workoutProgramDetails,
                arguments: WorkoutProgramDetailsArgs(program: summary.program),
              ),
              child: Text(l10n.homeOpenProgramButton),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoActiveProgramCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.homeNoActiveProgramTitle, style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 4),
          Text(l10n.homeNoActiveProgramBody, style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, AppNavigator.workoutPrograms),
              child: Text(l10n.homeOpenProgramButton),
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
                    session.workoutNameSnapshot,
                    style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                Text(
                  DateFormat.yMMMd().format(session.date),
                  style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text(l10n.homeExerciseCountLabel(summary.exerciseCount), style: const TextStyle(color: _muted, fontSize: 12)),
                Text(l10n.homeSetCountLabel(summary.setCount), style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.homeTotalVolumeLabel(_fmtVolume(session.totalVolume)),
              style: const TextStyle(color: _dark, fontWeight: FontWeight.w700, fontSize: 13),
            ),
            if (_expanded && summary.exerciseNames.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(summary.exerciseNames.join(' • '), style: const TextStyle(color: _muted, fontSize: 12)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (summary.exerciseNames.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? l10n.homeHideExercisesButton : l10n.homeShowExercisesButton),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: summary.template == null
                      ? null
                      : () => Navigator.pushNamed(
                            context,
                            AppNavigator.workoutTemplateHistory,
                            arguments: WorkoutTemplateHistoryArgs(template: summary.template!),
                          ),
                  style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
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
