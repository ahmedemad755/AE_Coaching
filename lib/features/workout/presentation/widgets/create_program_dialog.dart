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
  static const Color _blue = Color(0xff2f80ed);
  static const Color _muted = Color(0xff7d8792);

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  void _submit({required bool makeActive}) {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterProgramNameValidation), backgroundColor: Colors.redAccent),
      );
      return;
    }

    Navigator.pop(
      context,
      CreateProgramResult(
        name: name,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        makeActive: makeActive,
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
        l10n.createProgramTitle,
        style: const TextStyle(color: Color(0xff202936), fontWeight: FontWeight.w900),
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
          child: Text(l10n.cancel, style: const TextStyle(color: _muted)),
        ),
        OutlinedButton(
          onPressed: () => _submit(makeActive: false),
          style: OutlinedButton.styleFrom(foregroundColor: _blue, side: const BorderSide(color: _blue)),
          child: Text(l10n.createButton),
        ),
        ElevatedButton(
          onPressed: () => _submit(makeActive: true),
          style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
          child: Text(l10n.createAndMakeActiveButton),
        ),
      ],
    );
  }
}
