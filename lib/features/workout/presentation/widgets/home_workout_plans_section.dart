import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/views/widgets/home_dashboard_cards.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/domain/services/home_workout_overview_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_program_details_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HomeWorkoutPlansSection extends StatefulWidget {
  final HomeActiveProgramSummary? activeProgramSummary;
  final Future<void> Function()? onProgramsChanged;
  final VoidCallback? onExploreTemplates;

  const HomeWorkoutPlansSection({
    super.key,
    this.activeProgramSummary,
    this.onProgramsChanged,
    this.onExploreTemplates,
  });

  @override
  State<HomeWorkoutPlansSection> createState() =>
      _HomeWorkoutPlansSectionState();
}

class _HomeWorkoutPlansSectionState extends State<HomeWorkoutPlansSection> {
  static const int _homePlanLimit = 3;

  Box<WorkoutProgram>? _box;
  bool _isChangingActivePlan = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<WorkoutProgramCubit>();
    final state = cubit.state;
    if (state is WorkoutProgramLoaded) {
      _box = state.box;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrograms());
    }
  }

  Future<void> _loadPrograms() async {
    await context.read<WorkoutProgramCubit>().loadPrograms();
    if (mounted) await widget.onProgramsChanged?.call();
  }

  Future<void> _openPrograms() async {
    await Navigator.pushNamed(context, AppNavigator.workoutPrograms);
    if (mounted) await widget.onProgramsChanged?.call();
  }

  Future<void> _openProgram(WorkoutProgram program) async {
    await Navigator.pushNamed(
      context,
      AppNavigator.workoutProgramDetails,
      arguments: WorkoutProgramDetailsArgs(program: program),
    );
  }

  Future<void> _confirmMakeActive(
    WorkoutProgram program,
    Box<WorkoutProgram> box,
  ) async {
    if (_isChangingActivePlan) return;
    setState(() => _isChangingActivePlan = true);
    try {
      final l10n = AppLocalizations.of(context)!;
      final current = context
          .read<WorkoutProgramCubit>()
          .repository
          .getActiveProgram(box);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.makeActiveConfirmTitle),
          content: Text(
            current == null
                ? l10n.makeActiveConfirmBodyNoCurrent(program.name)
                : l10n.makeActiveConfirmBodyWithCurrent(program.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.makeActiveButton),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await context.read<WorkoutProgramCubit>().setActiveProgram(program.id);
      if (mounted) await widget.onProgramsChanged?.call();
    } finally {
      if (mounted) setState(() => _isChangingActivePlan = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.appColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;

    return BlocConsumer<WorkoutProgramCubit, WorkoutProgramState>(
      listener: (context, state) {
        if (state is WorkoutProgramLoaded && _box != state.box) {
          setState(() => _box = state.box);
        }
        if (state is WorkoutProgramError) _showError(state.message);
      },
      builder: (context, state) {
        final box = state is WorkoutProgramLoaded ? state.box : _box;
        if (box == null) {
          if (state is WorkoutProgramError) {
            return _LoadError(
              message: l10n.unableToLoadProgramsError,
              onRetry: _loadPrograms,
            );
          }
          return const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return ValueListenableBuilder<Box<WorkoutProgram>>(
          valueListenable: box.listenable(),
          builder: (context, liveBox, _) {
            final repository = context.read<WorkoutProgramCubit>().repository;
            final activeId = repository.getActiveProgram(liveBox)?.id;
            final programs = repository.getPrograms(liveBox)
              ..sort((a, b) {
                final aIsActive = a.id == activeId;
                final bIsActive = b.id == activeId;
                if (aIsActive != bIsActive) return aIsActive ? -1 : 1;
                return b.createdAt.compareTo(a.createdAt);
              });
            final visiblePrograms = programs.take(_homePlanLimit).toList();

            if (widget.onExploreTemplates != null) {
              final active = programs
                  .where((p) => p.id == activeId)
                  .firstOrNull;
              final others = visiblePrograms.where((p) => p.id != activeId);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.layers_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.activeProgramLabel,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: _openPrograms,
                        child: Text(l10n.homeViewAllPlansButton),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (active != null)
                    ActiveProgramCard(
                      key: ValueKey('home-active-program-${active.id}'),
                      program: active,
                      sessionsCompletedThisWeek:
                          widget.activeProgramSummary?.program.id == active.id
                          ? widget
                                .activeProgramSummary!
                                .sessionsCompletedThisWeek
                          : null,
                      onTap: () => _openProgram(active),
                    )
                  else
                    _EmptyPlans(
                      onCreate: widget.onExploreTemplates!,
                      body: l10n.homeNoActiveProgramBody,
                      action: l10n.workoutTemplatesTitle,
                    ),
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(l10n.homeWorkoutPlansTitle),
                      children: [
                        for (final program in others)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _HomePlanCard(
                              key: ValueKey('home-workout-plan-${program.id}'),
                              program: program,
                              isActive: false,
                              sessionsCompletedThisWeek: null,
                              isChangingActivePlan: _isChangingActivePlan,
                              onOpen: () => _openProgram(program),
                              onMakeActive: () =>
                                  _confirmMakeActive(program, liveBox),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.homeWorkoutPlansTitle,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openPrograms,
                      child: Text(l10n.homeViewAllPlansButton),
                    ),
                  ],
                ),
                if (programs.isEmpty)
                  _EmptyPlans(
                    onCreate: _openPrograms,
                    body: l10n.homeNoWorkoutPlansBody,
                    action: l10n.homeCreateWorkoutPlanButton,
                  )
                else ...[
                  if (activeId == null) ...[
                    _NoActivePlanNotice(
                      title: l10n.homeNoActiveProgramTitle,
                      body: l10n.homeNoActiveProgramBody,
                    ),
                    const SizedBox(height: 8),
                  ],
                  for (final program in visiblePrograms)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _HomePlanCard(
                        key: ValueKey('home-workout-plan-${program.id}'),
                        program: program,
                        isActive: program.id == activeId,
                        sessionsCompletedThisWeek:
                            program.id == activeId &&
                                widget.activeProgramSummary?.program.id ==
                                    program.id
                            ? widget
                                  .activeProgramSummary!
                                  .sessionsCompletedThisWeek
                            : null,
                        isChangingActivePlan: _isChangingActivePlan,
                        onOpen: () => _openProgram(program),
                        onMakeActive: () =>
                            _confirmMakeActive(program, liveBox),
                      ),
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _HomePlanCard extends StatelessWidget {
  final WorkoutProgram program;
  final bool isActive;
  final int? sessionsCompletedThisWeek;
  final bool isChangingActivePlan;
  final VoidCallback onOpen;
  final VoidCallback onMakeActive;

  const _HomePlanCard({
    super.key,
    required this.program,
    required this.isActive,
    required this.sessionsCompletedThisWeek,
    required this.isChangingActivePlan,
    required this.onOpen,
    required this.onMakeActive,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: isActive ? scheme.primary : colors.border,
        width: isActive ? 1.5 : 1,
      ),
    );

    return Material(
      key: ValueKey('home-workout-plan-surface-${program.id}'),
      color: scheme.surface,
      shape: shape,
      child: InkWell(
        onTap: onOpen,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      program.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 132),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.activeProgramLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (sessionsCompletedThisWeek != null) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.homeWorkoutsCompletedThisWeekLabel(
                    sessionsCompletedThisWeek!,
                  ),
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(l10n.homeOpenProgramButton),
                  ),
                  if (!isActive)
                    TextButton.icon(
                      onPressed: isChangingActivePlan ? null : onMakeActive,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(l10n.makeActiveButton),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoActivePlanNotice extends StatelessWidget {
  final String title;
  final String body;

  const _NoActivePlanNotice({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(body, style: TextStyle(color: colors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  final VoidCallback onCreate;
  final String body;
  final String action;

  const _EmptyPlans({
    required this.onCreate,
    required this.body,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body, style: TextStyle(color: colors.textMuted)),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(message, style: TextStyle(color: context.appColors.textMuted)),
      TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(AppLocalizations.of(context)!.retry),
      ),
    ],
  );
}
