import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_library_card.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_media_resolver.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_taxonomy_labels.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_sources_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    this.onAddToWorkout,
  });
  final ExerciseLibraryItem exercise;
  final VoidCallback? onAddToWorkout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final item = exercise.catalogExercise;
    final media = ExerciseMediaResolver.resolve(exercise);
    final arabic = lang == 'ar';
    final translated = item?.instructionsAr.isNotEmpty == true;
    final instructions = arabic && translated
        ? item!.instructionsAr
        : item?.instructionsEn ?? const <String>[];
    final tips = arabic && item?.tipsAr.isNotEmpty == true
        ? item!.tipsAr
        : item?.tipsEn ?? const <String>[];
    Widget pose(String? image, String title) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 250,
          child: ExerciseArtwork(
            illustration: image == null
                ? media.thumbnail
                : media.illustration(image),
            preview: true,
            semanticLabel: '${exercise.nameForLanguage(lang)}: $title',
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(exercise.nameForLanguage(lang))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            exercise.nameEn,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (exercise.nameAr?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              exercise.nameAr!,
              textDirection: TextDirection.rtl,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
          const SizedBox(height: 24),
          if (media.start != null || media.peak != null) ...[
            pose(media.start ?? media.peak, l10n.repdbStartPosition),
            const SizedBox(height: 16),
            if (media.peak != null && media.peak != media.start)
              pose(media.peak, l10n.repdbPeakPosition),
          ] else
            pose(media.main, l10n.exercisePreviewAction),
          const SizedBox(height: 24),
          ExerciseMetadata(exercise: exercise),
          if (item != null) ...[
            const SizedBox(height: 16),
            Text(
              l10n.repdbPrimaryMuscles,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              item.primaryMuscles.isEmpty
                  ? l10n.repdbUnknownMetadata
                  : item.primaryMuscles
                        .map((m) => ExerciseTaxonomyLabels.muscle(m, lang))
                        .join('، '),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.repdbSecondaryMuscles,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              item.secondaryMuscles.isEmpty
                  ? l10n.repdbUnknownMetadata
                  : item.secondaryMuscles
                        .map((m) => ExerciseTaxonomyLabels.muscle(m, lang))
                        .join('، '),
            ),
            if (item.category != null) ...[
              const SizedBox(height: 12),
              Text(ExerciseTaxonomyLabels.category(item.category!, lang)),
            ],
          ],
          const SizedBox(height: 24),
          Text(
            l10n.repdbInstructions,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (arabic && !translated) ...[
            const SizedBox(height: 8),
            Text(l10n.repdbTranslationPending),
          ],
          if (instructions.isEmpty)
            Text(l10n.repdbUnknownMetadata)
          else
            Directionality(
              textDirection: arabic && translated
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < instructions.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('${i + 1}. ${instructions[i]}'),
                    ),
                ],
              ),
            ),
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              l10n.repdbFormCues,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (arabic && item?.tipsAr.isEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.repdbTranslationPending),
              ),
            Directionality(
              textDirection: arabic && item!.tipsAr.isNotEmpty
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tip in tips)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(tip),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text('Exercise data by RepDB (repdb.co)'),
          TextButton.icon(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ExerciseSourcesScreen(),
              ),
            ),
            icon: const Icon(Icons.info_outline),
            label: Text(l10n.repdbDataSources),
          ),
        ],
      ),
      bottomNavigationBar: onAddToWorkout == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  key: const ValueKey('detail-add-to-workout'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () {
                    onAddToWorkout!();
                    Navigator.pop<void>(context);
                  },
                  icon: const Icon(Icons.add),
                  label: Text(l10n.repdbAddToWorkout),
                ),
              ),
            ),
    );
  }
}
