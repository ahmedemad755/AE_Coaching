import 'dart:math' as math;

import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_media_resolver.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_taxonomy_labels.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_library_card.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ExercisePickerDialog extends StatefulWidget {
  final ExerciseLibraryCatalog catalog;
  final CustomExerciseRepository customExercises;
  final String languageCode;
  final Set<String> excludedIds;
  final Set<String> excludedNames;
  final bool singleSelectionOnly;
  final bool fullScreen;
  final Future<void> Function(List<ExerciseLibraryItem> exercises)?
  onAddSelected;
  final String Function(Object error)? saveErrorMessage;

  const ExercisePickerDialog({
    super.key,
    required this.catalog,
    required this.customExercises,
    required this.languageCode,
    this.excludedIds = const {},
    this.excludedNames = const {},
    this.singleSelectionOnly = false,
    this.fullScreen = false,
    this.onAddSelected,
    this.saveErrorMessage,
  });

  @override
  State<ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<ExercisePickerDialog> {
  final _searchController = TextEditingController();
  final Set<String> _muscleGroups = {};
  final Set<String> _equipment = {};
  final Map<String, ExerciseLibraryItem> _selected = {};
  late Future<List<ExerciseLibraryItem>> _allExercises;
  late Future<List<ExerciseLibraryItem>> _results;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _allExercises = _traceCatalogSearch(
      'unfiltered picker load',
      widget.catalog.search(),
    );
    _results = _allExercises;
  }

  Future<List<ExerciseLibraryItem>> _traceCatalogSearch(
    String stage,
    Future<List<ExerciseLibraryItem>> search,
  ) async {
    try {
      final items = await search;
      if (kDebugMode) {
        debugPrint('[ExercisePicker] $stage: ${items.length} entries');
      }
      return items;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[ExercisePicker] $stage failed: $error\n$stackTrace');
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshResults() {
    setState(() {
      _error = null;
      _results = _traceCatalogSearch(
        'filtered picker search',
        widget.catalog.search(
          query: _searchController.text,
          muscleGroups: Set.of(_muscleGroups),
          equipment: Set.of(_equipment),
        ),
      );
    });
  }

  bool _isExcluded(ExerciseLibraryItem item) =>
      widget.excludedIds.contains(item.id) ||
      item.legacyIds.any(widget.excludedIds.contains) ||
      widget.excludedNames
          .map(normalizeExerciseName)
          .contains(
            normalizeExerciseName(item.nameForLanguage(widget.languageCode)),
          );

  void _toggleExercise(ExerciseLibraryItem item, bool selected) {
    final normalized = normalizeExerciseName(
      item.nameForLanguage(widget.languageCode),
    );
    if (selected &&
        _selected.values.any(
          (chosen) =>
              normalizeExerciseName(
                chosen.nameForLanguage(widget.languageCode),
              ) ==
              normalized,
        )) {
      setState(
        () => _error = AppLocalizations.of(
          context,
        )!.templateExerciseDuplicateError,
      );
      return;
    }
    setState(() {
      _error = null;
      if (selected) {
        if (widget.singleSelectionOnly) _selected.clear();
        _selected[item.id] = item;
      } else {
        _selected.remove(item.id);
      }
    });
  }

  Future<void> _addSelected() async {
    if (_isSaving || _selected.isEmpty) return;
    final exercises = _selected.values.toList(growable: false);
    if (kDebugMode) {
      debugPrint('[ExercisePicker] Add requested: ${exercises.length} items');
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onAddSelected?.call(exercises);
      if (!mounted) return;
      if (kDebugMode) debugPrint('[ExercisePicker] Add persisted successfully');
      Navigator.pop<List<ExerciseLibraryItem>>(context, exercises);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[ExercisePicker] Add persistence failed: $error\n$stackTrace',
        );
      }
      if (mounted) {
        setState(() {
          _error =
              widget.saveErrorMessage?.call(error) ??
              AppLocalizations.of(context)!.exerciseLibrarySaveError;
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _createCustomExercise() async {
    final l10n = AppLocalizations.of(context)!;
    final result =
        await showDialog<({String name, String? muscle, String? equipment})>(
          context: context,
          builder: (context) => const _CreateCustomExerciseDialog(),
        );
    if (result == null || !mounted) return;
    try {
      final exercise = await widget.customExercises.createExercise(
        name: result.name,
        muscleGroup: result.muscle,
        equipment: result.equipment,
      );
      final item = ExerciseLibraryItem.fromCustom(exercise);
      setState(() {
        final duplicate = _selected.values.any(
          (chosen) =>
              normalizeExerciseName(
                chosen.nameForLanguage(widget.languageCode),
              ) ==
              normalizeExerciseName(item.nameForLanguage(widget.languageCode)),
        );
        if (!duplicate) _selected[item.id] = item;
        _error = duplicate
            ? AppLocalizations.of(context)!.templateExerciseDuplicateError
            : null;
        _allExercises = _traceCatalogSearch(
          'unfiltered picker reload',
          widget.catalog.search(),
        );
        _results = _traceCatalogSearch(
          'filtered picker reload',
          widget.catalog.search(
            query: _searchController.text,
            muscleGroups: Set.of(_muscleGroups),
            equipment: Set.of(_equipment),
          ),
        );
      });
    } on DuplicateCustomExerciseException {
      setState(() => _error = l10n.customExerciseDuplicateError);
    } catch (_) {
      setState(() => _error = l10n.customExerciseSaveError);
    }
  }

  Future<void> _showFilters(List<ExerciseLibraryItem> items) async {
    final l10n = AppLocalizations.of(context)!;
    final muscles = items
        .expand((e) => [e.muscleGroup, ...?e.catalogExercise?.primaryMuscles])
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList()..sort();
    final equipment = items
        .map((e) => e.equipment)
        .whereType<String>()
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList()..sort();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.exerciseFiltersTitle,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(l10n.muscleGroupLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final value in muscles)
                            FilterChip(
                              key: ValueKey('muscle-filter-$value'),
                              label: Text(ExerciseTaxonomyLabels.muscle(
                                value,
                                widget.languageCode,
                                fallback: l10n.exerciseMuscleName,
                              )),
                              selected: _muscleGroups.contains(value),
                              onSelected: (selected) {
                                updateSheet(() {
                                  if (selected) {
                                    _muscleGroups.add(value);
                                  } else {
                                    _muscleGroups.remove(value);
                                  }
                                });
                                _refreshResults();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(l10n.equipmentLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final value in equipment)
                            FilterChip(
                              key: ValueKey('equipment-filter-$value'),
                              label: Text(ExerciseTaxonomyLabels.equipment(
                                value,
                                widget.languageCode,
                                fallback: l10n.exerciseEquipmentName,
                              )),
                              selected: _equipment.contains(value),
                              onSelected: (selected) {
                                updateSheet(() {
                                  if (selected) {
                                    _equipment.add(value);
                                  } else {
                                    _equipment.remove(value);
                                  }
                                });
                                _refreshResults();
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(l10n.close),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width - 24, 620.0);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: widget.fullScreen
          ? EdgeInsets.zero
          : const EdgeInsets.all(12),
      backgroundColor: dark ? const Color(0xff101521) : colors.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(widget.fullScreen ? 0 : 24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: widget.fullScreen ? size.width : width,
        height: widget.fullScreen ? size.height : size.height * 0.9,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.exercisePickerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          l10n.exercisePickerAlternateTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () =>
                        Navigator.pop<List<ExerciseLibraryItem>>(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (_) => _refreshResults(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchExerciseLibraryHint,
                  filled: true,
                  fillColor: dark ? const Color(0xff1b2232) : scheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: scheme.outline),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              FutureBuilder<List<ExerciseLibraryItem>>(
                future: _allExercises,
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <ExerciseLibraryItem>[];
                  return Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _isSaving || !snapshot.hasData
                          ? null
                          : () => _showFilters(items),
                      icon: const Icon(Icons.tune),
                      label: Text(
                        '${l10n.exerciseFiltersTitle} (${_muscleGroups.length + _equipment.length})',
                      ),
                    ),
                  );
                },
              ),
              Row(
                children: [
                  FilterChip(
                    label: Text(l10n.exerciseAllFilter),
                    showCheckmark: false,
                    avatar: const Icon(Icons.grid_view_rounded, size: 18),
                    selected:
                        _muscleGroups.isEmpty &&
                        _equipment.isEmpty &&
                        _searchController.text.isEmpty,
                    selectedColor: scheme.primaryContainer,
                    onSelected: _isSaving
                        ? null
                        : (_) {
                            _muscleGroups.clear();
                            _equipment.clear();
                            _searchController.clear();
                            _refreshResults();
                          },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: _isSaving ? null : _createCustomExercise,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.createCustomExerciseButton),
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: TextStyle(color: colors.error)),
                ),
              Expanded(
                child: FutureBuilder<List<ExerciseLibraryItem>>(
                  future: _results,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text(l10n.exerciseLibraryLoadError));
                    }
                    final results =
                        snapshot.data ?? const <ExerciseLibraryItem>[];
                    if (results.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.noExerciseSearchResults,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      cacheExtent: 200,
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = results[index];
                        final excluded = _isExcluded(item);
                        final selected = _selected.containsKey(item.id);
                        return ExerciseLibraryCard(
                          key: ValueKey('exercise-card-${item.id}'),
                          exercise: item,
                          illustration: ExerciseMediaResolver.resolve(
                            item,
                          ).thumbnail,
                          selected: excluded || selected,
                          onChanged: excluded
                              ? null
                              : (value) => _toggleExercise(item, value),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _selected.isEmpty || _isSaving ? null : _addSelected,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(l10n.addSelectedExercisesButton(_selected.length)),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

class _CreateCustomExerciseDialog extends StatefulWidget {
  const _CreateCustomExerciseDialog();

  @override
  State<_CreateCustomExerciseDialog> createState() =>
      _CreateCustomExerciseDialogState();
}

class _CreateCustomExerciseDialogState
    extends State<_CreateCustomExerciseDialog> {
  final _name = TextEditingController();
  final _muscle = TextEditingController();
  final _equipment = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _muscle.dispose();
    _equipment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.createCustomExerciseTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.exerciseNameLabel),
            ),
            TextField(
              controller: _muscle,
              decoration: InputDecoration(
                labelText: l10n.muscleGroupOptionalLabel,
              ),
            ),
            TextField(
              controller: _equipment,
              decoration: InputDecoration(
                labelText: l10n.equipmentOptionalLabel,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (
                  name: _name.text.trim(),
                  muscle: _muscle.text.trim().isEmpty
                      ? null
                      : _muscle.text.trim(),
                  equipment: _equipment.text.trim().isEmpty
                      ? null
                      : _equipment.text.trim(),
                )),
          child: Text(l10n.createButton),
        ),
      ],
    );
  }
}
