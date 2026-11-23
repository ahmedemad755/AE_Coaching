import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_reference_resolver.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_detail_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_media_resolver.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The picture of an exercise inside a program, a workout day or a running
/// workout, with its position in the day as a corner badge. Tapping it
/// opens the exercise's details (both positions, instructions).
///
/// The exercise is found by its stored id ([ExerciseReferenceResolver]),
/// never by name. Custom exercises, manual entries and missing images get
/// a monogram of the name instead of a broken picture. Images are decoded
/// at the displayed size only.
class ExerciseThumbnail extends StatefulWidget {
  const ExerciseThumbnail({
    super.key,
    required this.name,
    this.assignment,
    this.item,
    this.index,
    this.size = 56,
    this.resolver,
  });

  /// Shown in the monogram and read by screen readers.
  final String name;

  /// A program / workout exercise: resolved to its library exercise.
  final WorkoutTemplateExerciseAssignment? assignment;

  /// An already known library exercise (e.g. a template preview).
  final ExerciseLibraryItem? item;

  /// 1-based position in the day, shown as a badge.
  final int? index;
  final double size;

  /// Defaults to the app's registered resolver.
  final ExerciseReferenceResolver? resolver;

  @override
  State<ExerciseThumbnail> createState() => _ExerciseThumbnailState();
}

class _ExerciseThumbnailState extends State<ExerciseThumbnail> {
  late Future<ExerciseLibraryItem?> _exercise = _resolve();

  @override
  void didUpdateWidget(ExerciseThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.assignment;
    final after = widget.assignment;
    if (oldWidget.item?.id != widget.item?.id ||
        before?.exerciseId != after?.exerciseId ||
        before?.referenceType != after?.referenceType) {
      _exercise = _resolve();
    }
  }

  Future<ExerciseLibraryItem?> _resolve() {
    final item = widget.item;
    if (item != null) return SynchronousFuture(item);
    final assignment = widget.assignment;
    final resolver =
        widget.resolver ??
        (sl.isRegistered<ExerciseReferenceResolver>()
            ? sl<ExerciseReferenceResolver>()
            : null);
    if (assignment == null || resolver == null) {
      return SynchronousFuture(null);
    }
    return resolver.resolveAssignment(assignment);
  }

  void _openDetails(ExerciseLibraryItem exercise) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ExerciseDetailScreen(exercise: exercise),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExerciseLibraryItem?>(
      future: _exercise,
      builder: (context, snapshot) {
        final exercise = snapshot.data;
        final loading = snapshot.connectionState != ConnectionState.done;
        final path = exercise == null
            ? null
            : ExerciseMediaResolver.resolve(exercise).thumbnail?.assetPath;
        final tile = _Tile(
          size: widget.size,
          name: widget.name,
          assetPath: path,
          loading: loading,
          onTap: exercise == null ? null : () => _openDetails(exercise),
        );
        final index = widget.index;
        final content = index == null
            ? tile
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  tile,
                  PositionedDirectional(
                    top: -5,
                    start: -5,
                    child: _IndexBadge(index: index),
                  ),
                ],
              );
        // The position stays readable (it used to be plain text); the
        // picture itself is announced only when it opens the details.
        final label = [
          if (index != null) '$index',
          if (exercise != null)
            '${AppLocalizations.of(context)!.exercisePreviewAction}: '
                '${widget.name}',
        ].join('. ');
        if (label.isEmpty) return ExcludeSemantics(child: content);
        return Semantics(
          button: exercise != null,
          label: label,
          child: ExcludeSemantics(child: content),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.size,
    required this.name,
    required this.assetPath,
    required this.loading,
    required this.onTap,
  });

  final double size;
  final String name;
  final String? assetPath;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final path = assetPath;
    final Widget picture;
    if (loading) {
      picture = const SizedBox.expand();
    } else if (path == null) {
      picture = _Monogram(name: name, size: size);
    } else {
      picture = Image(
        key: ValueKey('exercise-thumbnail-$path'),
        image: ResizeImage(
          AssetImage(path),
          width: pixels,
          height: pixels,
          policy: ResizeImagePolicy.fit,
        ),
        fit: BoxFit.cover,
        width: size,
        height: size,
        excludeFromSemantics: true,
        gaplessPlayback: true,
        frameBuilder: (_, child, frame, synchronous) => AnimatedOpacity(
          opacity: synchronous || frame != null ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
        errorBuilder: (_, _, _) => _Monogram(name: name, size: size),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: Material(
        color: scheme.surfaceContainerHighest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size * 0.24),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(onTap: onTap, child: picture),
      ),
    );
  }
}

/// The first letter of the name on a soft brand gradient (custom and
/// unillustrated exercises).
class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = name.trim();
    final letter = trimmed.isEmpty
        ? null
        : String.fromCharCodes(trimmed.runes.take(1)).toUpperCase();
    return DecoratedBox(
      key: const ValueKey('exercise-thumbnail-monogram'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            scheme.primary.withValues(alpha: 0.32),
            scheme.primary.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Center(
        child: letter == null
            ? Icon(
                Icons.fitness_center,
                color: scheme.primary,
                size: size * 0.42,
              )
            : Text(
                letter,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.42,
                  height: 1,
                ),
              ),
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: scheme.surface, width: 2),
      ),
      child: Text(
        '$index',
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          height: 1,
        ),
      ),
    );
  }
}
