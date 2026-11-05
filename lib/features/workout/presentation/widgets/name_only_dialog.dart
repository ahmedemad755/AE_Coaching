import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Generic single-text-field dialog: a title, one text field
/// (optionally prefilled), Cancel/Save actions. Returns the trimmed
/// name via `Navigator.pop`, or null if cancelled. [onEmptyMessage] is
/// shown (as a SnackBar) instead of popping when the trimmed value is
/// empty.
///
/// Shared by "Create Workout Day" and "Rename Workout Day" — both are
/// a single required name field, nothing else.
class NameOnlyDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String? initialValue;
  final String saveLabel;
  final String cancelLabel;
  final String emptyValueMessage;

  const NameOnlyDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.saveLabel,
    required this.cancelLabel,
    required this.emptyValueMessage,
    this.initialValue,
  });

  @override
  State<NameOnlyDialog> createState() => _NameOnlyDialogState();
}

class _NameOnlyDialogState extends State<NameOnlyDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.emptyValueMessage),
          backgroundColor: context.appColors.error,
        ),
      );
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        widget.title,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.cancelLabel,
            style: TextStyle(color: colors.textMuted),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}
