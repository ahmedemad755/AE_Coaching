import 'dart:io';

import 'package:ae_coaching/features/progress_photos/data/models/progress_photo.dart';
import 'package:ae_coaching/features/progress_photos/presentation/cubit/progress_photo_cubit.dart';
import 'package:ae_coaching/features/progress_photos/presentation/screens/progress_photo_history_screen.dart';
import 'package:ae_coaching/features/progress_photos/presentation/widgets/add_photo_preview_dialog.dart';
import 'package:ae_coaching/features/progress_photos/presentation/widgets/before_after_card.dart';
import 'package:ae_coaching/features/progress_photos/presentation/widgets/photo_source_sheet.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

/// Progress Photos home screen: shows "Since Latest Photo" and
/// "Overall Progress" Before/After comparisons, plus access to the
/// full photo history.
///
/// Completely separate from Workout/Measurements — only ever talks to
/// [ProgressPhotoCubit].
class ProgressPhotosScreen extends StatefulWidget {
  const ProgressPhotosScreen({super.key});

  @override
  State<ProgressPhotosScreen> createState() => _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends State<ProgressPhotosScreen> {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _muted = Color(0xff7d8792);

  Box<ProgressPhoto>? _box;

  @override
  void initState() {
    super.initState();
    context.read<ProgressPhotoCubit>().loadPhotos();
  }

  Future<void> _addPhoto() async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    final confirmedDate = await showDialog<DateTime>(
      context: context,
      builder: (_) => AddPhotoPreviewDialog(
        imageFile: File(picked.path),
        initialDate: DateTime.now(),
      ),
    );

    if (confirmedDate != null && mounted) {
      context.read<ProgressPhotoCubit>().addPhoto(sourceFile: File(picked.path), date: confirmedDate);
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ProgressPhotoCubit>(),
          child: const ProgressPhotoHistoryScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xfff5f9fc),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Text(l10n.progressPhotosTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPhoto,
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 10,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(l10n.addPhotoButton, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: BlocConsumer<ProgressPhotoCubit, ProgressPhotoState>(
        listener: (context, state) {
          if (state is ProgressPhotoSuccess && _box != state.box) {
            setState(() => _box = state.box);
          }
          if (state is ProgressPhotoError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
            );
          }
        },
        builder: (context, state) {
          final box = _box;

          if (box == null) {
            if (state is ProgressPhotoError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.unableToLoadPhotos,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.read<ProgressPhotoCubit>().loadPhotos(),
                        style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          return ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<ProgressPhoto> liveBox, _) {
              final ascending = liveBox.values.toList()..sort((a, b) => a.date.compareTo(b.date));

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                children: [
                  if (ascending.isEmpty)
                    _EmptyState(onAdd: _addPhoto)
                  else ...[
                    if (ascending.length < 2)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xffdce6eb),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.notEnoughDataYet,
                          style: const TextStyle(color: Color(0xff52606c), fontWeight: FontWeight.w700),
                        ),
                      )
                    else ...[
                      BeforeAfterCard(
                        title: l10n.sinceLatestPhoto,
                        before: ascending[ascending.length - 2],
                        after: ascending.last,
                      ),
                      BeforeAfterCard(
                        title: l10n.overallProgress,
                        before: ascending.first,
                        after: ascending.last,
                      ),
                    ],
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openHistory,
                    icon: const Icon(Icons.history, color: _blue),
                    label: Text(l10n.historyButton, style: const TextStyle(fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      side: const BorderSide(color: _blue),
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 9)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.photo_camera_back_outlined, color: _blue, size: 40),
          const SizedBox(height: 14),
          Text(
            l10n.noPhotosYetTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.addFirstPhotoSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(l10n.addPhotoButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
