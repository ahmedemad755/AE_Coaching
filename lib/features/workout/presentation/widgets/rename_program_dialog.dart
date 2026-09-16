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
  static const Color _blue = Color(0xff2f80ed);
  static const Color _muted = Color(0xff7d8792);

  late final TextEditingController _nameController = TextEditingController(text: widget.currentName);

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
        SnackBar(content: Text(l10n.enterProgramNameValidation), backgroundColor: Colors.redAccent),
      );
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xfff5f9fc),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        l10n.renameProgramTitle,
        style: const TextStyle(color: Color(0xff202936), fontWeight: FontWeight.w900),
      ),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l10n.programNameHint,
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel, style: const TextStyle(color: _muted)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
