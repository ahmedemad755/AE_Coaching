import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One not-yet-logged working set of a template exercise, shown ready to fill:
/// the set number and target rep range are already there, so the trainee only
/// types the weight and the reps actually done, then taps ✓.
///
/// Nothing is persisted until [onSubmit] succeeds, so planned rows never
/// create empty or fake sets. Last session's weight is only a hint, never a
/// pre-filled value (same rule as [LogSetDialog]).
class PlannedSetRow extends StatefulWidget {
  const PlannedSetRow({
    super.key,
    required this.setNumber,
    required this.repsHint,
    required this.onSubmit,
    this.weightHint,
    this.enabled = true,
  });

  final int setNumber;

  /// Target reps shown inside the reps field, e.g. `8–12`.
  final String repsHint;

  /// Last session's weight for this set, shown as a hint only.
  final double? weightHint;

  /// False while logging is blocked (rest timer, previous set not done…);
  /// only changes the button's icon — [onSubmit] decides and explains.
  final bool enabled;

  /// Persists the set. Returns true when it was saved.
  final Future<bool> Function(double weight, int reps) onSubmit;

  @override
  State<PlannedSetRow> createState() => _PlannedSetRowState();
}

class _PlannedSetRowState extends State<PlannedSetRow> {
  final _weight = TextEditingController();
  final _reps = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  Future<void> _submit() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    final reps = int.tryParse(_reps.text.trim());
    if (weight == null ||
        !weight.isFinite ||
        weight < 0 ||
        reps == null ||
        reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unableToLogSetError),
          backgroundColor: context.appColors.error,
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await widget.onSubmit(weight, reps);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, String hint) => InputDecoration(
    isDense: true,
    labelText: label,
    hintText: hint,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final weightHint = widget.weightHint;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 52),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${l10n.setLabel} ${widget.setNumber}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: ValueKey('planned-weight-${widget.setNumber}'),
              controller: _weight,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                l10n.weightKgHint,
                weightHint == null
                    ? l10n.kgUnit
                    : '${_number(weightHint)} ${l10n.kgUnit}',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('×', style: TextStyle(color: colors.textMuted)),
          ),
          Expanded(
            child: TextField(
              key: ValueKey('planned-reps-${widget.setNumber}'),
              controller: _reps,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              // The range reads left-to-right in Arabic too.
              decoration: _decoration(
                l10n.repsHint,
                '\u2066${widget.repsHint}\u2069',
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox.square(
            dimension: 44,
            child: _saving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                // Stays tappable while blocked so the screen can explain why
                // (rest timer running, previous set not marked done).
                : IconButton.filledTonal(
                    key: ValueKey('planned-save-${widget.setNumber}'),
                    tooltip: l10n.setDoneLabel,
                    onPressed: _submit,
                    icon: Icon(
                      widget.enabled
                          ? Icons.check_rounded
                          : Icons.hourglass_top_rounded,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
