import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/views/widgets/home_dashboard_cards.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/home_workout_overview_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/active_workout_session_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_program_details_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/home_workout_overview_section.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Presentation and navigation only. Existing Cubits own all workout data.
class HomeDashboard extends StatefulWidget {
  const HomeDashboard({
    super.key,
    required this.name,
    required this.onProfile,
    required this.onSettings,
    required this.onProgressAnalysis,
    required this.currentUserId,
    required this.volume,
    this.photoPath,
    this.onImageError,
  });
  final String name;
  final String? photoPath;
  final VoidCallback? onImageError;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onProgressAnalysis;
  final String? Function() currentUserId;
  final Widget volume;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _scrollController = ScrollController();
  bool _starting = false;
  bool _openingTemplates = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPrograms() async {
    await context.read<WorkoutProgramCubit>().refreshPrograms();
    if (mounted) await context.read<HomeWorkoutOverviewCubit>().loadOverview();
  }

  Future<void> _openPrograms() async {
    final owner = widget.currentUserId();
    await Navigator.pushNamed(context, AppNavigator.workoutPrograms);
    if (mounted && owner == widget.currentUserId()) await _refreshPrograms();
  }

  Future<void> _openTemplates() async {
    if (_openingTemplates) return;
    _openingTemplates = true;
    final owner = widget.currentUserId();
    try {
      final result = await Navigator.pushNamed<WorkoutTemplateImportResult>(
        context,
        AppNavigator.workoutTemplates,
      );
      if (!mounted || result == null || owner != widget.currentUserId()) return;
      await _refreshPrograms();
      if (!mounted || owner != widget.currentUserId()) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.cloudSyncIncomplete
                ? l10n.standardTemplateSavedLocally
                : l10n.standardTemplateSaved,
          ),
        ),
      );
    } finally {
      _openingTemplates = false;
    }
  }

  Future<void> _startWorkout() async {
    if (_starting) return;
    _starting = true;
    final owner = widget.currentUserId();
    try {
      final sessions = context.read<WorkoutSessionCubit>();
      // Read the existing session before choosing a day; never create one here.
      await sessions.checkActiveSession();
      if (!mounted || owner != widget.currentUserId()) return;
      final state = sessions.state;
      if (state is WorkoutSessionError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message)));
        return;
      }
      if (state is WorkoutSessionActive) {
        await Navigator.pushNamed(
          context,
          AppNavigator.activeWorkoutSession,
          arguments: ActiveWorkoutSessionArgs(session: state.session),
        );
      } else {
        // The overview may be reloading. The program Cubit's already-open box
        // is the authoritative, current account's program selection.
        final programs = context.read<WorkoutProgramCubit>();
        final programState = programs.state;
        final active = programState is WorkoutProgramLoaded
            ? programs.repository.getActiveProgram(programState.box)
            : null;
        if (active == null) {
          await Navigator.pushNamed(context, AppNavigator.workoutPrograms);
        } else {
          await Navigator.pushNamed(
            context,
            AppNavigator.workoutProgramDetails,
            arguments: WorkoutProgramDetailsArgs(program: active),
          );
        }
      }
      if (mounted && owner == widget.currentUserId()) await _refreshPrograms();
    } finally {
      _starting = false;
    }
  }

  void _progress() => Navigator.pushNamed(context, AppNavigator.myProgress);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: HomeDashboardStyle.background(context),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: HomeWorkoutOverviewSection(
              controller: _scrollController,
              onExploreTemplates: _openTemplates,
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeHeader(
                    name: widget.name,
                    photoPath: widget.photoPath,
                    onProfile: widget.onProfile,
                    onSettings: widget.onSettings,
                    onImageError: widget.onImageError,
                  ),
                  const SizedBox(height: 28),
                  _NavigationGrid(
                    cards: [
                      HomeNavigationCard(
                        key: const ValueKey('home-programs'),
                        icon: Icons.calendar_month_outlined,
                        title: l10n.myProgramsTitle,
                        subtitle: l10n.homeManagePrograms,
                        onTap: _openPrograms,
                      ),
                      HomeNavigationCard(
                        key: const ValueKey('home-templates'),
                        icon: Icons.layers_outlined,
                        title: l10n.workoutTemplatesTitle,
                        subtitle: l10n.homeExploreTemplates,
                        emphasized: true,
                        onTap: _openTemplates,
                      ),
                      HomeNavigationCard(
                        key: const ValueKey('home-start-workout'),
                        icon: Icons.fitness_center,
                        title: l10n.startWorkoutFabLabel,
                        subtitle: l10n.homeBeginSession,
                        onTap: _startWorkout,
                      ),
                      HomeNavigationCard(
                        key: const ValueKey('home-progress'),
                        icon: Icons.bar_chart_rounded,
                        title: l10n.homeProgress,
                        subtitle: l10n.homeTrackResults,
                        onTap: _progress,
                      ),
                    ],
                  ),
                ],
              ),
              afterPlans: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.bolt,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.homeQuickActions,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _QuickActions(
                    cards: [
                      HomeQuickActionCard(
                        key: const ValueKey('home-log-workout'),
                        icon: Icons.add,
                        label: l10n.homeLogWorkout,
                        onTap: _startWorkout,
                      ),
                      HomeQuickActionCard(
                        key: const ValueKey('home-body-metrics'),
                        icon: Icons.straighten,
                        label: l10n.homeBodyMetrics,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppNavigator.measurements,
                        ),
                      ),
                      HomeQuickActionCard(
                        key: const ValueKey('home-history'),
                        icon: Icons.history,
                        label: l10n.historyLabel,
                        onTap: _progress,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const ValueKey('home-progress-analysis'),
                      onPressed: widget.onProgressAnalysis,
                      icon: const Icon(Icons.analytics_outlined),
                      label: Text(l10n.progressAnalyticsTooltip),
                    ),
                  ),
                ],
              ),
              volume: widget.volume,
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomNavigation(
        onHome: () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        },
        onPrograms: _openPrograms,
        onProgress: _progress,
        onMore: widget.onProfile,
      ),
    );
  }
}

