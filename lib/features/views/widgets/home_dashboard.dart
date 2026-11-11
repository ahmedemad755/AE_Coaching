import 'dart:ui' show ImageFilter;

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
import 'package:ae_coaching/core/widgets/entrance_animation.dart';
import 'package:ae_coaching/core/widgets/visible_data_refresher.dart';
import 'package:flutter/foundation.dart';

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
    this.programsTab,
    this.progressTab,
    this.moreTab,
    this.onTabChanged,
  });
  final String name;
  final String? photoPath;
  final VoidCallback? onImageError;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback onProgressAnalysis;
  final String? Function() currentUserId;
  final Widget volume;

  /// Bottom-bar destinations shown inside Home, so the bar stays visible.
  /// When none are given, the bar falls back to pushing the existing routes.
  final WidgetBuilder? programsTab;
  final WidgetBuilder? progressTab;
  final WidgetBuilder? moreTab;

  /// Called with the new index whenever the selected bottom tab changes.
  final ValueChanged<int>? onTabChanged;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _scrollController = ScrollController();
  bool _starting = false;
  bool _openingTemplates = false;
  int _tab = 0;

  // Persistent tabs: a tab is built the first time it is opened and then
  // stays mounted (offstage while hidden), so its State, scroll positions
  // and local UI state survive tab switches and nothing reloads just
  // because the user navigated. Tabs belong to one signed-in user: they
  // are keyed by [_tabsOwner] and rebuilt from scratch when it changes.
  final Set<int> _activated = {0};
  String _tabsOwner = '';

  // Home's overview reloads only after the data it shows changed (see
  // VisibleDataRefresher), while Home is the visible tab of the visible
  // route, instead of on every return to the Home tab.
  final _homeVisible = ValueNotifier<bool>(true);
  ValueListenable<bool>? _routeVisible;
  late final _overviewRefresher = VisibleDataRefresher(
    reload: () => context.read<HomeWorkoutOverviewCubit>().loadOverview(),
  );

  bool get _hasTabs =>
      widget.programsTab != null &&
      widget.progressTab != null &&
      widget.moreTab != null;

  @override
  void initState() {
    super.initState();
    _tabsOwner = widget.currentUserId() ?? '';
    _overviewRefresher.attachVisibility(_homeVisible);
    _watchOverviewSources(_tabsOwner);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // False while another route covers Home (for example an active
    // workout): changes made there are picked up on return.
    final routeVisible = TickerMode.getNotifier(context);
    if (!identical(routeVisible, _routeVisible)) {
      _routeVisible?.removeListener(_updateHomeVisible);
      _routeVisible = routeVisible..addListener(_updateHomeVisible);
      _updateHomeVisible();
    }
  }

  @override
  void didUpdateWidget(HomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final owner = widget.currentUserId() ?? '';
    if (owner != _tabsOwner) _onOwnerChanged(owner);
  }

  void _updateHomeVisible() =>
      _homeVisible.value = _tab == 0 && (_routeVisible?.value ?? true);

  Future<void> _watchOverviewSources(String owner) async {
    if (owner.isEmpty) return;
    try {
      final sources = await context
          .read<HomeWorkoutOverviewCubit>()
          .sourceChanges();
      if (mounted && owner == _tabsOwner) _overviewRefresher.watch(sources);
    } catch (error) {
      // No change notifications: Home still refreshes after its own
      // actions and on pull-to-refresh, exactly as before.
      debugPrint('Home overview change tracking unavailable: $error');
    }
  }

  /// The signed-in user changed under a mounted Home (for example the
  /// session was invalidated): drop every tab built for the previous user
  /// and replace Home's data, so nothing of theirs stays on screen.
  void _onOwnerChanged(String owner) {
    _tabsOwner = owner;
    _activated
      ..clear()
      ..add(0);
    _tab = 0;
    _updateHomeVisible();
    _overviewRefresher.reset();
    _watchOverviewSources(owner);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || owner != _tabsOwner) return;
      context.read<WorkoutProgramCubit>().refreshPrograms();
      context.read<HomeWorkoutOverviewCubit>().loadOverview();
    });
  }

  void _selectTab(int index) {
    if (index == _tab) {
      if (index == 0) _scrollHomeToTop();
      return;
    }
    setState(() {
      _tab = index;
      _activated.add(index);
    });
    _updateHomeVisible();
    widget.onTabChanged?.call(index);
  }

  void _scrollHomeToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _routeVisible?.removeListener(_updateHomeVisible);
    _overviewRefresher.dispose();
    _homeVisible.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPrograms() async {
    await context.read<WorkoutProgramCubit>().refreshPrograms();
    if (mounted) await context.read<HomeWorkoutOverviewCubit>().loadOverview();
  }

  Future<void> _openPrograms() async {
    if (_hasTabs) return _selectTab(1);
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
          if (_hasTabs) return _selectTab(1);
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

  void _progress() => _hasTabs
      ? _selectTab(2)
      : Navigator.pushNamed(context, AppNavigator.myProgress);

  void _more() => _hasTabs ? _selectTab(3) : widget.onProfile();

  @override
  Widget build(BuildContext context) {
    final home = _buildHome(context);
    final tabs = _hasTabs;
    return BlocListener<HomeWorkoutOverviewCubit, HomeWorkoutOverviewState>(
      // Any overview load (this Home's or a mutation-driven one elsewhere)
      // already reads the latest data, so pending changes are covered.
      listenWhen: (_, state) => state is HomeWorkoutOverviewLoading,
      listener: (_, _) => _overviewRefresher.markClean(),
      child: PopScope(
        canPop: !tabs || _tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _selectTab(0);
        },
        child: Scaffold(
          backgroundColor: HomeDashboardStyle.background(context),
          extendBody: true,
          body: tabs
              ? _AnimatedTabStack(
                  index: _tab,
                  children: [
                    home,
                    for (final (i, builder) in [
                      widget.programsTab!,
                      widget.progressTab!,
                      widget.moreTab!,
                    ].indexed)
                      // Built on first open, then kept mounted for this user.
                      if (_activated.contains(i + 1))
                        KeyedSubtree(
                          key: ValueKey('home-tab-${i + 1}-$_tabsOwner'),
                          child: KeyedSubtree(
                            key: PageStorageKey<String>(
                              'home-tab-${i + 1}-$_tabsOwner',
                            ),
                            child: Builder(builder: builder),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                  ],
                )
              : home,
          bottomNavigationBar: _BottomNavigation(
            selectedIndex: _tab,
            onSelected: (index) => switch (index) {
              0 => _selectTab(0),
              1 => _openPrograms(),
              2 => _progress(),
              _ => _more(),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
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
                  onProfile: _more,
                  onSettings: widget.onSettings,
                  onImageError: widget.onImageError,
                ).animateIn(),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
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
    );
  }
}

/// Keeps every built tab mounted and fades + slides the selected tab in from
/// the side of the tapped destination.
///
/// Hidden tabs keep their State but are offstage (not painted, no pointer
/// input, excluded from semantics), cannot take focus, and have their
/// tickers paused. Every slot keeps a fixed position in the tree, so
/// switching tabs never rebuilds a tab's subtree from scratch.
class _AnimatedTabStack extends StatefulWidget {
  const _AnimatedTabStack({required this.index, required this.children});

  static const duration = Duration(milliseconds: 300);
  static const curve = Curves.easeInOutCubic;
  final int index;
  final List<Widget> children;

  @override
  State<_AnimatedTabStack> createState() => _AnimatedTabStackState();
}

class _AnimatedTabStackState extends State<_AnimatedTabStack>
    with SingleTickerProviderStateMixin {
  static const _restingOffset = AlwaysStoppedAnimation<Offset>(Offset.zero);

  late final _controller = AnimationController(
    vsync: this,
    duration: _AnimatedTabStack.duration,
    value: 1,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: _AnimatedTabStack.curve,
  );
  double _direction = 1;

  @override
  void didUpdateWidget(_AnimatedTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _direction = widget.index > oldWidget.index ? 1 : -1;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: Offset(0.08 * _direction, 0),
      end: Offset.zero,
    ).animate(_curve);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          KeyedSubtree(
            key: ValueKey('tab-slot-$i'),
            child: Offstage(
              offstage: i != widget.index,
              child: ExcludeFocus(
                excluding: i != widget.index,
                child: TickerMode(
                  enabled: i == widget.index,
                  child: FadeTransition(
                    opacity: i == widget.index
                        ? _curve
                        : kAlwaysCompleteAnimation,
                    child: SlideTransition(
                      position: i == widget.index ? slide : _restingOffset,
                      textDirection: Directionality.of(context),
                      child: widget.children[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
                child: SizedBox(
                  width: double.infinity,
                  child: cards[i].animateIn(index: i + 1),
                ),
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
                  Expanded(child: cards[i].animateIn(index: i + 1)),
                  const SizedBox(width: 12),
                  Expanded(child: cards[i + 1].animateIn(index: i + 2)),
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

/// The app's main bottom bar. The selected pill and icon animate between tabs.
class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _duration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final muted = context.appColors.textMuted;
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    const radius = BorderRadius.all(Radius.circular(28));
    // Floating frosted-glass bar: the Scaffold extends its body behind it, so
    // page content scrolls under the blur.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scheme.surface.withValues(alpha: dark ? 0.62 : 0.72),
                      scheme.surface.withValues(alpha: dark ? 0.48 : 0.58),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: dark ? 0.14 : 0.6),
                  ),
                ),
                child: _items(context, labels, icons, scheme, muted),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _items(
    BuildContext context,
    List<String> labels,
    List<IconData> icons,
    ColorScheme scheme,
    Color muted,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selectedIndex,
                child: InkWell(
                  key: ValueKey('home-nav-$i'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelected(i),
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
                          AnimatedContainer(
                            duration: _duration,
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(
                              horizontal: i == selectedIndex ? 18 : 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(
                                alpha: i == selectedIndex ? 0.16 : 0,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: AnimatedScale(
                              duration: _duration,
                              curve: Curves.easeOutBack,
                              scale: i == selectedIndex ? 1.12 : 1,
                              child: TweenAnimationBuilder<Color?>(
                                duration: _duration,
                                tween: ColorTween(
                                  end: i == selectedIndex
                                      ? scheme.primary
                                      : muted,
                                ),
                                builder: (context, color, _) =>
                                    Icon(icons[i], color: color, size: 26),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: _duration,
                            textAlign: TextAlign.center,
                            style:
                                (Theme.of(context).textTheme.labelMedium ??
                                        const TextStyle())
                                    .copyWith(
                                      color: i == selectedIndex
                                          ? scheme.primary
                                          : muted,
                                      fontWeight: i == selectedIndex
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                            child: Text(labels[i]),
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
    );
  }
}
