import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program_draft.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_draft_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_library_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_exercise_targets_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_template_layout.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WorkoutProgramDraftScreen extends StatefulWidget {
  final WorkoutProgramDraft draft;
  final WorkoutTemplateImportService importer;
  final ExerciseLibraryCatalog exercises;
  final CustomExerciseRepository customExercises;
  const WorkoutProgramDraftScreen({
    super.key,
    required this.draft,
    required this.importer,
    required this.exercises,
    required this.customExercises,
  });
  @override
  State<WorkoutProgramDraftScreen> createState() =>
      _WorkoutProgramDraftScreenState();
}

class _WorkoutProgramDraftScreenState extends State<WorkoutProgramDraftScreen> {
  late final _cubit = WorkoutProgramDraftCubit(
    draft: widget.draft,
    importer: widget.importer,
  );
  bool _allowPop = false;
  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _discard() async {
    if (_cubit.state.saving) return;
    final l10n = AppLocalizations.of(context)!;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardProgramDraftTitle),
        content: Text(l10n.discardProgramDraftBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.discardProgramDraft),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop<WorkoutTemplateImportResult>(context);
        }
      });
    }
  }

  Future<void> _pick(
    WorkoutTemplate day, {
    WorkoutTemplateExerciseAssignment? replacing,
  }) async {
    final others = day.exerciseAssignments.where(
      (e) => e.assignmentId != replacing?.assignmentId,
    );
    final language = Localizations.localeOf(context).languageCode;
    await showDialog<List<ExerciseLibraryItem>>(
      context: context,
      builder: (_) => ExerciseLibraryScreen(
        catalog: widget.exercises,
        customExercises: widget.customExercises,
        languageCode: language,
        singleSelectionOnly: replacing != null,
        excludedIds: others.map((e) => e.exerciseId).toSet(),
        excludedNames: others.map((e) => e.exerciseNameSnapshot).toSet(),
        onAddSelected: (items) async {
          if (replacing == null) {
            _cubit.addExercises(day.id, items, language);
          } else {
            _cubit.replaceExercise(
              day.id,
              replacing.assignmentId,
              items.single,
              language,
            );
          }
        },
      ),
    );
  }

  Future<void> _targets(
    String dayId,
    WorkoutTemplateExerciseAssignment assignment,
  ) async {
    final updated = await showDialog<WorkoutTemplateExerciseAssignment>(
      context: context,
      builder: (_) => WorkoutExerciseTargetsDialog(assignment: assignment),
    );
    if (updated != null && mounted) _cubit.updateTargets(dayId, updated);
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocConsumer<WorkoutProgramDraftCubit, WorkoutProgramDraftState>(
      listener: (context, state) {
        if (state.saved != null) {
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pop<WorkoutTemplateImportResult>(context, state.saved);
            }
          });
        } else if (state.error != null) {
          final l10n = AppLocalizations.of(context)!;
          final message = switch (state.error!) {
            WorkoutDraftError.invalid => l10n.standardDraftInvalid,
            WorkoutDraftError.legacyResolution => l10n.repdbResolveBeforeSave,
            WorkoutDraftError.saveFailed => l10n.standardDraftSaveError,
            WorkoutDraftError.accountChanged =>
              l10n.standardDraftAccountChanged,
          };
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        return PopScope<WorkoutTemplateImportResult>(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _discard();
          },
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.customizeTemplateTitle)),
            body: AbsorbPointer(
              absorbing: state.saving,
              child: ListView(
                padding: const EdgeInsets.all(WorkoutTemplateSpacing.screen),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  TextFormField(
                    key: const ValueKey('draft-program-name'),
                    initialValue: state.draft.name,
                    decoration: InputDecoration(
                      labelText: l10n.programNameHint,
                    ),
                    onChanged: _cubit.renameProgram,
                    maxLength: 80,
                  ),
                  const SizedBox(height: WorkoutTemplateSpacing.section),
                  for (
                    var dayIndex = 0;
                    dayIndex < state.draft.days.length;
                    dayIndex++
                  )
                    Padding(
                      padding: EdgeInsets.only(
                        top: dayIndex == 0 ? 0 : WorkoutTemplateSpacing.dayCard,
                      ),
                      child: _dayCard(state.draft.days[dayIndex], dayIndex),
                    ),
                ],
              ),
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(WorkoutTemplateSpacing.screen),
                  child: FilledButton.icon(
                    key: const ValueKey('save-template-copy'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(
                        0,
                        WorkoutTemplateSpacing.tapTarget,
                      ),
                    ),
                    onPressed: state.saving ? null : _cubit.save,
                    icon: state.saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(l10n.saveToMyPrograms),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _dayCard(WorkoutTemplate day, int dayIndex) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      key: ValueKey('draft-day-card-${day.id}'),
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: ValueKey('draft-day-${day.id}'),
        initiallyExpanded: dayIndex == 0,
        maintainState: true,
        title: Text(day.name),
        tilePadding: const EdgeInsets.all(WorkoutTemplateSpacing.cardPadding),
        minTileHeight: WorkoutTemplateSpacing.tapTarget,
        childrenPadding: const EdgeInsets.fromLTRB(
          WorkoutTemplateSpacing.cardPadding,
          WorkoutTemplateSpacing.heading,
          WorkoutTemplateSpacing.cardPadding,
          WorkoutTemplateSpacing.cardPadding,
        ),
        children: [
          TextFormField(
            key: ValueKey('draft-day-name-${day.id}'),
            initialValue: day.name,
            decoration: InputDecoration(labelText: l10n.workoutDayNameHint),
            maxLength: 60,
            onChanged: (name) => _cubit.renameDay(day.id, name),
          ),
          const SizedBox(height: WorkoutTemplateSpacing.heading),
          for (var i = 0; i < day.exerciseAssignments.length; i++)
            Padding(
              padding: EdgeInsets.only(
                top: i == 0 ? 0 : WorkoutTemplateSpacing.exercise,
              ),
              child: ListTile(
                key: ValueKey(
                  'draft-assignment-${day.exerciseAssignments[i].assignmentId}',
                ),
                contentPadding: EdgeInsets.zero,
                minTileHeight: WorkoutTemplateSpacing.tapTarget,
                minVerticalPadding: 0,
                minLeadingWidth: 20,
                horizontalTitleGap: WorkoutTemplateSpacing.heading,
                titleAlignment: ListTileTitleAlignment.top,
                leading: Text('${i + 1}'),
                title: WorkoutTemplateExerciseContent(
                  assignment: day.exerciseAssignments[i],
                ),
                onTap: () => _targets(day.id, day.exerciseAssignments[i]),
                trailing: SizedBox.square(
                  dimension: WorkoutTemplateSpacing.tapTarget,
                  child: PopupMenuButton<String>(
                    tooltip: l10n.edit,
                    onSelected: (action) {
                      final e = day.exerciseAssignments[i];
                      switch (action) {
                        case 'targets':
                          _targets(day.id, e);
                        case 'replace':
                          _pick(day, replacing: e);
                        case 'remove':
                          _cubit.removeExercise(day.id, e.assignmentId);
                        case 'up':
                          _cubit.moveExercise(day.id, i, -1);
                        case 'down':
                          _cubit.moveExercise(day.id, i, 1);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'targets',
                        child: Text(l10n.editExerciseTargets),
                      ),
                      PopupMenuItem(
                        value: 'replace',
                        child: Text(l10n.replaceExerciseAction),
                      ),
                      PopupMenuItem(
                        value: 'up',
                        enabled: i > 0,
                        child: Text(l10n.moveUpTooltip),
                      ),
                      PopupMenuItem(
                        value: 'down',
                        enabled: i < day.exerciseAssignments.length - 1,
                        child: Text(l10n.moveDownTooltip),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(l10n.removeExerciseAction),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (day.exerciseAssignments.isEmpty)
            Text(l10n.noAssignedTemplateExercises),
          const SizedBox(height: WorkoutTemplateSpacing.heading),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: ValueKey('draft-add-${day.id}'),
              style: TextButton.styleFrom(
                minimumSize: const Size(
                  WorkoutTemplateSpacing.tapTarget,
                  WorkoutTemplateSpacing.tapTarget,
                ),
              ),
              onPressed: () => _pick(day),
              icon: const Icon(Icons.add),
              label: Text(l10n.addExerciseButton),
            ),
          ),
        ],
      ),
    );
  }
}
