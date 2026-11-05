import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class CreateProgramResult {
  final String name;
  final String? description;
  final bool makeActive;

  const CreateProgramResult({
    required this.name,
    required this.description,
    required this.makeActive,
  });
}

/// Collects a new program's name/description and whether the user
/// wants it made active. Returns a [CreateProgramResult] via
/// `Navigator.pop`, or null if cancelled. Does not talk to the Cubit
/// itself — the caller decides what to do (e.g. show the "make active"
/// confirmation) with the result.
class CreateProgramDialog extends StatefulWidget {
  const CreateProgramDialog({super.key});

  @override
  State<CreateProgramDialog> createState() => _CreateProgramDialogState();
}

class _CreateProgramDialogState extends State<CreateProgramDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(hintText: hint);
  }

  void _submit({required bool makeActive}) {
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

    Navigator.pop(
      context,
      CreateProgramResult(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        makeActive: makeActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        l10n.createProgramTitle,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: _decoration(l10n.programNameHint),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: _decoration(l10n.descriptionOptionalHint),
            minLines: 1,
            maxLines: 3,
          ),
        ],
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel, style: TextStyle(color: colors.textMuted)),
        ),
        OutlinedButton(
          onPressed: () => _submit(makeActive: false),
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary),
          ),
          child: Text(l10n.createButton),
        ),
        ElevatedButton(
          onPressed: () => _submit(makeActive: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: Text(l10n.createAndMakeActiveButton),
        ),
      ],
    );
  }
}