class _NavigationGrid extends StatelessWidget {
  const _NavigationGrid({required this.cards});
  final List<HomeNavigationCard> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final singleColumn =
          constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(16) > 26;
      if (singleColumn) {
        return Column(
          children: [
            for (var i = 0; i < cards.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                child: SizedBox(width: double.infinity, child: cards[i]),
              ),
          ],
        );
      }
      var cardHeight = 0.0;
      for (final card in cards) {
        final height = card.heightForWidth(
          context,
          (constraints.maxWidth - 12) / 2,
        );
        if (height > cardHeight) cardHeight = height;
      }
      return Column(
        children: [
          for (var i = 0; i < cards.length; i += 2) ...[
            if (i != 0) const SizedBox(height: 12),
            SizedBox(
              height: cardHeight.ceilToDouble(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[i]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[i + 1]),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.cards});
  final List<Widget> cards;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(16) > 24) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: cards[i],
            ),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i != 0) const SizedBox(width: 8),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

/// A single bar on Home. Other destinations use the existing route stack.
class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.onHome,
    required this.onPrograms,
    required this.onProgress,
    required this.onMore,
  });
  final VoidCallback onHome, onPrograms, onProgress, onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.homeNavigationHome,
      l10n.homeNavigationPrograms,
      l10n.homeProgress,
      l10n.homeNavigationMore,
    ];
    final icons = [
      Icons.home_rounded,
      Icons.calendar_month_outlined,
      Icons.bar_chart_rounded,
      Icons.more_horiz,
    ];
    final callbacks = [onHome, onPrograms, onProgress, onMore];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: context.appColors.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == 0,
                    child: InkWell(
                      key: ValueKey('home-nav-$i'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: callbacks[i],
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 4,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icons[i],
                                color: i == 0
                                    ? Theme.of(context).colorScheme.primary
                                    : context.appColors.textMuted,
                                size: 26,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                labels[i],
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: i == 0
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : context.appColors.textMuted,
                                      fontWeight: i == 0
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
