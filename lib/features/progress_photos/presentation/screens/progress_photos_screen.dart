import 'dart:io';

import 'package:ae_coaching/features/progress_photos/data/models/progress_photo.dart';
import 'package:ae_coaching/features/progress_photos/presentation/cubit/progress_photo_cubit.dart';
import 'package:ae_coaching/features/progress_photos/presentation/screens/progress_photo_history_screen.dart';
import 'package:ae_coaching/features/progress_photos/presentation/widgets/add_photo_preview_dialog.dart';
import 'package:ae_coaching/features/progress_photos/presentation/widgets/before_after_card.dart';
import 'package:ae_coaching/features/progress_photos/presentation/widgets/photo_source_sheet.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
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
  Box<ProgressPhoto>? _box;

  @override
  void initState() {
    super.initState();
    context.read<ProgressPhotoCubit>().loadPhotos();
  }

  Future<void> _addPhoto() async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;

    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final confirmedDate = await showDialog<DateTime>(
      context: context,
      builder: (_) => AddPhotoPreviewDialog(
        imageFile: File(picked.path),
        initialDate: DateTime.now(),
      ),
    );

    if (confirmedDate != null && mounted) {
      context.read<ProgressPhotoCubit>().addPhoto(
        sourceFile: File(picked.path),
        date: confirmedDate,
      );
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
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(l10n.progressPhotosTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPhoto,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 10,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(
          l10n.addPhotoButton,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: BlocConsumer<ProgressPhotoCubit, ProgressPhotoState>(
        listener: (context, state) {
          if (state is ProgressPhotoSuccess && _box != state.box) {
            setState(() => _box = state.box);
          }
          if (state is ProgressPhotoError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
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
                        style: TextStyle(
                          color: context.appColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            context.read<ProgressPhotoCubit>().loadPhotos(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                        ),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          return ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<ProgressPhoto> liveBox, _) {
              final ascending = liveBox.values.toList()
                ..sort((a, b) => a.date.compareTo(b.date));

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
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l10n.notEnoughDataYet,
                          style: TextStyle(
                            color: context.appColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
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
                    icon: Icon(
                      Icons.history,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    label: Text(
                      l10n.historyButton,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.photo_camera_back_outlined,
            color: scheme.primary,
            size: 40,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.noPhotosYetTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.addFirstPhotoSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(l10n.addPhotoButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
