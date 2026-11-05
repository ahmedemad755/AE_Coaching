import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_overview_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_template_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/active_workout_session_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/archived_workout_days_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/program_analytics_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_template_history_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/name_only_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/template_exercise_manager.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Route arguments for [WorkoutProgramDetailsScreen] — same pattern as
/// `WorkoutAnalyticsArgs`.
class WorkoutProgramDetailsArgs {
  final WorkoutProgram program;

  const WorkoutProgramDetailsArgs({required this.program});
}

/// Workout Days screen — shows reusable WorkoutTemplate cards
/// ("Push 1", "Pull 1", ...) for one program. Templates are created
/// once and reused every week; nothing here creates a new template per
/// training session. "Start Workout" (Phase 7) never silently creates
/// a second active session — see [_onSessionStateChanged].
class WorkoutProgramDetailsScreen extends StatefulWidget {
  final WorkoutProgram program;

  const WorkoutProgramDetailsScreen({super.key, required this.program});

  @override
  State<WorkoutProgramDetailsScreen> createState() =>
      _WorkoutProgramDetailsScreenState();
}

class _WorkoutProgramDetailsScreenState
    extends State<WorkoutProgramDetailsScreen> {
  static const Color _blue = Color(0xff2f80ed);

  Box<WorkoutTemplate>? _box;

  @override
  void initState() {
    super.initState();
    context.read<WorkoutTemplateCubit>().loadTemplates();
    context.read<ProgramOverviewCubit>().loadOverview(widget.program.id);
  }

  Future<void> _openCreateDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameOnlyDialog(
        title: l10n.createWorkoutDayTitle,
        hint: l10n.workoutDayNameHint,
        saveLabel: l10n.createButton,
        cancelLabel: l10n.cancel,
        emptyValueMessage: l10n.enterWorkoutDayNameValidation,
      ),
    );
    if (name != null && mounted) {
      context.read<WorkoutTemplateCubit>().createTemplate(
        programId: widget.program.id,
        name: name,
      );
    }
  }

  Future<void> _openRenameDialog(WorkoutTemplate template) async {
    final l10n = AppLocalizations.of(context)!;
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => NameOnlyDialog(
        title: l10n.renameWorkoutDayTitle,
        hint: l10n.workoutDayNameHint,
        initialValue: template.name,
        saveLabel: l10n.save,
        cancelLabel: l10n.cancel,
        emptyValueMessage: l10n.enterWorkoutDayNameValidation,
      ),
    );
    if (newName != null && mounted) {
      context.read<WorkoutTemplateCubit>().renameTemplate(
        templateId: template.id,
        newName: newName,
      );
    }
  }

  Future<void> _confirmArchive(WorkoutTemplate template) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.archiveWorkoutDayConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          l10n.archiveWorkoutDayConfirmBody(template.name),
          style: TextStyle(color: ctx.appColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.appColors.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.archiveButton),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<WorkoutTemplateCubit>().archiveTemplate(template.id);
    }
  }

  /// Real, permanent, cascading delete — every session and logged set
  /// under this workout day goes with it. Requires an explicit
  /// confirmation naming exactly what will be lost; [_confirmArchive]
  /// remains the normal, reversible action.
  Future<void> _confirmDeleteTemplate(WorkoutTemplate template) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.deleteWorkoutDayConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          l10n.deleteWorkoutDayConfirmBody(template.name),
          style: TextStyle(color: ctx.appColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.appColors.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<WorkoutTemplateCubit>().deleteTemplate(template.id);
    }
  }

  void _openArchivedWorkoutDays() {
    Navigator.pushNamed(
      context,
      AppNavigator.archivedWorkoutDays,
      arguments: ArchivedWorkoutDaysArgs(program: widget.program),
    );
  }

  void _moveTemplate(List<WorkoutTemplate> orderedList, int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= orderedList.length) return;

    final reordered = List<WorkoutTemplate>.from(orderedList);
    final moved = reordered.removeAt(index);
    reordered.insert(newIndex, moved);

    context.read<WorkoutTemplateCubit>().reorderTemplates(
      reordered.map((t) => t.id).toList(),
    );
  }

  void _openProgramAnalytics() {
    Navigator.pushNamed(
      context,
      AppNavigator.programAnalytics,
      arguments: ProgramAnalyticsArgs(program: widget.program),
    );
  }

  void _openHistory(WorkoutTemplate template) {
    Navigator.pushNamed(
      context,
      AppNavigator.workoutTemplateHistory,
      arguments: WorkoutTemplateHistoryArgs(template: template),
    );
  }

  void _startWorkout(WorkoutTemplate template) {
    context.read<WorkoutSessionCubit>().startWorkout(
      programId: widget.program.id,
      workoutTemplateId: template.id,
      workoutNameSnapshot: template.name,
      templateExerciseAssignments: template.exerciseAssignments,
    );
  }

  void _openActiveSession(WorkoutSession session) {
    // On finish (Phase 10/13), the active-session screen replaces
    // itself with the Workout Completion Summary screen, whose own
    // "Done" button pops straight back to here — nothing to react to
    // on the way back.
    Navigator.pushNamed(
      context,
      AppNavigator.activeWorkoutSession,
      arguments: ActiveWorkoutSessionArgs(session: session),
    );
  }

  Future<void> _onSessionStateChanged(
    BuildContext context,
    WorkoutSessionState state,
  ) async {
    if (state is WorkoutSessionActive) {
      _openActiveSession(state.session);
      return;
    }

    if (state is WorkoutSessionConflict) {
      final l10n = AppLocalizations.of(context)!;
      // Never silently creates a second session — always surfaces the
      // existing one and lets the user explicitly choose.
      final shouldResume = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            l10n.workoutInProgressConflictTitle,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            l10n.workoutInProgressConflictBody(
              state.existingSession.workoutNameSnapshot,
            ),
            style: TextStyle(color: ctx.appColors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.primary,
                foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
              ),
              child: Text(l10n.resumeWorkoutButton),
            ),
          ],
        ),
      );
      if (shouldResume == true && mounted) {
        _openActiveSession(state.existingSession);
      }
      return;
    }

    if (state is WorkoutSessionError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: context.appColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocListener<WorkoutSessionCubit, WorkoutSessionState>(
      listener: _onSessionStateChanged,
      child: Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(
          backgroundColor: isDark ? colors.canvas : _blue,
          foregroundColor: isDark ? colors.textPrimary : Colors.white,
          title: Text(widget.program.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              onPressed: _openArchivedWorkoutDays,
              tooltip: l10n.archivedWorkoutDaysTooltip,
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: _openProgramAnalytics,
              tooltip: l10n.analyticsTooltip,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreateDialog,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 10,
          icon: const Icon(Icons.add_circle_outline),
          label: Text(
            l10n.addWorkoutDayButton,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Column(
          children: [
            const _ThisWeekCard(),
            Expanded(
              child: BlocConsumer<WorkoutTemplateCubit, WorkoutTemplateState>(
                listener: (context, state) {
                  if (state is WorkoutTemplateLoaded && _box != state.box) {
                    setState(() => _box = state.box);
                  }
                  if (state is WorkoutTemplateError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: colors.error,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  final box = _box;

                  if (box == null) {
                    if (state is WorkoutTemplateError) {
                      return Center(
                        child: Text(
                          l10n.unableToLoadWorkoutDaysError,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }
                    return Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  }

                  return ValueListenableBuilder(
                    valueListenable: box.listenable(),
                    builder: (context, Box<WorkoutTemplate> liveBox, _) {
                      final repository = context
                          .read<WorkoutTemplateCubit>()
                          .repository;
                      final templates = repository.getTemplatesForProgram(
                        liveBox,
                        widget.program.id,
                      );

                      if (templates.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.list_alt,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 40,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  l10n.noWorkoutDaysYetTitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.noWorkoutDaysYetSubtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                        itemCount: templates.length,
                        itemBuilder: (context, index) {
                          final template = templates[index];
                          return Padding(
                            key: ValueKey(template.id),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _WorkoutDayCard(
                              template: template,
                              canMoveUp: index > 0,
                              canMoveDown: index < templates.length - 1,
                              onMoveUp: () =>
                                  _moveTemplate(templates, index, -1),
                              onMoveDown: () =>
                                  _moveTemplate(templates, index, 1),
                              onRename: () => _openRenameDialog(template),
                              onArchive: () => _confirmArchive(template),
                              onDelete: () => _confirmDeleteTemplate(template),
                              onStartWorkout: () => _startWorkout(template),
                              onHistory: () => _openHistory(template),
                              templateRepository: context
                                  .read<WorkoutTemplateCubit>()
                                  .repository,
                              exerciseCatalog:
                                  sl<CombinedExerciseLibraryCatalog>(),
                              customExercises: sl<CustomExerciseRepository>(),
                              languageCode: Localizations.localeOf(
                                context,
                              ).languageCode,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThisWeekCard extends StatelessWidget {
  const _ThisWeekCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return BlocBuilder<ProgramOverviewCubit, ProgramOverviewState>(
      builder: (context, state) {
        if (state is! ProgramOverviewLoaded) return const SizedBox.shrink();
        final overview = state.overview;
        if (overview.templates.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    l10n.thisWeekTitle,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    l10n.totalSessionsThisWeekLabel(
                      overview.totalSessionsThisWeek,
                    ),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final template in overview.templates)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: template.sessionsThisWeek > 0
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.14)
                            : colors.surfaceRaised,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${template.workoutTemplateName} '
                        '${l10n.templateSessionsThisWeekLabel(template.sessionsThisWeek)}',
                        style: TextStyle(
                          color: template.sessionsThisWeek > 0
                              ? Theme.of(context).colorScheme.primary
                              : colors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkoutDayCard extends StatelessWidget {
  final WorkoutTemplate template;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRename;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onStartWorkout;
  final VoidCallback onHistory;
  final WorkoutTemplateRepository templateRepository;
  final ExerciseLibraryCatalog exerciseCatalog;
  final CustomExerciseRepository customExercises;
  final String languageCode;

  const _WorkoutDayCard({
    required this.template,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRename,
    required this.onArchive,
    required this.onDelete,
    required this.onStartWorkout,
    required this.onHistory,
    required this.templateRepository,
    required this.exerciseCatalog,
    required this.customExercises,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: canMoveUp ? onMoveUp : null,
                    child: Icon(
                      Icons.keyboard_arrow_up,
                      size: 20,
                      color: canMoveUp
                          ? Theme.of(context).colorScheme.primary
                          : colors.textMuted.withValues(alpha: 0.4),
                    ),
                  ),
                  InkWell(
                    onTap: canMoveDown ? onMoveDown : null,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: canMoveDown
                          ? Theme.of(context).colorScheme.primary
                          : colors.textMuted.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  template.name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.history,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: onHistory,
                tooltip: l10n.historyTooltip,
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: onRename,
                tooltip: l10n.renameButton,
              ),
              IconButton(
                icon: Icon(
                  Icons.archive_outlined,
                  size: 18,
                  color: colors.error,
                ),
                onPressed: onArchive,
                tooltip: l10n.archiveButton,
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_forever_outlined,
                  size: 18,
                  color: colors.error,
                ),
                onPressed: onDelete,
                tooltip: l10n.delete,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TemplateExerciseManager(
            key: ValueKey('exercise-manager-${template.id}'),
            template: template,
            repository: templateRepository,
            catalog: exerciseCatalog,
            customExercises: customExercises,
            languageCode: languageCode,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStartWorkout,
              icon: const Icon(Icons.play_arrow),
              label: Text(
                l10n.startWorkoutButton,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
