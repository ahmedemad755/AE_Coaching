import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Prefilled with [currentName]. Returns the trimmed new name via
/// `Navigator.pop`, or null if cancelled. Only ever changes the name —
/// nothing else about the program.
class RenameProgramDialog extends StatefulWidget {
  final String currentName;

  const RenameProgramDialog({super.key, required this.currentName});

  @override
  State<RenameProgramDialog> createState() => _RenameProgramDialogState();
}

class _RenameProgramDialogState extends State<RenameProgramDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.currentName,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.enterProgramNameValidation),
          backgroundColor: context.appColors.error,
        ),
      );
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        l10n.renameProgramTitle,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.programNameHint),
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
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
