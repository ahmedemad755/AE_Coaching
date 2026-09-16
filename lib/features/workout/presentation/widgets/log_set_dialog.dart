import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
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

  const LogSetDialog({super.key, required this.exerciseName, this.previousSets = const []});

  @override
  State<LogSetDialog> createState() => _LogSetDialogState();
}

class _LogSetDialogState extends State<LogSetDialog> {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _muted = Color(0xff7d8792);

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
        SnackBar(content: Text(l10n.unableToLogSetError), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final notes = _notesController.text.trim();
    Navigator.pop(context, LogSetResult(weight: weight, reps: reps, notes: notes.isEmpty ? null : notes));
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffd5e3f2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _blue),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xfff5f9fc),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        l10n.addSetToTitle(widget.exerciseName),
        style: const TextStyle(color: Color(0xff202936), fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.previousSets.isNotEmpty) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${l10n.lastTimeLabel}: '
                '${widget.previousSets.map((s) => '${s.weight}${l10n.kgUnit} × ${s.reps}').join(', ')}',
                style: const TextStyle(color: _muted, fontSize: 12, fontStyle: FontStyle.italic),
              ),
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
            maxLines: 2,
            decoration: _decoration(l10n.setNotesHint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel, style: const TextStyle(color: _muted)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
          child: Text(l10n.logFirstSetButton),
        ),
      ],
    );
  }
}
