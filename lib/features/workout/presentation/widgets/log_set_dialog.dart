import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Result of [LogSetDialog]: the weight/reps/optional note to log for
/// one set.
class LogSetResult {
  final double weight;
  final int reps;

  /// Optional free-text note for this specific set (Phase 18) — reuses
  /// ExerciseSet's original `notes` field, already normalized to
  /// `null` when blank.
  final String? notes;

  const LogSetResult({required this.weight, required this.reps, this.notes});
}

/// Weight + reps dialog used to log one set against [exerciseName] —
/// shared by "log a set for an already-listed exercise" and "log the
/// first set of a brand-new exercise" (the caller asks for the name
/// separately via [NameOnlyDialog] in the latter case).
class LogSetDialog extends StatefulWidget {
  final String exerciseName;

  /// Sets logged for this exact exercise in the previous COMPLETED
  /// session sharing the same programId + workoutTemplateId (Phase 9)
  /// — shown as read-only context, never pre-filled into the fields
  /// automatically.
  final List<ExerciseSet> previousSets;

  const LogSetDialog({
    super.key,
    required this.exerciseName,
    this.previousSets = const [],
  });

  @override
  State<LogSetDialog> createState() => _LogSetDialogState();
}

class _LogSetDialogState extends State<LogSetDialog> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final weight = double.tryParse(_weightController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());

    if (weight == null || weight < 0 || reps == null || reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unableToLogSetError),
          backgroundColor: context.appColors.error,
        ),
      );
      return;
    }
    final notes = _notesController.text.trim();
    Navigator.pop(
      context,
      LogSetResult(
        weight: weight,
        reps: reps,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(hintText: hint);
  }

  InputDecoration _notesDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      alignLabelWithHint: true,
      prefixIcon: const Icon(Icons.sticky_note_2_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        l10n.addSetToTitle(widget.exerciseName),
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.previousSets.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.lastTimeLabel}:',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                for (final previousSet in widget.previousSets)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 8,
                      top: 2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${previousSet.weight}${l10n.kgUnit} × ${previousSet.reps}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        if (previousSet.notes?.trim().isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 8,
                              bottom: 4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 14,
                                  color: colors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    previousSet.notes!.trim(),
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _weightController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration(l10n.weightKgHint),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _repsController,
            keyboardType: TextInputType.number,
            decoration: _decoration(l10n.repsHint),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: _notesDecoration(l10n.setNotesHint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel, style: TextStyle(color: colors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: Text(l10n.logFirstSetButton),
        ),
      ],
    );
  }
}
