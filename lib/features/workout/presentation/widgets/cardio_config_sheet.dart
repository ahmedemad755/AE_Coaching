import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_library.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/cardio_activity_visuals.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The cardio settings of one activity (design screen 4, as a sheet).
/// Returns the edited plan, or null when cancelled. Nothing is saved here:
/// the caller saves it. Details this activity doesn't offer are carried over
/// unchanged from [initial].
Future<CardioPlan?> showCardioConfigSheet(
  BuildContext context, {
  required String exerciseId,
  required String name,
  CardioPlan? initial,
  bool justAdded = false,
}) => showModalBottomSheet<CardioPlan>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => CardioConfigSheet(
    exerciseId: exerciseId,
    name: name,
    initial: initial ?? CardioLibrary.defaultPlan,
    justAdded: justAdded,
  ),
);

class CardioConfigSheet extends StatefulWidget {
  const CardioConfigSheet({
    super.key,
    required this.exerciseId,
    required this.name,
    required this.initial,
    this.justAdded = false,
  });

  final String exerciseId;
  final String name;
  final CardioPlan initial;

  /// Opened right after the activity was added: says it is already in the
  /// day with these settings, and that Cancel keeps them.
  final bool justAdded;

  @override
  State<CardioConfigSheet> createState() => _CardioConfigSheetState();
}

/// A text field's allowed range (inclusive) and whether it takes decimals.
typedef _Range = ({double min, double max, bool decimal});

class _CardioConfigSheetState extends State<CardioConfigSheet> {
  late CardioMode _mode = widget.initial.mode;
  late int _durationSeconds = widget.initial.durationSeconds ?? 20 * 60;
  late bool _hasTarget =
      widget.initial.mode == CardioMode.stopwatch &&
      widget.initial.durationSeconds != null;
  late int _workSeconds = widget.initial.workSeconds ?? 30;
  late int _restSeconds = widget.initial.intervalRestSeconds ?? 30;
  late int _rounds = widget.initial.rounds ?? 8;
  late int _warmupSeconds = widget.initial.warmupSeconds ?? 0;
  late int _cooldownSeconds = widget.initial.cooldownSeconds ?? 0;
  late CardioIntensity? _intensity = widget.initial.intensity;

  late final Set<CardioDetail> _details = CardioLibrary.detailsFor(
    widget.exerciseId,
  );
  late final _speed = TextEditingController(
    text: _format(widget.initial.speedKmh),
  );
  late final _incline = TextEditingController(
    text: _format(widget.initial.inclinePercent),
  );
  late final _resistance = TextEditingController(
    text: widget.initial.resistanceLevel?.toString() ?? '',
  );
  late final _distance = TextEditingController(
    text: _format(
      widget.initial.distanceMeters == null
          ? null
          : widget.initial.distanceMeters! / 1000,
    ),
  );

  static const _speedRange = (min: 0.5, max: 40.0, decimal: true);
  static const _inclineRange = (min: -5.0, max: 40.0, decimal: true);
  static const _resistanceRange = (min: 1.0, max: 50.0, decimal: false);
  static const _distanceRange = (min: 0.01, max: 1000.0, decimal: true);

  @override
  void dispose() {
    _speed.dispose();
    _incline.dispose();
    _resistance.dispose();
    _distance.dispose();
    super.dispose();
  }

  static String _format(double? value) {
    if (value == null) return '';
    final text = value.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// Accepts Arabic-Indic digits and a comma or Arabic decimal separator.
  static double? _parse(String text) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final normalized = StringBuffer();
    for (final char in text.trim().split('')) {
      final digit = arabic.indexOf(char);
      normalized.write(
        digit >= 0
            ? '$digit'
            : (char == ',' || char == '٫')
            ? '.'
            : char,
      );
    }
    return double.tryParse(normalized.toString());
  }

  /// Null (empty), the value, or NaN when the text is invalid for [range].
  double? _value(TextEditingController controller, _Range range) {
    if (controller.text.trim().isEmpty) return null;
    final value = _parse(controller.text);
    if (value == null ||
        value < range.min ||
        value > range.max ||
        (!range.decimal && value != value.roundToDouble())) {
      return double.nan;
    }
    return value;
  }

  bool _invalid(TextEditingController controller, _Range range) =>
      _value(controller, range)?.isNaN ?? false;

