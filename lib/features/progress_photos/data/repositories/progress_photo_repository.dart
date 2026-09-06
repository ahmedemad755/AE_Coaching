import 'dart:io';

import 'package:ae_coaching/features/progress_photos/data/models/progress_photo.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Handles Hive metadata + local file storage for progress photos.
///
/// Photos are local-only by design (per-user choice): the image file
/// lives in the app's documents directory, and only its path + date are
/// kept in the per-user `progress_photos_$uid` Hive box — same naming
/// pattern as `sets_$uid` / `measurements_$uid`, but a completely
/// separate box so this feature never touches workout or measurement
/// data.
class ProgressPhotoRepository {
  Future<Box<ProgressPhoto>> getUserBox() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    final boxName = 'progress_photos_$uid';
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<ProgressPhoto>(boxName);
    }

    return Hive.openBox<ProgressPhoto>(boxName);
  }

  /// Copies [sourceFile] into the app's documents directory (so it
  /// survives the OS ever clearing a cache/temp dir the picker used)
  /// and records it dated [date].
  Future<void> addPhoto({
    required File sourceFile,
    required DateTime date,
    String? note,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${docsDir.path}/progress_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final extension = sourceFile.path.contains('.') ? sourceFile.path.split('.').last : 'jpg';
    final fileName = '${uid}_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final savedFile = await sourceFile.copy('${photosDir.path}/$fileName');

    final box = await getUserBox();
    await box.add(
      ProgressPhoto(date: date, imagePath: savedFile.path, note: note),
    );
  }

  /// Deletes both the Hive entry and its underlying file so nothing is
  /// left orphaned on disk.
  Future<void> deletePhoto(ProgressPhoto photo) async {
    final box = await getUserBox();
    await box.delete(photo.key);

    try {
      final file = File(photo.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Non-fatal: the Hive record is already gone, a leftover file on
      // disk doesn't affect app correctness.
    }
  }

  /// Returns every stored photo for the current user, newest first.
  List<ProgressPhoto> getAllSorted(Box<ProgressPhoto> box) {
    final all = box.values.toList();
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }
}
