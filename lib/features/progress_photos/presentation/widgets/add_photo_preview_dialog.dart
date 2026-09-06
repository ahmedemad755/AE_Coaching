import 'dart:io';

import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shows the just-picked photo with an editable date (defaults to
/// [initialDate]) and returns the confirmed date via `Navigator.pop`,
/// or null if cancelled.
///
/// Shared by the standalone "Add Photo" flow and the after-save prompt
/// from the measurement form (which pre-fills the check-in's date).
class AddPhotoPreviewDialog extends StatefulWidget {
  final File imageFile;
  final DateTime initialDate;

  const AddPhotoPreviewDialog({
    super.key,
    required this.imageFile,
    required this.initialDate,
  });

  @override
  State<AddPhotoPreviewDialog> createState() => _AddPhotoPreviewDialogState();
}

class _AddPhotoPreviewDialogState extends State<AddPhotoPreviewDialog> {
  static const Color _blue = Color(0xff2f80ed);

  late DateTime _date = widget.initialDate;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: _blue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateLocale = Localizations.localeOf(context).toString();

    return AlertDialog(
      backgroundColor: const Color(0xfff5f9fc),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(l10n.choosePhotoSourceTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                widget.imageFile,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffd5e3f2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event, color: _blue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d MMM yyyy', dateLocale).format(_date),
                        style: const TextStyle(
                          color: Color(0xff202936),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      l10n.changeDateButton,
                      style: const TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _date),
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
