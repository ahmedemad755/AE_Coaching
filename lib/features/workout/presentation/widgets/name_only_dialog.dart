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
  static const Color _blue = Color(0xff2f80ed);
  static const Color _muted = Color(0xff7d8792);

  late final TextEditingController _controller = TextEditingController(text: widget.initialValue ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.emptyValueMessage), backgroundColor: Colors.redAccent),
      );
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xfff5f9fc),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(widget.title, style: const TextStyle(color: Color(0xff202936), fontWeight: FontWeight.w900)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hint,
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
          child: Text(widget.cancelLabel, style: const TextStyle(color: _muted)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}
