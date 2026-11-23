import 'package:ae_coaching/features/account_deletion/application/local_account_data_wiper.dart';
import 'package:ae_coaching/features/account_deletion/domain/account_deletion.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

enum DeletionCompletion {
  /// No deletion was started on this device.
  none,

  /// A deletion started but the account still exists (interrupted, or that
  /// can't be checked now): it must be finished with the password.
  incomplete,

  /// Firebase reports the account gone: local data removed, signed out.
  accountDeleted,

  /// The deleting account is no longer signed in here: its local data was
  /// removed (as the user asked).
  localDataRemoved,
}

/// The device side of in-app account deletion, across app restarts.
///
/// [markStarted] is recorded before anything is deleted. After the server
/// side succeeded, [completeLocally] removes the account's device data and
/// signs out. If the app is interrupted in between, [finalizeIfCompleted]
/// (app start, deletion screen) finds out what happened: account gone →
/// finish locally; account still there → deletion incomplete (the user
/// completes it with their password); another or no account signed in →
/// remove the deleting account's device data.
class AccountDeletionLifecycle {
  AccountDeletionLifecycle({
    required Box authBox,
    required AccountDeletionRepository repository,
    required LocalAccountDataWiper wiper,
    required String? Function() currentUid,
    required Future<void> Function() signOut,
    required Future<void> Function() clearFirestoreCache,
  }) : _authBox = authBox,
       _repository = repository,
       _wiper = wiper,
       _currentUid = currentUid,
       _signOut = signOut,
       _clearFirestoreCache = clearFirestoreCache;

  static const inProgressUidKey = 'accountDeletionInProgressUid';

  final Box _authBox;
  final AccountDeletionRepository _repository;
  final LocalAccountDataWiper _wiper;
  final String? Function() _currentUid;
  final Future<void> Function() _signOut;
  final Future<void> Function() _clearFirestoreCache;

  String? get inProgressUid {
    final value = _authBox.get(inProgressUidKey);
    return value is String && value.isNotEmpty ? value : null;
  }

  bool isInProgress(String uid) => inProgressUid == uid;

  Future<void> markStarted(String uid) => _authBox.put(inProgressUidKey, uid);

  /// The account was deleted on the server: remove its device data, then
  /// sign out. A failed cleanup keeps the marker (retried at next start),
  /// but the user is signed out regardless.
  Future<void> completeLocally(String uid) async {
    try {
      await _wiper.wipe(uid);
      await _authBox.delete(inProgressUidKey);
    } finally {
      await _signOut();
    }
  }

  Future<DeletionCompletion> finalizeIfCompleted() async {
    final uid = inProgressUid;
    if (uid == null) return DeletionCompletion.none;
    if (_currentUid() == uid) {
      if (await _repository.accountStillExists() != false) return DeletionCompletion.incomplete;
      await completeLocally(uid);
      return DeletionCompletion.accountDeleted;
    }
    await _wiper.wipe(uid);
    await _authBox.delete(inProgressUidKey);
    return DeletionCompletion.localDataRemoved;
  }

  /// App start, BEFORE anything uses Firestore: settles an interrupted
  /// deletion, then clears the Firestore cache if a cleanup asked for it.
  /// A failed cleanup keeps its marker and is retried at the next start.
  Future<DeletionCompletion> completeAtStartup({required Future<void> Function() waitForAuthRestore}) async {
    var result = DeletionCompletion.none;
    if (inProgressUid != null) {
      await waitForAuthRestore();
      try {
        result = await finalizeIfCompleted();
      } catch (error) {
        debugPrint('Account deletion cleanup deferred to the next start: $error');
      }
    }
    await clearFirestoreCacheIfNeeded();
    return result;
  }

  Future<void> clearFirestoreCacheIfNeeded() async {
    if (_authBox.get(LocalAccountDataWiper.clearFirestoreCacheKey) != true) return;
    try {
      await _clearFirestoreCache();
      await _authBox.delete(LocalAccountDataWiper.clearFirestoreCacheKey);
    } catch (error) {
      debugPrint('Clearing the Firestore cache failed; retried next start: $error');
    }
  }
}
