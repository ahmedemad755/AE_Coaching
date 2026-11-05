import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_illustrations.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_video_links.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_detail_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_taxonomy_labels.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_media_resolver.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/l10n/app_localizations_ar.dart';
import 'package:ae_coaching/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExerciseLibraryCard extends StatelessWidget {
  const ExerciseLibraryCard({
    super.key,
    required this.exercise,
    required this.selected,
    required this.onChanged,
    this.illustration,
    this.openExternal = openExerciseExternalUrl,
  });

  final ExerciseLibraryItem exercise;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final ExerciseIllustration? illustration;
  final ExternalUrlOpener openExternal;

  @override
  Widget build(BuildContext context) {
    final illustration =
        this.illustration ??
        (exercise.catalogExercise?.isRepDb == true
            ? ExerciseMediaResolver.resolve(exercise).thumbnail
            : null);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? const Color(0xff79adff) : const Color(0xff2468d7);
    final video = ExerciseVideoLinks.forExercise(exercise);
    final l10n = AppLocalizations.of(context)!;
    final nameAlignment = Directionality.of(context) == TextDirection.rtl
        ? TextAlign.right
        : TextAlign.left;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Material(
          color: selected
              ? Color.alphaBlend(accent.withValues(alpha: 0.10), scheme.surface)
              : dark
              ? const Color(0xff171d2b)
              : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected ? accent : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onChanged == null ? null : () => onChanged!(!selected),
            child: Padding(
              padding: EdgeInsets.all(compact ? 10 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: compact ? 72 : 112,
                    height: compact ? 94 : 112,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ExerciseArtwork(
                            illustration: illustration,
                            semanticLabel: video == null
                                ? l10n.exercisePreviewAction
                                : l10n.exerciseWatchVideo,
                            onTap: video == null
                                ? () => _preview(context)
                                : () => _openUrl(context, video),
                          ),
                        ),
                        if (video != null)
                          PositionedDirectional(
                            bottom: 2,
                            end: 2,
                            child: Material(
                              color: scheme.primaryContainer,
                              shape: const CircleBorder(),
                              child: IconButton(
                                key: ValueKey('exercise-video-${exercise.id}'),
                                tooltip: l10n.exerciseWatchVideo,
                                onPressed: () => _openUrl(context, video),
                                icon: Icon(
                                  Icons.play_arrow_rounded,
                                  color: scheme.onPrimaryContainer,
                                  size: 20,
                                ),
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: compact ? 10 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          exercise.nameEn,
                          textDirection: TextDirection.ltr,
                          textAlign: nameAlignment,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                        ),
                        if (exercise.nameAr?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 3),
                          Text(
                            exercise.nameAr!,
                            textDirection: TextDirection.rtl,
                            textAlign: nameAlignment,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        ExerciseMetadata(exercise: exercise),
                        if (illustration != null)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              key: ValueKey(
                                'exercise-artwork-credits-${exercise.id}',
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => _preview(context),
                              icon: const Icon(Icons.info_outline, size: 16),
                              label: Text(l10n.exerciseArtworkCredits),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      key: ValueKey('exercise-selection-${exercise.id}'),
                      value: selected,
                      onChanged: onChanged == null
                          ? null
                          : (value) => onChanged!(value == true),
                      semanticLabel: exercise.nameForLanguage(
                        Localizations.localeOf(context).languageCode,
                      ),
                      activeColor: accent,
                      checkColor: dark ? const Color(0xff101521) : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    final message = AppLocalizations.of(context)!.exerciseBrowserLaunchFailed;
    var opened = false;
    try {
      opened = await openExternal(uri);
    } catch (_) {
      // Native launch errors have the same localized, retryable outcome.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _preview(BuildContext context) {
    if (exercise.catalogExercise?.isRepDb == true) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ExerciseDetailScreen(
            exercise: exercise,
            onAddToWorkout: onChanged == null || selected
                ? null
                : () => onChanged!(true),
          ),
        ),
      );
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(exercise.nameForLanguage(l10n.localeName)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 230,
                  width: double.infinity,
                  child: ExerciseArtwork(
                    illustration: illustration,
                    preview: true,
                  ),
                ),
                const SizedBox(height: 16),
                Text(exercise.nameEn, textDirection: TextDirection.ltr),
                if (exercise.nameAr != null)
                  Text(exercise.nameAr!, textDirection: TextDirection.rtl),
                const SizedBox(height: 12),
                ExerciseMetadata(exercise: exercise),
                if (illustration != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${illustration!.author} · ${illustration!.license}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (illustration!.changes.isNotEmpty)
                    Text(
                      illustration!.changes,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        _openUrl(context, Uri.parse(illustration!.sourceUrl)),
                    child: Text(l10n.exerciseArtworkSource),
                  ),
                  TextButton(
                    onPressed: () => _showLicense(context),
                    child: Text(l10n.exerciseArtworkLicense),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  void _showLicense(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CC BY-SA 4.0'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: FutureBuilder<String>(
              future: rootBundle.loadString(ExerciseIllustrations.licenseAsset),
              builder: (context, snapshot) => snapshot.hasError
                  ? Text(l10n.exerciseLibraryLoadError)
                  : snapshot.hasData
                  ? SelectableText(snapshot.data!)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}

/// Only local assets are supported. Bounded decoding uses Flutter's normal
/// image cache; unavailable files render the same explicit placeholder.
class ExerciseArtwork extends StatelessWidget {
  const ExerciseArtwork({
    super.key,
    this.illustration,
    this.onTap,
    this.preview = false,
    this.semanticLabel,
  });
  final ExerciseIllustration? illustration;
  final VoidCallback? onTap;
  final bool preview;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder() => Container(
      key: const ValueKey('exercise-artwork-placeholder'),
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: preview ? 48 : 26,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              l10n.exerciseIllustrationUnavailable,
              textAlign: TextAlign.center,
              maxLines: preview ? null : 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: preview ? 12 : 9,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: semanticLabel ?? l10n.exercisePreviewAction,
      button: onTap != null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: scheme.surfaceContainerHighest,
          child: InkWell(
            onTap: onTap,
            child: illustration == null
                ? placeholder()
                : Image(
                    image: ResizeImage(
                      AssetImage(illustration!.assetPath),
                      width: preview ? 1000 : 336,
                      height: preview ? 1000 : 336,
                      policy: ResizeImagePolicy.fit,
                    ),
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    frameBuilder: (_, child, frame, synchronous) =>
                        synchronous || frame != null
                        ? child
                        : Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                    errorBuilder: (_, _, _) => placeholder(),
                  ),
          ),
        ),
      ),
    );
  }
}

class ExerciseMetadata extends StatelessWidget {
  const ExerciseMetadata({super.key, required this.exercise});
  final ExerciseLibraryItem exercise;

  @override
  Widget build(BuildContext context) {
    final en = AppLocalizationsEn();
    final ar = AppLocalizationsAr();
    final l10n = AppLocalizations.of(context)!;
    final primary = exercise.catalogExercise?.primaryMuscles;
    final muscle = primary?.isNotEmpty == true
        ? primary!.first
        : exercise.muscleGroup;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (muscle?.isNotEmpty == true)
          _Badge(
            icon: Icons.accessibility_new_outlined,
            english: ExerciseTaxonomyLabels.muscle(
              muscle!,
              'en',
              fallback: en.exerciseMuscleName,
            ),
            arabic: ExerciseTaxonomyLabels.muscle(
              muscle,
              'ar',
              fallback: ar.exerciseMuscleName,
            ),
            highlight: true,
          ),
        if (exercise.equipment?.isNotEmpty == true)
          _Badge(
            icon: Icons.fitness_center,
            english: ExerciseTaxonomyLabels.equipment(
              exercise.equipment!,
              'en',
              fallback: en.exerciseEquipmentName,
            ),
            arabic: ExerciseTaxonomyLabels.equipment(
              exercise.equipment!,
              'ar',
              fallback: ar.exerciseEquipmentName,
            ),
          ),
        if (exercise.source == ExerciseLibraryItemSource.custom)
          _Badge(icon: Icons.person_outline, english: l10n.exerciseCustomBadge),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.english,
    this.arabic,
    this.highlight = false,
  });
  final IconData icon;
  final String english;
  final String? arabic;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = highlight
        ? (dark ? const Color(0xff8dbbff) : const Color(0xff2468d7))
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? color.withValues(alpha: 0.4)
              : scheme.outlineVariant,
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 5),
                child: Icon(icon, size: 15, color: color),
              ),
            ),
            TextSpan(
              text: arabic != null && arabic != english
                  ? '$arabic · $english'
                  : english,
            ),
          ],
        ),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: color, height: 1.4),
      ),
    );
  }
}
