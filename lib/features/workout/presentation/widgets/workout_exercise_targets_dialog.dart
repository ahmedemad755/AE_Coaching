import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class ExerciseTargetsSummary extends StatelessWidget {
  final WorkoutTemplateExerciseAssignment assignment;
  const ExerciseTargetsSummary({super.key, required this.assignment});
  @override
  Widget build(BuildContext context) {
    if (!assignment.hasTargets) {
      return const SizedBox.shrink();
    }
    var summary = AppLocalizations.of(context)!.exerciseTargetSummary(
      assignment.workingSets!,
      assignment.targetRepsMin!,
      assignment.targetRepsMax!,
      assignment.restSeconds!,
    );
    if (Directionality.of(context) == TextDirection.rtl) {
      final range = '${assignment.targetRepsMin}–${assignment.targetRepsMax}';
      // Isolate the numeric range without putting invisible bidi controls in
      // generated localization source files.
      summary = summary.replaceFirst(range, '\u2066$range\u2069');
    }
    return Text(summary, style: Theme.of(context).textTheme.bodySmall);
  }
}

class WorkoutExerciseTargetsDialog extends StatefulWidget {
  final WorkoutTemplateExerciseAssignment assignment;
  const WorkoutExerciseTargetsDialog({super.key, required this.assignment});
  @override
  State<WorkoutExerciseTargetsDialog> createState() =>
      _WorkoutExerciseTargetsDialogState();
}

class _WorkoutExerciseTargetsDialogState
    extends State<WorkoutExerciseTargetsDialog> {
  late final List<TextEditingController> _fields = [
    TextEditingController(text: '${widget.assignment.workingSets ?? 2}'),
    TextEditingController(text: '${widget.assignment.targetRepsMin ?? 8}'),
    TextEditingController(text: '${widget.assignment.targetRepsMax ?? 12}'),
    TextEditingController(text: '${widget.assignment.restSeconds ?? 90}'),
  ];
  bool _invalid = false;
  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _save() {
    final values = _fields.map((f) {
      var text = f.text.trim();
      for (var i = 0; i < 10; i++) {
        text = text
            .replaceAll(String.fromCharCode(0x660 + i), '$i')
            .replaceAll(String.fromCharCode(0x6f0 + i), '$i');
      }
      return int.tryParse(text);
    }).toList();
    if (values.any((v) => v == null)) {
      setState(() => _invalid = true);
      return;
    }
    final updated = widget.assignment.copyWith(
      workingSets: values[0],
      targetRepsMin: values[1],
      targetRepsMax: values[2],
      restSeconds: values[3],
    );
    try {
      updated.validateTargets();
    } catch (_) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop<WorkoutTemplateExerciseAssignment>(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.workingSetsLabel,
      l10n.minimumRepsLabel,
      l10n.maximumRepsLabel,
      l10n.exerciseRestSecondsLabel,
    ];
    return AlertDialog(
      title: Text(l10n.editExerciseTargets),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.assignment.exerciseNameSnapshot),
              for (var i = 0; i < _fields.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    key: ValueKey('target-$i'),
                    controller: _fields[i],
                    decoration: InputDecoration(labelText: labels[i]),
                    keyboardType: TextInputType.number,
                    textInputAction: i == 3
                        ? TextInputAction.done
                        : TextInputAction.next,
                    onSubmitted: i == 3 ? (_) => _save() : null,
                  ),
                ),
              if (_invalid)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    l10n.exerciseTargetsValidation,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop<WorkoutTemplateExerciseAssignment>(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
