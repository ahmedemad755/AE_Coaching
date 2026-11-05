import 'dart:math' as math;

import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_library_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ManageTemplateExercisesDialog extends StatefulWidget {
  final WorkoutTemplate template;
  final WorkoutTemplateRepository repository;
  final ExerciseLibraryCatalog catalog;
  final CustomExerciseRepository customExercises;
  final String languageCode;

  const ManageTemplateExercisesDialog({
    super.key,
    required this.template,
    required this.repository,
    required this.catalog,
    required this.customExercises,
    required this.languageCode,
  });

  @override
  State<ManageTemplateExercisesDialog> createState() =>
      _ManageTemplateExercisesDialogState();
}

class _ManageTemplateExercisesDialogState
    extends State<ManageTemplateExercisesDialog> {
  late List<WorkoutTemplateExerciseAssignment> _assignments;
  String? _error;
  final Set<String> _busyAssignmentIds = {};

  @override
  void initState() {
    super.initState();
    _assignments = List.of(widget.template.exerciseAssignments);
  }

  Future<void> _openPicker() async {
    await showDialog<List<ExerciseLibraryItem>>(
      context: context,
      builder: (_) => ExerciseLibraryScreen(
        catalog: widget.catalog,
        customExercises: widget.customExercises,
        languageCode: widget.languageCode,
        excludedIds: _assignments.map((item) => item.exerciseId).toSet(),
        excludedNames: _assignments
            .map((item) => item.exerciseNameSnapshot)
            .toSet(),
        onAddSelected: (selected) async {
          if (kDebugMode) {
            debugPrint(
              '[TemplateExercisePicker] Saving ${selected.length} selections '
              'to template ${widget.template.id}',
            );
          }
          final updated = await widget.repository.addExerciseAssignments(
            templateId: widget.template.id,
            exercises: selected,
            languageCode: widget.languageCode,
          );
          if (kDebugMode) {
            debugPrint(
              '[TemplateExercisePicker] Template ${widget.template.id} '
              'now has ${updated.exerciseAssignments.length} assignments',
            );
          }
          if (mounted) {
            setState(() {
              _assignments = updated.exerciseAssignments;
              _error = null;
            });
          }
        },
      ),
    );
  }

  Future<void> _remove(WorkoutTemplateExerciseAssignment assignment) async {
    if (!_busyAssignmentIds.add(assignment.assignmentId)) return;
    setState(() => _error = null);
    try {
      final updated = await widget.repository.removeExerciseAssignment(
        templateId: widget.template.id,
        assignmentId: assignment.assignmentId,
      );
      if (mounted) setState(() => _assignments = updated.exerciseAssignments);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = AppLocalizations.of(context)!.templateExerciseSaveError,
        );
      }
    } finally {
      _busyAssignmentIds.remove(assignment.assignmentId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final reordered = List.of(_assignments);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    setState(() {
      _assignments = reordered;
      _error = null;
    });
    try {
      final updated = await widget.repository.reorderExerciseAssignments(
        templateId: widget.template.id,
        orderedAssignmentIds: reordered
            .map((assignment) => assignment.assignmentId)
            .toList(),
      );
      if (mounted) setState(() => _assignments = updated.exerciseAssignments);
    } catch (_) {
      if (mounted) {
        setState(() {
          _assignments = widget.template.exerciseAssignments;
          _error = AppLocalizations.of(context)!.templateExerciseSaveError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(screen.width - 32, 560.0);
    final maxHeight = screen.height * 0.9;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: width,
        height: maxHeight,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.manageTemplateExercisesTitle(widget.template.name),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: colors.error)),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.assignedTemplateExercisesTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _assignments.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noAssignedTemplateExercises,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textMuted),
                        ),
                      )
                    : ReorderableListView.builder(
                        itemCount: _assignments.length,
                        onReorder: _reorder,
                        itemBuilder: (context, index) {
                          final assignment = _assignments[index];
                          return ListTile(
                            key: ValueKey(assignment.assignmentId),
                            dense: true,
                            title: Text(assignment.exerciseNameSnapshot),
                            subtitle:
                                assignment.referenceType == 'builtIn' &&
                                    assignment.exerciseId.startsWith('ex_')
                                ? Text(l10n.repdbLegacyReference)
                                : null,
                            leading: const Icon(Icons.drag_handle),
                            trailing: IconButton(
                              tooltip: l10n.removeAssignedExerciseTooltip,
                              onPressed:
                                  _busyAssignmentIds.contains(
                                    assignment.assignmentId,
                                  )
                                  ? null
                                  : () => _remove(assignment),
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: colors.error,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _openPicker,
                icon: const Icon(Icons.add),
                label: Text(l10n.addExerciseButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
