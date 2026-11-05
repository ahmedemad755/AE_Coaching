import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

/// Stores profile photos locally, using a UID-specific directory and Hive key.
/// The picker path is copied into persistent application storage before it is
/// referenced, so temporary picker files are never treated as durable data.
class LocalProfilePhotoStore {
  LocalProfilePhotoStore(
    this._box, {
    Future<Directory> Function()? documentsDirectory,
    DateTime Function()? clock,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _clock = clock ?? DateTime.now;

  final Box _box;
  final Future<Directory> Function() _documentsDirectory;
  final DateTime Function() _clock;

  static const int maxImageBytes = 20 * 1024 * 1024;

  static String _key(String uid) => 'profilePhotoPath.$uid';

  String _uidDirectory(String uid, String documentsPath) {
    final digest = sha256.convert(utf8.encode(uid)).toString();
    return '$documentsPath/profile_photos/$digest';
  }

  Future<String?> getPhotoPath(String uid) async {
    _requireUid(uid);
    final value = _box.get(_key(uid));
    if (value is! String || value.isEmpty) return null;

    final directory = await _documentsDirectory();
    final ownDirectory = _uidDirectory(uid, directory.path);
    // File.absolute preserves mixed separators on Windows. File URIs
    // canonicalize them and resolve dot segments before checking ownership.
    final photoUri = File(value).absolute.uri.normalizePath();
    final directoryUri = Directory(ownDirectory).absolute.uri.normalizePath();
    if (!photoUri.path.startsWith(directoryUri.path)) {
      return null;
    }
    final normalizedPath = photoUri.toFilePath();
    return await File(normalizedPath).exists() ? normalizedPath : null;
  }

  Future<String> savePhoto({required String uid, required File source}) async {
    _requireUid(uid);
    if (!await source.exists()) {
      throw const FileSystemException('Image not found.');
    }
    final length = await source.length();
    if (length == 0 || length > maxImageBytes) {
      throw const FileSystemException('Unsupported image size.');
    }

    final documents = await _documentsDirectory();
    final directory = Directory(_uidDirectory(uid, documents.path));
    await directory.create(recursive: true);

    final stamp =
        '${_clock().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final temporary = File.fromUri(directory.uri.resolve('$stamp.tmp'));
    final saved = File.fromUri(directory.uri.resolve('$stamp.jpg'));
    final previousPath = await getPhotoPath(uid);
    try {
      await source.copy(temporary.path);
      await temporary.rename(saved.path);
      await _box.put(_key(uid), saved.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      if (await saved.exists()) await saved.delete();
      rethrow;
    }

    if (previousPath != null && previousPath != saved.path) {
      try {
        await File(previousPath).delete();
      } on FileSystemException {
        // The new pointer is already committed; a leftover old image is safe.
      }
    }
    return saved.path;
  }

  Future<void> removePhoto(String uid) async {
    _requireUid(uid);
    final previousPath = await getPhotoPath(uid);
    if (previousPath != null) {
      final file = File(previousPath);
      try {
        await file.delete();
      } on FileSystemException {
        if (await file.exists()) rethrow;
      }
    }
    await _box.delete(_key(uid));
  }

  void _requireUid(String uid) {
    if (uid.trim().isEmpty) {
      throw StateError('An authenticated user is required.');
    }
  }
}
