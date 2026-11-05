import 'dart:math' as math;

import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_library_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_template_layout.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_exercise_targets_dialog.dart';
import 'package:flutter/material.dart';

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

  Future<void> _remove(WorkoutTemplateExerciseAssignment assignment) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final updated = await widget.repository.removeExerciseAssignment(
        templateId: widget.template.id,
        assignmentId: assignment.assignmentId,
      );
      if (mounted) setState(() => _assignments = updated.exerciseAssignments);
    } catch (_) {
      _showSaveError();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.templateExerciseSaveError),
      ),
    );
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
            Text(
              l10n.assignedTemplateExercisesCount(_assignments.length),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            FilledButton.tonalIcon(
              onPressed: _isSaving ? null : () => _openPicker(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addExerciseButton),
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
              maxHeight: math.min(
                260,
                MediaQuery.sizeOf(context).height * 0.42,
              ),
            ),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _assignments.length,
              onReorder: _reorder,
              itemBuilder: (context, index) {
                final assignment = _assignments[index];
                return Material(
                  key: ValueKey(assignment.assignmentId),
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 76,
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const SizedBox.square(
                              dimension: 44,
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: WorkoutTemplateExerciseContent(
                      assignment: assignment,
                    ),
                    trailing: PopupMenuButton<String>(
                      enabled: !_isSaving,
                      tooltip: l10n.edit,
                      onSelected: (action) {
                        if (action == 'targets') {
                          _editTargets(assignment);
                        } else if (action == 'replace') {
                          _openPicker(replacing: assignment);
                        } else if (action == 'remove') {
                          _remove(assignment);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'targets',
                          child: Text(l10n.editExerciseTargets),
                        ),
                        PopupMenuItem(
                          value: 'replace',
                          child: Text(l10n.replaceExerciseAction),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(l10n.removeExerciseAction),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
