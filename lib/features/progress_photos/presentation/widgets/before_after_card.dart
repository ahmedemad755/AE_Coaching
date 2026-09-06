import 'dart:io';

import 'package:ae_coaching/features/progress_photos/data/models/progress_photo.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One "Before → After" comparison: two photos side by side with their
/// dates. Used for both the "Since Latest Photo" and "Overall
/// Progress" cards on the main screen.
class BeforeAfterCard extends StatelessWidget {
  final String title;
  final ProgressPhoto before;
  final ProgressPhoto after;

  const BeforeAfterCard({
    super.key,
    required this.title,
    required this.before,
    required this.after,
  });

  static const Color _dark = Color(0xff202936);
  static const Color _blue = Color(0xff2f80ed);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _PhotoTile(label: l10n.beforeLabel, photo: before)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward, color: _blue),
              ),
              Expanded(child: _PhotoTile(label: l10n.afterLabel, photo: after)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String label;
  final ProgressPhoto photo;

  const _PhotoTile({required this.label, required this.photo});

  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  Widget build(BuildContext context) {
    final dateLocale = Localizations.localeOf(context).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 11),
        ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(photo.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xffeaf2fc),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined, color: _muted),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('d MMM yyyy', dateLocale).format(photo.date),
          textAlign: TextAlign.center,
          style: const TextStyle(color: _dark, fontWeight: FontWeight.w700, fontSize: 11),
        ),
      ],
    );
  }
}
