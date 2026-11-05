import 'dart:io';

import 'package:ae_coaching/features/progress_photos/data/models/progress_photo.dart';
import 'package:ae_coaching/features/progress_photos/presentation/cubit/progress_photo_cubit.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

/// Full gallery of every recorded progress photo, newest first, with
/// full-screen view and delete (with confirmation).
class ProgressPhotoHistoryScreen extends StatefulWidget {
  const ProgressPhotoHistoryScreen({super.key});

  @override
  State<ProgressPhotoHistoryScreen> createState() =>
      _ProgressPhotoHistoryScreenState();
}

class _ProgressPhotoHistoryScreenState
    extends State<ProgressPhotoHistoryScreen> {
  Box<ProgressPhoto>? _box;

  @override
  void initState() {
    super.initState();
    final state = context.read<ProgressPhotoCubit>().state;
    if (state is ProgressPhotoSuccess) {
      _box = state.box;
    }
  }

  Future<void> _confirmDelete(ProgressPhoto photo) async {
    final l10n = AppLocalizations.of(context)!;
    final dateLocale = Localizations.localeOf(context).toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.deletePhotoTitle,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        content: Text(
          l10n.deletePhotoBody(
            DateFormat('d MMM yyyy', dateLocale).format(photo.date),
          ),
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              l10n.delete,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<ProgressPhotoCubit>().deletePhoto(photo);
    }
  }

  void _viewFullScreen(ProgressPhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(child: Image.file(File(photo.imagePath))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateLocale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(l10n.photoHistoryTitle),
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
                child: Text(
                  l10n.unableToLoadPhotos,
                  style: TextStyle(
                    color: context.appColors.textMuted,
                    fontWeight: FontWeight.w700,
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
              final all = liveBox.values.toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              if (all.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '${l10n.noPhotosYetTitle}\n\n${l10n.addFirstPhotoSubtitle}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.appColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: all.length,
                itemBuilder: (context, index) {
                  final photo = all[index];
                  return GestureDetector(
                    onTap: () => _viewFullScreen(photo),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                              child: Image.file(
                                File(photo.imagePath),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: context.appColors.textMuted,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    DateFormat(
                                      'd MMM yyyy',
                                      dateLocale,
                                    ).format(photo.date),
                                    style: TextStyle(
                                      color: context.appColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _confirmDelete(photo),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.delete_outline,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
