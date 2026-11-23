import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/widgets/app_shimmer.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/cardio_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/cardio_activity_visuals.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// "My library": the exercises and cardio activities the user created.
/// Picking one calls the matching callback, which saves it (the caller owns
/// persistence); the screen closes once it succeeded.
class MyActivityLibraryScreen extends StatefulWidget {
  const MyActivityLibraryScreen({
    super.key,
    required this.customExercises,
    required this.onSelectStrength,
    required this.onSelectCardio,
    this.excludedIds = const {},
    this.excludedNames = const {},
    this.saveErrorMessage,
  });

  final CustomExerciseRepository customExercises;
  final Future<void> Function(ExerciseLibraryItem item) onSelectStrength;
  final Future<void> Function(CardioLibraryItem item) onSelectCardio;
  final Set<String> excludedIds;
  final Set<String> excludedNames;
  final String Function(Object error)? saveErrorMessage;

  @override
  State<MyActivityLibraryScreen> createState() =>
      _MyActivityLibraryScreenState();
}

class _MyActivityLibraryScreenState extends State<MyActivityLibraryScreen> {
  late final Future<List<CustomExercise>> _exercises = widget.customExercises
      .getAllExercises();
  String? _busyId;
  String? _error;

  late final Set<String> _excludedNames = {
    for (final name in widget.excludedNames) normalizeExerciseName(name),
  };

  bool _isExcluded(CustomExercise exercise) =>
      widget.excludedIds.contains(exercise.id) ||
      _excludedNames.contains(normalizeExerciseName(exercise.name));

  Future<void> _select(CustomExercise exercise) async {
    if (_busyId != null || _isExcluded(exercise)) return;
    setState(() {
      _busyId = exercise.id;
      _error = null;
    });
    try {
      if (ActivityType.parse(exercise.activityType) == ActivityType.cardio) {
        await widget.onSelectCardio(
          CardioLibraryItem(
            exerciseId: exercise.id,
            nameEn: exercise.name,
            isCustom: true,
          ),
        );
      } else {
        await widget.onSelectStrength(ExerciseLibraryItem.fromCustom(exercise));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error =
            widget.saveErrorMessage?.call(error) ??
            AppLocalizations.of(context)!.exerciseLibrarySaveError,
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.appColors;
    return Dialog.fullscreen(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.myLibraryTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _error!,
                    key: const ValueKey('my-library-error'),
                    style: TextStyle(color: colors.error),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<CustomExercise>>(
                  future: _exercises,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const ShimmerList(
                        itemHeight: 64,
                        padding: EdgeInsets.zero,
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text(l10n.exerciseLibraryLoadError));
                    }
                    final all = snapshot.data ?? const <CustomExercise>[];
                    final cardio = [
                      for (final e in all)
                        if (ActivityType.parse(e.activityType) ==
                            ActivityType.cardio)
                          e,
                    ];
                    final strength = [
                      for (final e in all)
                        if (ActivityType.parse(e.activityType) ==
                            ActivityType.strength)
                          e,
                    ];
                    if (cardio.isEmpty && strength.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bookmarks_outlined,
                                size: 40,
                                color: colors.textMuted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                l10n.myLibraryEmpty,
                                key: const ValueKey('my-library-empty'),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final rows = <Widget>[
                      if (strength.isNotEmpty) ...[
                        _SectionTitle(l10n.myLibraryStrengthSection),
                        for (final e in strength) _row(e, cardio: false),
                      ],
                      if (cardio.isNotEmpty) ...[
                        _SectionTitle(l10n.myLibraryCardioSection),
                        for (final e in cardio) _row(e, cardio: true),
                      ],
                    ];
                    return ListView.builder(
                      key: const ValueKey('my-library-list'),
                      itemCount: rows.length,
                      itemBuilder: (_, index) => rows[index],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(CustomExercise exercise, {required bool cardio}) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final excluded = _isExcluded(exercise);
    final busy = _busyId == exercise.id;
    return Padding(
      key: ValueKey('my-library-item-${exercise.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: !excluded,
        label: excluded
            ? '${exercise.name}, ${l10n.cardioAlreadyInDay}'
            : l10n.cardioAddAction(exercise.name),
        excludeSemantics: true,
        child: Material(
          color: colors.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: excluded || _busyId != null ? null : () => _select(exercise),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (cardio)
                      CardioActivityAvatar(exerciseId: exercise.id, size: 44)
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.border.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.fitness_center,
                          color: colors.textMuted,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (busy)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (excluded)
                      Text(
                        l10n.cardioAlreadyInDay,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.textMuted,
                        ),
                      )
                    else
                      Icon(
                        Icons.add_circle,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: context.appColors.textMuted,
      ),
    ),
  );
}
