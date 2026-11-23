import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/widgets/app_shimmer.dart';
import 'package:ae_coaching/features/workout/data/repositories/cardio_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_library.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/cardio_activity_visuals.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/name_only_dialog.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The cardio library (design screen 3): search, categories, the user's own
/// cardio. Picking an activity calls [onSelected], which saves it (the
/// caller owns persistence, like the exercise library); the screen closes
/// once it succeeded, or shows [saveErrorMessage].
class CardioLibraryScreen extends StatefulWidget {
  const CardioLibraryScreen({
    super.key,
    required this.library,
    required this.customExercises,
    required this.languageCode,
    required this.onSelected,
    this.excludedIds = const {},
    this.excludedNames = const {},
    this.saveErrorMessage,
  });

  final CardioLibraryCatalog library;
  final CustomExerciseRepository customExercises;
  final String languageCode;
  final Future<void> Function(CardioLibraryItem item) onSelected;

  /// Already in the day (shown, not selectable).
  final Set<String> excludedIds;
  final Set<String> excludedNames;
  final String Function(Object error)? saveErrorMessage;

  @override
  State<CardioLibraryScreen> createState() => _CardioLibraryScreenState();
}

enum _CardioFilter { all, machines, bodyweight, outdoor, mine }

class _CardioLibraryScreenState extends State<CardioLibraryScreen> {
  late Future<List<CardioLibraryItem>> _items = widget.library.load();
  final _search = TextEditingController();
  _CardioFilter _filter = _CardioFilter.all;
  String? _busyId;
  String? _error;

  late final Set<String> _excludedNames = {
    for (final name in widget.excludedNames) normalizeExerciseName(name),
  };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isExcluded(CardioLibraryItem item) =>
      widget.excludedIds.contains(item.exerciseId) ||
      _excludedNames.contains(
        normalizeExerciseName(item.nameFor(widget.languageCode)),
      );

  bool _inFilter(CardioLibraryItem item) => switch (_filter) {
    _CardioFilter.all => true,
    _CardioFilter.machines => item.category == CardioCategory.machines,
    _CardioFilter.bodyweight => item.category == CardioCategory.bodyweight,
    _CardioFilter.outdoor => item.category == CardioCategory.outdoor,
    _CardioFilter.mine => item.isCustom,
  };

  Future<void> _select(CardioLibraryItem item) async {
    if (_busyId != null || _isExcluded(item)) return;
    setState(() {
      _busyId = item.exerciseId;
      _error = null;
    });
    try {
      await widget.onSelected(item);
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

  Future<void> _createCustom() async {
    if (_busyId != null) return;
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameOnlyDialog(
        title: l10n.cardioCreateCustom,
        hint: l10n.cardioCustomNameLabel,
        saveLabel: l10n.cardioCreateAndAdd,
        cancelLabel: l10n.cancel,
        emptyValueMessage: l10n.exerciseNameRequiredError,
      ),
    );
    if (name == null || !mounted) return;
    try {
      final created = await widget.customExercises.createExercise(
        name: name,
        activityType: ActivityType.cardio,
      );
      if (!mounted) return;
      setState(() {
        _items = widget.library.load();
        _filter = _CardioFilter.mine;
      });
      await _select(
        CardioLibraryItem(
          exerciseId: created.id,
          nameEn: created.name,
          isCustom: true,
        ),
      );
    } on DuplicateCustomExerciseException {
      if (mounted) setState(() => _error = l10n.customExerciseDuplicateError);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.customExerciseSaveError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
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
                      l10n.cardioLibraryTitle,
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
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('cardio-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.close,
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_search.clear),
                        ),
                  hintText: l10n.cardioSearchHint,
                  filled: true,
                  fillColor: colors.surfaceRaised,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView(
                  key: const ValueKey('cardio-filters'),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final filter in _CardioFilter.values)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          key: ValueKey('cardio-filter-${filter.name}'),
                          label: Text(_filterLabel(l10n, filter)),
                          selected: _filter == filter,
                          showCheckmark: false,
                          selectedColor: theme.colorScheme.primaryContainer,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    _error!,
                    key: const ValueKey('cardio-error'),
                    style: TextStyle(color: colors.error),
                  ),
                ),
              const SizedBox(height: 6),
              Expanded(
                child: FutureBuilder<List<CardioLibraryItem>>(
                  future: _items,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const ShimmerList(
                        itemHeight: 72,
                        padding: EdgeInsets.zero,
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text(l10n.exerciseLibraryLoadError));
                    }
                    final visible = [
                      for (final item in snapshot.data ?? const [])
                        if (_inFilter(item) && item.matches(_search.text)) item,
                    ];
                    if (visible.isEmpty) return _empty(l10n);
                    return ListView.separated(
                      key: const ValueKey('cardio-list'),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        return _CardioActivityTile(
                          key: ValueKey('cardio-item-${item.exerciseId}'),
                          item: item,
                          languageCode: widget.languageCode,
                          excluded: _isExcluded(item),
                          busy: _busyId == item.exerciseId,
                          enabled: _busyId == null,
                          onTap: () => _select(item),
                        );
                      },
                    );
                  },
                ),
              ),
              if (!keyboardOpen) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('cardio-create-custom'),
                  onPressed: _busyId == null ? _createCustom : null,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.cardioCreateCustom),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(AppLocalizations l10n) {
    final mine = _filter == _CardioFilter.mine && _search.text.trim().isEmpty;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mine ? Icons.monitor_heart_outlined : Icons.search_off,
              size: 40,
              color: context.appColors.textMuted,
            ),
            const SizedBox(height: 10),
            Text(
              mine ? l10n.cardioMineEmpty : l10n.cardioNoResults,
              key: const ValueKey('cardio-empty'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              key: const ValueKey('cardio-empty-create'),
              onPressed: _busyId == null ? _createCustom : null,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.cardioCreateCustom),
            ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(AppLocalizations l10n, _CardioFilter filter) =>
      switch (filter) {
        _CardioFilter.all => l10n.cardioCategoryAll,
        _CardioFilter.machines => l10n.cardioCategoryMachines,
        _CardioFilter.bodyweight => l10n.cardioCategoryBodyweight,
        _CardioFilter.outdoor => l10n.cardioCategoryOutdoor,
        _CardioFilter.mine => l10n.cardioCategoryMine,
      };
}

class _CardioActivityTile extends StatelessWidget {
  const _CardioActivityTile({
    super.key,
    required this.item,
    required this.languageCode,
    required this.excluded,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final CardioLibraryItem item;
  final String languageCode;
  final bool excluded;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final name = item.nameFor(languageCode);
    final subtitle = item.exerciseId == CardioLibrary.airBike
        ? l10n.cardioAirBikeAlsoKnown
        : languageCode.startsWith('ar') && item.nameEn != name
        ? item.nameEn
        : cardioCategoryLabel(l10n, item.category);
    return Semantics(
      button: !excluded,
      enabled: enabled && !excluded,
      label: excluded
          ? '$name, ${l10n.cardioAlreadyInDay}'
          : l10n.cardioAddAction(name),
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: excluded || !enabled ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CardioActivityAvatar(exerciseId: item.exerciseId, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          // English names stay left-to-right in Arabic.
                          textDirection: subtitle == item.nameEn
                              ? TextDirection.ltr
                              : null,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
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
    );
  }
}
