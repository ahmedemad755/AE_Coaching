import 'dart:io';

import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/profile/data/local_profile_photo_store.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Removes everything this DEVICE holds for one account, and nothing of any
/// other account: per-user Hive boxes, progress and profile photos,
/// per-account preferences, the session (only if it is that account's) and,
/// through [accountHooks], in-memory state, local reminders and the device's
/// push registration. Marks the Firestore cache for clearing (done at the
/// next start, before Firestore is used).
///
/// Every step runs even if an earlier one fails; failures are rethrown at
/// the end so the caller keeps its pending marker and retries (every step is
/// idempotent).
class LocalAccountDataWiper {
  LocalAccountDataWiper({
    required UserStorageManager storage,
    required LocalProfilePhotoStore profilePhotos,
    required Box authBox,
    required SessionStorage session,
    required Future<Directory> Function() documentsDirectory,
    required List<Future<void> Function(String uid)> accountHooks,
  }) : _storage = storage,
       _profilePhotos = profilePhotos,
       _authBox = authBox,
       _session = session,
       _documentsDirectory = documentsDirectory,
       _accountHooks = accountHooks;

  /// Read at startup by [AccountDeletionLifecycle].
  static const clearFirestoreCacheKey = 'firestoreCacheClearPending';

  final UserStorageManager _storage;
  final LocalProfilePhotoStore _profilePhotos;
  final Box _authBox;
  final SessionStorage _session;
  final Future<Directory> Function() _documentsDirectory;
  final List<Future<void> Function(String uid)> _accountHooks;

  /// Per-account keys other features keep in `authBox`.
  static List<String> perAccountKeys(String uid) => [
    'themeMode.$uid',
    'inactivityRemindersEnabled:$uid', // retired on-device reminder
  ];

  Future<void> wipe(String uid) async {
    if (uid.isEmpty) throw ArgumentError.value(uid, 'uid', 'required');
    final failures = <String>[];
    Future<void> step(String name, Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        debugPrint('Local account data cleanup step "$name" failed: $error');
        failures.add(name);
      }
    }

    for (final hook in _accountHooks) {
      await step('account_hook', () => hook(uid));
    }
    await step('hive_boxes', () => _storage.deleteForUser(uid));
    await step('progress_photos', () => _deleteProgressPhotoFiles(uid));
    await step('profile_photo', () => _profilePhotos.deleteForUser(uid));
    await step('preferences', () => _authBox.deleteAll(perAccountKeys(uid)));
    await step('session', () async {
      if (_session.currentUserUid == uid) await _session.clearSession();
    });
    await step('firestore_cache', () => _authBox.put(clearFirestoreCacheKey, true));
    if (failures.isNotEmpty) {
      throw StateError('Local account data cleanup incomplete: ${failures.join(', ')}');
    }
  }

  /// ProgressPhotoRepository names files `<uid>_<timestamp>.<ext>`.
  Future<void> _deleteProgressPhotoFiles(String uid) async {
    final directory = Directory('${(await _documentsDirectory()).path}/progress_photos');
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is File && entity.uri.pathSegments.last.startsWith('${uid}_')) {
        await entity.delete();
      }
    }
  }
}
