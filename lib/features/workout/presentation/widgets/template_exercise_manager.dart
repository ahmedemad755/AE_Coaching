import 'dart:math' as math;
import 'package:ae_coaching/core/feedback/app_feedback.dart';

import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/cardio_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_library.dart';
import 'package:ae_coaching/features/workout/domain/workout_duration_estimator.dart';
import 'package:ae_coaching/features/workout/domain/workout_features.dart';
import 'package:ae_coaching/features/workout/presentation/screens/cardio_library_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_library_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/my_activity_library_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/add_activity_sheet.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/cardio_activity_visuals.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/cardio_config_sheet.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_thumbnail.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_template_layout.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_exercise_targets_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:ae_coaching/core/widgets/entrance_animation.dart';

class TemplateExerciseManager extends StatefulWidget {
  final WorkoutTemplate template;
  final WorkoutTemplateRepository repository;
  final ExerciseLibraryCatalog catalog;
  final CustomExerciseRepository customExercises;
  final String languageCode;

  const TemplateExerciseManager({
    super.key,
    required this.template,
    required this.repository,
    required this.catalog,
    required this.customExercises,
    required this.languageCode,
  });

  @override
  State<TemplateExerciseManager> createState() =>
      _TemplateExerciseManagerState();
}

class _TemplateExerciseManagerState extends State<TemplateExerciseManager> {
  late List<WorkoutTemplateExerciseAssignment> _assignments;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _assignments = List.of(widget.template.exerciseAssignments);
  }

  @override
  void didUpdateWidget(covariant TemplateExerciseManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.template != widget.template) {
      _assignments = List.of(widget.template.exerciseAssignments);
    }
  }

  Future<void> _openPicker({
    WorkoutTemplateExerciseAssignment? replacing,
  }) async {
    if (_isSaving) return;
    final others = _assignments
        .where((item) => item.assignmentId != replacing?.assignmentId)
        .toList();
    await showDialog<List<ExerciseLibraryItem>>(
      context: context,
      builder: (_) => ExerciseLibraryScreen(
        catalog: widget.catalog,
        customExercises: widget.customExercises,
        languageCode: widget.languageCode,
        singleSelectionOnly: replacing != null,
        saveErrorMessage: (error) {
          final l10n = AppLocalizations.of(context)!;
          return error is ActivityLimitExceededException
              ? l10n.activityLimitReached(error.limit)
              : l10n.exerciseLibrarySaveError;
        },
        excludedIds: others.map((item) => item.exerciseId).toSet(),
        excludedNames: others.map((item) => item.exerciseNameSnapshot).toSet(),
        onAddSelected: (selected) async {
          setState(() => _isSaving = true);
          try {
            final updated = replacing == null
                ? await widget.repository.addExerciseAssignments(
                    templateId: widget.template.id,
                    exercises: selected,
                    languageCode: widget.languageCode,
                  )
                : await widget.repository.replaceExerciseAssignment(
                    templateId: widget.template.id,
                    assignmentId: replacing.assignmentId,
                    exercise: selected.single,
                    languageCode: widget.languageCode,
                  );
            if (mounted) {
              setState(() => _assignments = updated.exerciseAssignments);
            }
          } finally {
            if (mounted) setState(() => _isSaving = false);
          }
        },
      ),
    );
  }

  String _saveError(Object error) {
    final l10n = AppLocalizations.of(context)!;
    return switch (error) {
      ActivityLimitExceededException(:final limit) => l10n.activityLimitReached(
        limit,
      ),
      DuplicateTemplateExerciseException() =>
        l10n.templateExerciseDuplicateError,
      _ => l10n.exerciseLibrarySaveError,
    };
  }

  /// "Add activity" (design screen 2). Strength opens the exercise library
  /// exactly as before; with the cardio paths off (release builds until the
  /// cardio workout is ready) the button opens it directly, as it always did.
  Future<void> _addActivity() async {
    if (_isSaving) return;
    if (!WorkoutFeatures.cardioActivities) return _openPicker();
    final choice = await showAddActivitySheet(context);
    if (!mounted || choice == null) return;
    switch (choice) {
      case AddActivityChoice.strength:
        await _openPicker();
      case AddActivityChoice.cardio:
        await _openCardioLibrary();
      case AddActivityChoice.myLibrary:
        await _openMyLibrary();
    }
  }

  /// What is already in the day, apart from [assignmentId] (being replaced).
  ({Set<String> ids, Set<String> names}) _otherThan(String? assignmentId) {
    final others = _assignments.where((a) => a.assignmentId != assignmentId);
    return (
      ids: {for (final a in others) a.exerciseId},
      names: {for (final a in others) a.exerciseNameSnapshot},
    );
  }

  /// Added from a library that is still open: its settings open once the
  /// library has closed.
  WorkoutTemplateExerciseAssignment? _addedCardio;

  /// Adds [item] at the end of the day with the default plan (20 minutes;
  /// no timer runs). Its settings then open ([_configureAdded]).
  Future<void> _addCardio(CardioLibraryItem item) async {
    final name = item.nameFor(widget.languageCode);
    setState(() => _isSaving = true);
    try {
      final updated = await widget.repository.addExerciseAssignment(
        templateId: widget.template.id,
        exerciseId: item.exerciseId,
        exerciseNameSnapshot: name,
        referenceType: item.referenceType,
        cardio: CardioLibrary.defaultPlan,
      );
      _addedCardio = updated.exerciseAssignments.lastWhere(
        (a) => a.exerciseId == item.exerciseId,
      );
      if (mounted) setState(() => _assignments = updated.exerciseAssignments);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// After a library closed: opens the settings of the cardio activity just
  /// added. It is already saved; Cancel (or closing the sheet) keeps it with
  /// the settings it was added with, and says so.
  Future<void> _configureAdded() async {
    final added = _addedCardio;
    _addedCardio = null;
    if (added == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final saved = await _editCardio(added, justAdded: true);
    if (saved || !mounted) return;
    final plan = added.cardio ?? CardioLibrary.defaultPlan;
    AppFeedback.success(
      l10n.cardioAddedToDay(
        added.exerciseNameSnapshot,
        cardioDurationLabel(l10n, plan) ?? cardioModeLabel(l10n, plan.mode),
      ),
    );
  }

  Future<void> _openCardioLibrary({
    WorkoutTemplateExerciseAssignment? replacing,
  }) async {
    if (_isSaving) return;
    final others = _otherThan(replacing?.assignmentId);
    await showDialog<void>(
      context: context,
      builder: (_) => CardioLibraryScreen(
        library: CardioLibraryCatalog(
          catalog: widget.catalog,
          customExercises: widget.customExercises,
          appDefinedNames: appDefinedCardioNames(),
        ),
        customExercises: widget.customExercises,
        languageCode: widget.languageCode,
        excludedIds: others.ids,
        excludedNames: others.names,
        saveErrorMessage: _saveError,
        onSelected: (item) async {
          if (replacing == null) return _addCardio(item);
          _addedCardio = null;
          setState(() => _isSaving = true);
          try {
            // Keeps the activity's plan: only the activity changes.
            final updated = await widget.repository.replaceExerciseAssignment(
              templateId: widget.template.id,
              assignmentId: replacing.assignmentId,
              exercise: item.toLibraryItem(),
              languageCode: widget.languageCode,
            );
            if (mounted) {
              setState(() => _assignments = updated.exerciseAssignments);
            }
          } finally {
            if (mounted) setState(() => _isSaving = false);
          }
        },
      ),
    );
    if (replacing == null) await _configureAdded();
  }

  Future<void> _openMyLibrary() async {
    if (_isSaving) return;
    final others = _otherThan(null);
    await showDialog<void>(
      context: context,
      builder: (_) => MyActivityLibraryScreen(
        customExercises: widget.customExercises,
        excludedIds: others.ids,
        excludedNames: others.names,
        saveErrorMessage: _saveError,
        onSelectCardio: _addCardio,
        onSelectStrength: (item) async {
          setState(() => _isSaving = true);
          try {
            final updated = await widget.repository.addExerciseAssignments(
              templateId: widget.template.id,
              exercises: [item],
              languageCode: widget.languageCode,
            );
            if (mounted) {
              setState(() => _assignments = updated.exerciseAssignments);
            }
          } finally {
            if (mounted) setState(() => _isSaving = false);
          }
        },
      ),
    );
    await _configureAdded();
  }

  /// Cardio settings (design screen 4, as a sheet). Saved through the
  /// repository like any other change (order, sync and limits untouched);
  /// true when saved. Cancel saves nothing: the previous settings stay.
  /// A cardio path: off while the cardio paths are off (release builds).
  Future<bool> _editCardio(
    WorkoutTemplateExerciseAssignment assignment, {
    bool justAdded = false,
  }) async {
    if (_isSaving || !WorkoutFeatures.cardioActivities) return false;
    final l10n = AppLocalizations.of(context)!;
    final plan = await showCardioConfigSheet(
      context,
      exerciseId: assignment.exerciseId,
      name: assignment.exerciseNameSnapshot,
      initial: assignment.cardio,
      justAdded: justAdded,
    );
    if (plan == null || !mounted) return false;
    setState(() => _isSaving = true);
    try {
      final updated = await widget.repository.updateCardioPlan(
        templateId: widget.template.id,
        assignmentId: assignment.assignmentId,
        plan: plan,
      );
      if (!mounted) return true;
      setState(() => _assignments = updated.exerciseAssignments);
      AppFeedback.success(l10n.cardioSettingsSaved);
      return true;
    } catch (_) {
      _showSaveError();
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Removes at once, with Undo: the same entry (id, targets, plan) goes
  /// back to its place through the repository, saved and synced like any
  /// other change.
  Future<void> _remove(WorkoutTemplateExerciseAssignment assignment) async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    final index = _assignments.indexWhere(
      (a) => a.assignmentId == assignment.assignmentId,
    );
    setState(() => _isSaving = true);
    try {
      final updated = await widget.repository.removeExerciseAssignment(
        templateId: widget.template.id,
        assignmentId: assignment.assignmentId,
      );
      if (mounted) setState(() => _assignments = updated.exerciseAssignments);
      AppFeedback.info(
        l10n.activityRemoved(assignment.exerciseNameSnapshot),
        action: FeedbackAction(
          label: l10n.undoAction,
          onPressed: () => _undoRemove(assignment, index),
        ),
      );
    } catch (_) {
      _showSaveError();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Runs even if the card is gone meanwhile (the user asked for it back).
  Future<void> _undoRemove(
    WorkoutTemplateExerciseAssignment assignment,
    int index,
  ) async {
    final repository = widget.repository;
    final templateId = widget.template.id;
    final message = mounted ? _saveError : null;
    try {
      final updated = await repository.restoreExerciseAssignment(
        templateId: templateId,
        assignment: assignment,
        index: index < 0 ? _assignments.length : index,
      );
      if (mounted) setState(() => _assignments = updated.exerciseAssignments);
    } catch (error) {
      final text = message?.call(error);
      if (text != null) AppFeedback.error(text);
    }
  }

  /// One place up or down: the same path as a drag ([_reorder]), for the
  /// menu and screen readers (an alternative to dragging).
  Future<void> _move(int index, {required bool up}) =>
      _reorder(index, up ? index - 1 : index + 2);

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_isSaving || oldIndex == newIndex) return;
    if (newIndex > oldIndex) newIndex--;
    final previous = List.of(_assignments);
    final reordered = List.of(_assignments);
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    setState(() {
      _isSaving = true;
      _assignments = reordered;
    });
    try {
      final updated = await widget.repository.reorderExerciseAssignments(
        templateId: widget.template.id,
        orderedAssignmentIds: reordered
            .map((item) => item.assignmentId)
            .toList(),
      );
      if (mounted) setState(() => _assignments = updated.exerciseAssignments);
    } catch (_) {
      if (mounted) {
        setState(() => _assignments = previous);
        _showSaveError();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSaveError() {
    if (!mounted) return;
    AppFeedback.error(AppLocalizations.of(context)!.templateExerciseSaveError);
  }

  Future<void> _editTargets(
    WorkoutTemplateExerciseAssignment assignment,
  ) async {
    final edited = await showDialog<WorkoutTemplateExerciseAssignment>(
      context: context,
      builder: (_) => WorkoutExerciseTargetsDialog(assignment: assignment),
    );
    if (edited == null || !mounted || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final updated = await widget.repository.updateExerciseTargets(
        templateId: widget.template.id,
        assignmentId: assignment.assignmentId,
        workingSets: edited.workingSets!,
        targetRepsMin: edited.targetRepsMin!,
        targetRepsMax: edited.targetRepsMax!,
        restSeconds: edited.restSeconds!,
      );
      if (mounted) setState(() => _assignments = updated.exerciseAssignments);
    } catch (_) {
      _showSaveError();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.assignedTemplateExercisesCount(_assignments.length),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                _DayEstimate(assignments: _assignments),
              ],
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('template-add-activity'),
              onPressed: _isSaving ? null : _addActivity,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                WorkoutFeatures.cardioActivities
                    ? l10n.addActivityButton
                    : l10n.addExerciseButton,
              ),
            ),
          ],
        ),
        if (_assignments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              l10n.noAssignedTemplateExercises,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              // About five pictured rows, never most of a small screen.
              maxHeight: math.min(
                360,
                MediaQuery.sizeOf(context).height * 0.48,
              ),
            ),
            child: ReorderableListView.builder(
              proxyDecorator: entranceSafeProxyDecorator,
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _assignments.length,
              onReorder: _reorder,
              // A light tick when an activity is lifted and dropped (the
              // device's own haptics setting applies).
              onReorderStart: (_) => HapticFeedback.selectionClick(),
              onReorderEnd: (_) => HapticFeedback.selectionClick(),
              itemBuilder: staggeredItemBuilder((context, index) {
                final assignment = _assignments[index];
                final type = assignment.type;
                final cardio = type == ActivityType.cardio;
                // Replacing a cardio activity picks another cardio activity
                // (its plan is kept); only while the cardio paths are on.
                final canReplace =
                    type == ActivityType.strength ||
                    (cardio && WorkoutFeatures.cardioActivities);
                final canMoveUp = index > 0;
                final canMoveDown = index < _assignments.length - 1;
                return Material(
                  key: ValueKey(assignment.assignmentId),
                  color: Colors.transparent,
                  // Screen readers: move without dragging.
                  child: Semantics(
                    container: true,
                    customSemanticsActions: {
                      if (canMoveUp)
                        CustomSemanticsAction(label: l10n.moveUpTooltip): () =>
                            _move(index, up: true),
                      if (canMoveDown)
                        CustomSemanticsAction(
                          label: l10n.moveDownTooltip,
                        ): () =>
                            _move(index, up: false),
                    },
                    child: ListTile(
                      // Cardio: tap to open its settings (cardio paths on).
                      onTap: cardio && WorkoutFeatures.cardioActivities
                          ? () => _editCardio(assignment)
                          : null,
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 68,
                      minVerticalPadding: 8,
                      minLeadingWidth: 52,
                      horizontalTitleGap: 12,
                      // The exercise's picture (from the exercise library),
                      // numbered by its place in the day; tap for details.
                      // Cardio: its activity icon, same footprint.
                      leading: cardio
                          ? CardioActivityAvatar(
                              key: ValueKey(
                                'template-cardio-avatar-${assignment.assignmentId}',
                              ),
                              exerciseId: assignment.exerciseId,
                              index: index + 1,
                            )
                          : ExerciseThumbnail(
                              key: ValueKey(
                                'template-exercise-thumbnail-${assignment.assignmentId}',
                              ),
                              name: assignment.exerciseNameSnapshot,
                              assignment: assignment,
                              index: index + 1,
                              size: 52,
                            ),
                      title: WorkoutTemplateExerciseContent(
                        assignment: assignment,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: SizedBox(
                              width: 36,
                              height: 48,
                              child: Icon(
                                Icons.drag_handle,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            enabled: !_isSaving,
                            tooltip: l10n.edit,
                            onSelected: (action) {
                              if (action == 'targets') {
                                _editTargets(assignment);
                              } else if (action == 'cardio') {
                                _editCardio(assignment);
                              } else if (action == 'replace') {
                                cardio
                                    ? _openCardioLibrary(replacing: assignment)
                                    : _openPicker(replacing: assignment);
                              } else if (action == 'up') {
                                _move(index, up: true);
                              } else if (action == 'down') {
                                _move(index, up: false);
                              } else if (action == 'remove') {
                                _remove(assignment);
                              }
                            },
                            itemBuilder: (context) => [
                              // Sets and reps: strength only; a cardio activity
                              // has its own settings.
                              if (type == ActivityType.strength)
                                PopupMenuItem(
                                  value: 'targets',
                                  child: Text(l10n.editExerciseTargets),
                                ),
                              if (cardio && WorkoutFeatures.cardioActivities)
                                PopupMenuItem(
                                  value: 'cardio',
                                  child: Text(l10n.cardioSettingsTitle),
                                ),
                              if (canReplace)
                                PopupMenuItem(
                                  value: 'replace',
                                  child: Text(l10n.replaceExerciseAction),
                                ),
                              if (canMoveUp)
                                PopupMenuItem(
                                  value: 'up',
                                  child: Text(l10n.moveUpTooltip),
                                ),
                              if (canMoveDown)
                                PopupMenuItem(
                                  value: 'down',
                                  child: Text(l10n.moveDownTooltip),
                                ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(l10n.removeExerciseAction),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// "Estimated: 45 min" for the day (an estimate from its plan, never the
/// time a workout took), or nothing when no activity can be estimated.
class _DayEstimate extends StatelessWidget {
  const _DayEstimate({required this.assignments});
  final List<WorkoutTemplateExerciseAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final estimate = WorkoutDurationEstimator.estimate(assignments);
    if (estimate == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final duration = l10n.cardioDurationMinutes(estimate.minutes);
    final text = estimate.partial
        ? l10n.estimatedDurationAtLeast(duration)
        : l10n.estimatedDuration(duration);
    return Tooltip(
      message: l10n.estimatedDurationNote,
      child: Semantics(
        label: '$text. ${l10n.estimatedDurationNote}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: context.appColors.textMuted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  text,
                  key: const ValueKey('day-estimated-duration'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textMuted,
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
