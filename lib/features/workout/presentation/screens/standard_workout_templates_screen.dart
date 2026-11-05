import 'package:ae_coaching/features/workout/data/models/standard_workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program_draft.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/standard_workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/standard_workout_templates_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_template_layout.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_program_draft_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StandardWorkoutTemplatesScreen extends StatelessWidget {
  final StandardWorkoutTemplateRepository templates;
  final WorkoutTemplateImportService importer;
  final ExerciseLibraryCatalog exercises;
  final CustomExerciseRepository customExercises;
  const StandardWorkoutTemplatesScreen({
    super.key,
    required this.templates,
    required this.importer,
    required this.exercises,
    required this.customExercises,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => StandardWorkoutTemplatesCubit(templates)..load(),
    child: Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final lang = Localizations.localeOf(context).languageCode;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.workoutTemplatesTitle)),
          body:
              BlocBuilder<
                StandardWorkoutTemplatesCubit,
                StandardWorkoutTemplatesState
              >(
                builder: (context, state) {
                  if (state.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.failed) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(
                          WorkoutTemplateSpacing.screen,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.standardTemplateLoadError),
                            TextButton(
                              onPressed: context
                                  .read<StandardWorkoutTemplatesCubit>()
                                  .load,
                              child: Text(l10n.retry),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (state.splits.isEmpty) {
                    return Center(child: Text(l10n.standardTemplatesEmpty));
                  }
                  return ListView(
                    padding: const EdgeInsets.all(
                      WorkoutTemplateSpacing.screen,
                    ),
                    children: [
                      Text(l10n.standardTemplatesIntro),
                      const SizedBox(height: WorkoutTemplateSpacing.section),
                      for (final split in state.splits)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: split == state.splits.last
                                ? 0
                                : WorkoutTemplateSpacing.programCard,
                          ),
                          child: Card(
                            key: ValueKey('split-card-${split.id}'),
                            margin: EdgeInsets.zero,
                            child: ExpansionTile(
                              key: ValueKey('split-${split.id}'),
                              tilePadding: const EdgeInsets.all(
                                WorkoutTemplateSpacing.cardPadding,
                              ),
                              minTileHeight: WorkoutTemplateSpacing.tapTarget,
                              childrenPadding: const EdgeInsets.fromLTRB(
                                WorkoutTemplateSpacing.cardPadding,
                                WorkoutTemplateSpacing.heading,
                                WorkoutTemplateSpacing.cardPadding,
                                WorkoutTemplateSpacing.cardPadding,
                              ),
                              leading: const Icon(Icons.view_week_outlined),
                              title: Text(split.nameForLanguage(lang)),
                              subtitle: Text(
                                lang == 'ar' ? split.nameEn : split.nameAr,
                              ),
                              children: [
                                for (final variant in split.variants)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: variant == split.variants.first
                                          ? 0
                                          : WorkoutTemplateSpacing.variant,
                                    ),
                                    child: ListTile(
                                      key: ValueKey('variant-${variant.id}'),
                                      contentPadding: EdgeInsets.zero,
                                      minTileHeight:
                                          WorkoutTemplateSpacing.tapTarget,
                                      title: Text(
                                        l10n.templateDaysPerWeek(
                                          variant.days.length,
                                        ),
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () async {
                                        final saved =
                                            await Navigator.push<
                                              WorkoutTemplateImportResult
                                            >(
                                              context,
                                              MaterialPageRoute<
                                                WorkoutTemplateImportResult
                                              >(
                                                builder: (_) =>
                                                    StandardWorkoutTemplatePreviewScreen(
                                                      split: split,
                                                      variant: variant,
                                                      importer: importer,
                                                      exercises: exercises,
                                                      customExercises:
                                                          customExercises,
                                                    ),
                                              ),
                                            );
                                        if (saved != null && context.mounted) {
                                          Navigator.pop<
                                            WorkoutTemplateImportResult
                                          >(context, saved);
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
        );
      },
    ),
  );
}

class StandardWorkoutTemplatePreviewScreen extends StatelessWidget {
  final StandardWorkoutSplit split;
  final StandardWorkoutVariant variant;
  final WorkoutTemplateImportService importer;
  final ExerciseLibraryCatalog exercises;
  final CustomExerciseRepository customExercises;
  const StandardWorkoutTemplatePreviewScreen({
    super.key,
    required this.split,
    required this.variant,
    required this.importer,
    required this.exercises,
    required this.customExercises,
  });
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(split.nameForLanguage(lang))),
      body: ListView(
        padding: const EdgeInsets.all(WorkoutTemplateSpacing.screen),
        children: [
          Text(
            l10n.templateDaysPerWeek(variant.days.length),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: WorkoutTemplateSpacing.heading),
          Text(l10n.standardTemplateProgrammingNote),
          if (variant.days.length == 6)
            Padding(
              padding: const EdgeInsets.only(
                top: WorkoutTemplateSpacing.heading,
              ),
              child: Text(l10n.standardTemplateAdvancedNote),
            ),
          if (split.id == 'anterior_posterior')
            Padding(
              padding: const EdgeInsets.only(
                top: WorkoutTemplateSpacing.heading,
              ),
              child: Text(l10n.standardTemplateAnteriorPosteriorNote),
            ),
          const SizedBox(height: WorkoutTemplateSpacing.section),
          Text(
            l10n.suggestedTrainingWeek,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: WorkoutTemplateSpacing.heading),
          Wrap(
            spacing: WorkoutTemplateSpacing.exercise,
            runSpacing: WorkoutTemplateSpacing.exercise,
            children: [
              for (var i = 0; i < 7; i++)
                Chip(
                  label: Text(
                    '${l10n.suggestedSequenceDay(i + 1)}: ${variant.suggestedWeek[i] == null ? l10n.standardRestDay : variant.days[variant.suggestedWeek[i]!].nameForLanguage(lang)}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: WorkoutTemplateSpacing.section),
          for (final day in variant.days)
            Padding(
              padding: EdgeInsets.only(
                bottom: day == variant.days.last
                    ? 0
                    : WorkoutTemplateSpacing.dayCard,
              ),
              child: Card(
                key: ValueKey('preview-day-card-${day.id}'),
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  key: ValueKey('preview-day-${day.id}'),
                  tilePadding: const EdgeInsets.all(
                    WorkoutTemplateSpacing.cardPadding,
                  ),
                  minTileHeight: WorkoutTemplateSpacing.tapTarget,
                  childrenPadding: const EdgeInsets.fromLTRB(
                    WorkoutTemplateSpacing.cardPadding,
                    WorkoutTemplateSpacing.heading,
                    WorkoutTemplateSpacing.cardPadding,
                    WorkoutTemplateSpacing.cardPadding,
                  ),
                  title: Text(day.nameForLanguage(lang)),
                  children: [
                    for (var i = 0; i < day.exercises.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          top: i == 0 ? 0 : WorkoutTemplateSpacing.exercise,
                        ),
                        child: ListTile(
                          key: ValueKey('preview-exercise-${day.id}-$i'),
                          contentPadding: EdgeInsets.zero,
                          minTileHeight: WorkoutTemplateSpacing.tapTarget,
                          minVerticalPadding: 0,
                          minLeadingWidth: 20,
                          horizontalTitleGap: WorkoutTemplateSpacing.heading,
                          titleAlignment: ListTileTitleAlignment.top,
                          leading: Text('${i + 1}'),
                          title: WorkoutTemplateExerciseContent(
                            assignment: WorkoutTemplateExerciseAssignment(
                              assignmentId: 'preview',
                              exerciseId: day.exercises[i].exercise.id,
                              exerciseNameSnapshot: day.exercises[i].exercise
                                  .nameForLanguage(lang),
                              referenceType: 'builtIn',
                              workingSets: day.exercises[i].workingSets,
                              targetRepsMin: day.exercises[i].repsMin,
                              targetRepsMax: day.exercises[i].repsMax,
                              restSeconds: day.exercises[i].restSeconds,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WorkoutTemplateSpacing.screen),
          child: FilledButton.icon(
            key: const ValueKey('use-workout-template'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, WorkoutTemplateSpacing.tapTarget),
            ),
            icon: const Icon(Icons.copy_outlined),
            label: Text(l10n.useWorkoutTemplate),
            onPressed: () async {
              final owner = importer.currentUserId();
              if (owner == null || owner.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.standardDraftAccountChanged)),
                );
                return;
              }
              final saved = await Navigator.push<WorkoutTemplateImportResult>(
                context,
                MaterialPageRoute<WorkoutTemplateImportResult>(
                  builder: (_) => WorkoutProgramDraftScreen(
                    draft: WorkoutProgramDraft.fromTemplate(
                      split: split,
                      variant: variant,
                      languageCode: lang,
                      ownerUid: owner,
                    ),
                    importer: importer,
                    exercises: exercises,
                    customExercises: customExercises,
                  ),
                ),
              );
              if (saved != null && context.mounted) {
                Navigator.pop<WorkoutTemplateImportResult>(context, saved);
              }
            },
          ),
        ),
      ),
    );
  }
}