  /// The edited plan, or null while a field is invalid.
  CardioPlan? _plan() {
    double? detail(
      CardioDetail kind,
      TextEditingController controller,
      _Range range,
      double? carried,
    ) => _details.contains(kind) ? _value(controller, range) : carried;
    final speed = detail(
      CardioDetail.speed,
      _speed,
      _speedRange,
      widget.initial.speedKmh,
    );
    final incline = detail(
      CardioDetail.incline,
      _incline,
      _inclineRange,
      widget.initial.inclinePercent,
    );
    final resistance = detail(
      CardioDetail.resistance,
      _resistance,
      _resistanceRange,
      widget.initial.resistanceLevel?.toDouble(),
    );
    final distanceKm = detail(
      CardioDetail.distance,
      _distance,
      _distanceRange,
      widget.initial.distanceMeters == null
          ? null
          : widget.initial.distanceMeters! / 1000,
    );
    if ([
      speed,
      incline,
      resistance,
      distanceKm,
    ].any((v) => v?.isNaN ?? false)) {
      return null;
    }
    final intervals = _mode == CardioMode.intervals;
    final plan = CardioPlan(
      mode: _mode,
      durationSeconds: switch (_mode) {
        CardioMode.countdown => _durationSeconds,
        CardioMode.stopwatch => _hasTarget ? _durationSeconds : null,
        CardioMode.intervals => null,
      },
      intensity: _intensity,
      workSeconds: intervals ? _workSeconds : null,
      intervalRestSeconds: intervals ? _restSeconds : null,
      rounds: intervals ? _rounds : null,
      warmupSeconds: intervals && _warmupSeconds > 0 ? _warmupSeconds : null,
      cooldownSeconds: intervals && _cooldownSeconds > 0
          ? _cooldownSeconds
          : null,
      speedKmh: speed,
      inclinePercent: incline,
      resistanceLevel: resistance?.round(),
      distanceMeters: distanceKm == null ? null : (distanceKm * 1000).round(),
    );
    try {
      plan.validate();
    } on ArgumentError {
      return null;
    }
    return plan;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final plan = _plan();
    final planned = plan == null ? null : cardioDurationLabel(l10n, plan);
    String minutes(int seconds) => seconds <= 0
        ? l10n.cardioNone
        : l10n.cardioDurationMinutes((seconds + 59) ~/ 60);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CardioActivityAvatar(exerciseId: widget.exerciseId, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.cardioSettingsTitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.justAdded)
              Container(
                key: const ValueKey('cardio-just-added'),
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(l10n.cardioJustAddedHint),
              ),
            _Section(l10n.cardioTimerModeLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in CardioMode.values)
                  ChoiceChip(
                    key: ValueKey('cardio-mode-${mode.name}'),
                    label: Text(cardioModeLabel(l10n, mode)),
                    selected: _mode == mode,
                    showCheckmark: false,
                    selectedColor: theme.colorScheme.primaryContainer,
                    onSelected: (_) => setState(() => _mode = mode),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_mode == CardioMode.stopwatch)
              SwitchListTile(
                key: const ValueKey('cardio-target-toggle'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.cardioTargetToggle),
                value: _hasTarget,
                onChanged: (value) => setState(() => _hasTarget = value),
              ),
            if (_mode == CardioMode.countdown ||
                (_mode == CardioMode.stopwatch && _hasTarget))
              _Stepper(
                id: 'duration',
                label: l10n.cardioDurationLabel,
                value: minutes(_durationSeconds),
                onMinus: _durationSeconds > 60
                    ? () => setState(() => _durationSeconds -= 60)
                    : null,
                onPlus: _durationSeconds + 60 <= 6 * 3600
                    ? () => setState(() => _durationSeconds += 60)
                    : null,
              ),
            if (_mode == CardioMode.intervals) ...[
              _Stepper(
                id: 'work',
                label: l10n.cardioWorkLabel,
                value: l10n.cardioSecondsValue(_workSeconds),
                onMinus: _workSeconds > 5
                    ? () => setState(() => _workSeconds -= 5)
                    : null,
                onPlus: _workSeconds < 3600
                    ? () => setState(() => _workSeconds += 5)
                    : null,
              ),
              _Stepper(
                id: 'rest',
                label: l10n.cardioIntervalRestLabel,
                value: l10n.cardioSecondsValue(_restSeconds),
                onMinus: _restSeconds > 0
                    ? () => setState(() => _restSeconds -= 5)
                    : null,
                onPlus: _restSeconds < 3600
                    ? () => setState(() => _restSeconds += 5)
                    : null,
              ),
              _Stepper(
                id: 'rounds',
                label: l10n.cardioRoundsLabel,
                value: '$_rounds',
                onMinus: _rounds > 1 ? () => setState(() => _rounds--) : null,
                onPlus: _rounds < 100 ? () => setState(() => _rounds++) : null,
              ),
              _Stepper(
                id: 'warmup',
                label: l10n.cardioWarmupLabel,
                value: minutes(_warmupSeconds),
                onMinus: _warmupSeconds > 0
                    ? () => setState(
                        () => _warmupSeconds = (_warmupSeconds - 60).clamp(
                          0,
                          3600,
                        ),
                      )
                    : null,
                onPlus: _warmupSeconds < 3600
                    ? () => setState(() => _warmupSeconds += 60)
                    : null,
              ),
              _Stepper(
                id: 'cooldown',
                label: l10n.cardioCooldownLabel,
                value: minutes(_cooldownSeconds),
                onMinus: _cooldownSeconds > 0
                    ? () => setState(
                        () => _cooldownSeconds = (_cooldownSeconds - 60).clamp(
                          0,
                          3600,
                        ),
                      )
                    : null,
                onPlus: _cooldownSeconds < 3600
                    ? () => setState(() => _cooldownSeconds += 60)
                    : null,
              ),
            ],
            _Section(l10n.cardioIntensityLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final intensity in CardioIntensity.values)
                  ChoiceChip(
                    key: ValueKey('cardio-intensity-${intensity.name}'),
                    label: Text(_intensityLabel(l10n, intensity)),
                    selected: _intensity == intensity,
                    showCheckmark: false,
                    selectedColor: theme.colorScheme.primaryContainer,
                    // Tapping the selected one again clears it (optional).
                    onSelected: (_) => setState(
                      () => _intensity = _intensity == intensity
                          ? null
                          : intensity,
                    ),
                  ),
              ],
            ),
            if (_intensity != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _intensityHint(l10n, _intensity!),
                  key: const ValueKey('cardio-intensity-hint'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
            if (_details.isNotEmpty) ...[
              _Section(l10n.cardioDetailsLabel),
              if (_details.contains(CardioDetail.speed))
                _NumberField(
                  id: 'speed',
                  controller: _speed,
                  label: l10n.cardioSpeedLabel,
                  range: _speedRange,
                  invalid: _invalid(_speed, _speedRange),
                  onChanged: () => setState(() {}),
                ),
              if (_details.contains(CardioDetail.incline))
                _NumberField(
                  id: 'incline',
                  controller: _incline,
                  label: l10n.cardioInclineLabel,
                  range: _inclineRange,
                  invalid: _invalid(_incline, _inclineRange),
                  signed: true,
                  onChanged: () => setState(() {}),
                ),
              if (_details.contains(CardioDetail.resistance))
                _NumberField(
                  id: 'resistance',
                  controller: _resistance,
                  label: l10n.cardioResistanceLabel,
                  range: _resistanceRange,
                  invalid: _invalid(_resistance, _resistanceRange),
                  onChanged: () => setState(() {}),
                ),
              if (_details.contains(CardioDetail.distance))
                _NumberField(
                  id: 'distance',
                  controller: _distance,
                  label: l10n.cardioDistanceLabel,
                  range: _distanceRange,
                  invalid: _invalid(_distance, _distanceRange),
                  onChanged: () => setState(() {}),
                ),
            ],
            const SizedBox(height: 16),
            if (planned != null)
              Text(
                l10n.cardioPlannedTotal(planned),
                key: const ValueKey('cardio-planned-total'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('cardio-config-save'),
              onPressed: plan == null
                  ? null
                  : () => Navigator.of(context).pop(plan),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(l10n.save),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: const ValueKey('cardio-config-cancel'),
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }

  static String _intensityLabel(AppLocalizations l10n, CardioIntensity value) =>
      switch (value) {
        CardioIntensity.light => l10n.cardioIntensityLight,
        CardioIntensity.moderate => l10n.cardioIntensityModerate,
        CardioIntensity.high => l10n.cardioIntensityHigh,
      };

  static String _intensityHint(AppLocalizations l10n, CardioIntensity value) =>
      switch (value) {
        CardioIntensity.light => l10n.cardioIntensityLightHint,
        CardioIntensity.moderate => l10n.cardioIntensityModerateHint,
        CardioIntensity.high => l10n.cardioIntensityHighHint,
      };
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: context.appColors.textMuted,
      ),
    ),
  );
}

/// − value + (48 dp touch targets; the value is announced with its label).
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.id,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String id;
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          IconButton(
            key: ValueKey('cardio-$id-minus'),
            tooltip: l10n.cardioDecrease(label),
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 76),
            child: Semantics(
              label: '$label: $value',
              excludeSemantics: true,
              child: Text(
                value,
                key: ValueKey('cardio-$id-value'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('cardio-$id-plus'),
            tooltip: l10n.cardioIncrease(label),
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.id,
    required this.controller,
    required this.label,
    required this.range,
    required this.invalid,
    required this.onChanged,
    this.signed = false,
  });

  final String id;
  final TextEditingController controller;
  final String label;
  final _Range range;
  final bool invalid;
  final bool signed;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String show(double value) => range.decimal
        ? value.toString().replaceFirst(RegExp(r'\.0$'), '')
        : value.round().toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: ValueKey('cardio-detail-$id'),
        controller: controller,
        onChanged: (_) => onChanged(),
        keyboardType: TextInputType.numberWithOptions(
          decimal: range.decimal,
          signed: signed,
        ),
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: label,
          errorText: invalid
              ? l10n.cardioValueRange(show(range.min), show(range.max))
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          isDense: true,
        ),
      ),
    );
  }
}
