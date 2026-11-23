import 'dart:async';
import 'dart:math';

import 'package:ae_coaching/features/account_deletion/domain/account_deletion.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, visibleForTesting;

class FirebaseAccountDeletionRepository implements AccountDeletionRepository {
  FirebaseAccountDeletionRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    this.serverTimeout = const Duration(seconds: 20),
    @visibleForTesting this.debugStep,
  }) : _auth = auth,
       _firestore = firestore;

  /// Called before each step (`collection:<name>`, `tombstones:<name>`,
  /// `settings`, `profile`, `auth`): integration tests cut the network or
  /// change data at an exact point. Never set by the app.
  final Future<void> Function(String step)? debugStep;

  /// Every subcollection the app writes under `users/{uid}` and is allowed
  /// to list (firestore.rules). Deleting the profile document does NOT
  /// delete these, so each is emptied first. `settings/notifications` is a
  /// single known document (not listable) and is deleted by id.
  /// Server-owned data (`notificationState`, `fcmTokenOwners`) is only
  /// written by Cloud Functions, which are not deployed on Spark.
  static const userCollections = [
    'exercise_sets',
    'workout_sessions',
    'workout_templates',
    'custom_exercises',
    'workout_programs',
    'body_measurements',
    'fcmTokens',
  ];

  /// Collections synced by RevisionSyncEngine. firestore.rules lets a
  /// schema 2 document be deleted only once it is a tombstone, so a live
  /// one is first tombstoned with a revision-checked write, then deleted.
  static const revisionedCollections = {
    'workout_templates',
    'custom_exercises',
  };

  /// New in Stage 2. Until its rules are deployed, listing it is denied and
  /// nothing can have been written to it, so a denied read means "empty".
  static const _newCollections = {'custom_exercises'};

  /// Re-reads allowed when another device changes a document between this
  /// device reading it and tombstoning it.
  static const _maxTombstoneAttempts = 5;

  /// Firestore allows 500 writes per batch.
  static const _batchSize = 400;

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final Duration serverTimeout;
  FirebaseAuth get _authInstance => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> reauthenticate(String password) async {
    final user = _authInstance.currentUser;
    if (user == null) {
      throw const AccountDeletionException(AccountDeletionFailure.notSignedIn);
    }
    final email = user.email;
    final usesPassword = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
    if (email == null || email.isEmpty || !usesPassword) {
      throw const AccountDeletionException(
        AccountDeletionFailure.unsupportedSignIn,
      );
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      // A fresh ID token carries the new sign-in time the rules check.
      await user.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      throw AccountDeletionException(_authFailure(error));
    }
  }

  @override
  Future<void> deleteAccount(String uid) async {
    final user = _authInstance.currentUser;
    if (user == null || user.uid != uid) {
      throw const AccountDeletionException(AccountDeletionFailure.notSignedIn);
    }
    final profile = _db.collection('users').doc(uid);
    try {
      // Writes still queued from this device go first, so none of them can
      // recreate a document after it was deleted.
      await _db.waitForPendingWrites().timeout(serverTimeout);
      await debugStep?.call('lock');
      await _lockAccount(profile);
      for (final name in userCollections) {
        await debugStep?.call('collection:$name');
        await _deleteAll(profile.collection(name));
      }
      await debugStep?.call('settings');
      await _commit(
        _db.batch()
          ..delete(profile.collection('settings').doc('notifications')),
      );
      await debugStep?.call('profile');
      await _commit(_db.batch()..delete(profile));
    } on TimeoutException {
      throw const AccountDeletionException(AccountDeletionFailure.offline);
    } on FirebaseException catch (error) {
      throw AccountDeletionException(_firestoreFailure(error));
    }
    // Last: once the data is confirmed gone on the server.
    await debugStep?.call('auth');
    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') return; // already deleted
      throw AccountDeletionException(_authFailure(error));
    }
  }

  /// First step of a deletion: stamps `deletionStartedAt` on the profile.
  /// From then on firestore.rules refuse creating anything new for the
  /// account, so another device still signed in (its ID token stays valid
  /// for up to an hour) can't bring data back, while everything left can
  /// still be read and deleted. The profile itself is deleted near the end.
  /// Already deleted by an earlier attempt: nothing to lock (nothing can be
  /// created without a profile either). Checked by reading the SERVER copy
  /// first: an update of a missing document is refused by the rules
  /// (permission-denied), not reported as not-found.
  ///
  /// A refused lock never stops the deletion: before the Stage 2.2 rules are
  /// deployed the lock doesn't exist yet (the deletion works as before); with
  /// them, a refusal can only mean a sign-in that isn't recent or another
  /// account, which the later steps refuse too, before the Auth account.
  Future<void> _lockAccount(
    DocumentReference<Map<String, dynamic>> profile,
  ) async {
    final current = await profile
        .get(const GetOptions(source: Source.server))
        .timeout(serverTimeout);
    if (!current.exists) return;
    try {
      await profile
          .update({'deletionStartedAt': FieldValue.serverTimestamp()})
          .timeout(serverTimeout);
    } on FirebaseException catch (error) {
      if (error.code == 'not-found') return;
      if (error.code != 'permission-denied') rethrow;
      if (kDebugMode) debugPrint('[AccountDeletion] lock refused; continuing');
    }
  }

  @override
  Future<bool?> accountStillExists() async {
    final user = _authInstance.currentUser;
    if (user == null) return null;
    try {
      await user.reload();
      return true;
    } on FirebaseAuthException catch (error) {
      return switch (error.code) {
        'user-not-found' || 'user-disabled' || 'user-token-expired' => false,
        _ => null,
      };
    }
  }

  /// The revision-checked tombstone a live schema 2 document needs before it
  /// can be deleted (firestore.rules), or null when it can be deleted as it
  /// is (schema 1, or already a tombstone). The caller adds
  /// `serverUpdatedAt` and writes it with merge, keeping the content.
  @visibleForTesting
  static Map<String, dynamic>? tombstoneBeforeDelete(
    Map<String, dynamic> data, {
    required String writeId,
    required DateTime now,
  }) {
    if (data['schemaVersion'] != 2 || data['deleted'] == true) return null;
    final revision = (data['revision'] as num?)?.toInt() ?? 0;
    return {
      'schemaVersion': 2,
      'baseRevision': revision,
      'revision': revision + 1,
      'writeId': writeId,
      'contentHash': data['contentHash'],
      'deleted': true,
      'deletedAt': now.toUtc().toIso8601String(),
    };
  }

  static final _random = Random.secure();

  static String _deletionWriteId() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final suffix = _random.nextInt(1 << 32).toRadixString(36);
    return 'account-deletion-$time-$suffix';
  }

  /// Reads from the SERVER (never the cache) and deletes page by page, each
  /// page confirmed by the server before the next. In [revisionedCollections],
  /// live schema 2 documents are tombstoned first (a separate commit: the
  /// rules of a batch see the documents as they were before it), then the
  /// page is read again and deleted.
  Future<void> _deleteAll(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final revisioned = revisionedCollections.contains(collection.id);
    var tombstoneAttempts = 0;
    for (;;) {
      final QuerySnapshot<Map<String, dynamic>> page;
      try {
        page = await collection
            .limit(_batchSize)
            .get(const GetOptions(source: Source.server))
            .timeout(serverTimeout);
      } on FirebaseException catch (error) {
        final ruleNotDeployedYet =
            error.code == 'permission-denied' &&
            _newCollections.contains(collection.id);
        if (ruleNotDeployedYet) return;
        rethrow;
      }
      if (page.docs.isEmpty) return;
      if (revisioned) {
        final tombstones = _db.batch();
        var live = 0;
        for (final doc in page.docs) {
          final tombstone = tombstoneBeforeDelete(
            doc.data(),
            writeId: _deletionWriteId(),
            now: DateTime.now(),
          );
          if (tombstone == null) continue;
          tombstones.set(doc.reference, {
            ...tombstone,
            'serverUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          live++;
        }
        if (live > 0) {
          await debugStep?.call('tombstones:${collection.id}');
          try {
            await _commit(tombstones);
          } on FirebaseException catch (error) {
            // Most likely another device changed one of these documents
            // since the page was read (its revision moved on): read again.
            if (error.code != 'permission-denied') rethrow;
            if (++tombstoneAttempts >= _maxTombstoneAttempts) {
              // Not a sign-in problem: still changing elsewhere. Nothing
              // is lost; the user can simply try again.
              throw const AccountDeletionException(
                AccountDeletionFailure.unknown,
              );
            }
          }
          continue;
        }
      }
      final batch = _db.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await _commit(batch);
    }
  }

  /// A batch completes only when the server commits it.
  Future<void> _commit(WriteBatch batch) =>
      batch.commit().timeout(serverTimeout);

  static AccountDeletionFailure _authFailure(FirebaseAuthException error) =>
      switch (error.code) {
        'wrong-password' ||
        'invalid-credential' ||
        'invalid-login-credentials' => AccountDeletionFailure.wrongPassword,
        'too-many-requests' => AccountDeletionFailure.tooManyAttempts,
        'network-request-failed' => AccountDeletionFailure.offline,
        'requires-recent-login' => AccountDeletionFailure.recentSignInRequired,
        'user-mismatch' ||
        'user-not-found' ||
        'user-disabled' => AccountDeletionFailure.notSignedIn,
        _ => AccountDeletionFailure.unknown,
      };

  static AccountDeletionFailure _firestoreFailure(FirebaseException error) =>
      switch (error.code) {
        'unavailable' || 'deadline-exceeded' => AccountDeletionFailure.offline,
        // Rules: the profile, settings and device list need a fresh sign-in.
        'permission-denied' ||
        'unauthenticated' => AccountDeletionFailure.recentSignInRequired,
        _ => AccountDeletionFailure.unknown,
      };
}
