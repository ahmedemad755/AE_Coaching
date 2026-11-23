import 'dart:async';

import 'package:ae_coaching/core/sync/revision_cloud.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// [RevisionCloud] on `users/{uid}/{collection}`.
///
/// - Reads always come from the SERVER (`Source.server`), never Firestore's
///   local cache: the cache also shows our own writes that have not reached
///   the server yet, which must never be mistaken for confirmed state.
/// - Writes are merges (fields not sent, like an old-format backup, are
///   kept) with the server time as `serverUpdatedAt`. Firestore queues a
///   write made offline; this method stops waiting after [timeout] and
///   reports [CloudUnavailable], and the sync engine later finds out from
///   the server whether that queued write landed (by its writeId).
/// - `permission-denied` means the security rules refused the write
///   ([CloudWriteRejected]); every other failure is [CloudUnavailable].
class FirestoreRevisionCloud implements RevisionCloud {
  FirestoreRevisionCloud({
    required this.collection,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.timeout = const Duration(seconds: 20),
  }) : _firestoreOverride = firestore,
       _authOverride = auth;

  final String collection;
  final Duration timeout;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  // Resolved on use, not at construction (no Firebase app in unit tests).
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static const _fromServer = GetOptions(source: Source.server);

  CollectionReference<Map<String, dynamic>> _collection() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const CloudUnavailable('Not signed in.');
    }
    return _firestore.collection('users').doc(uid).collection(collection);
  }

  /// A refused write is [CloudWriteRejected]; a refused read is
  /// [CloudReadDenied] (handled like being offline: nothing is known).
  Future<R> _guard<R>(Future<R> Function() action, {required bool read}) async {
    try {
      return await action().timeout(timeout);
    } on TimeoutException {
      throw const CloudUnavailable('Timed out.');
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        final message = error.message ?? 'permission-denied';
        throw read ? CloudReadDenied(message) : CloudWriteRejected(message);
      }
      throw CloudUnavailable(error.code);
    }
  }

  /// `serverUpdatedAt` (a Firestore Timestamp) becomes
  /// [CloudDoc.serverUpdatedAt]; the remaining fields are plain values.
  static CloudDoc _toCloudDoc(String id, Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.of(raw);
    final stamp = data.remove('serverUpdatedAt');
    return CloudDoc(
      id,
      data,
      serverUpdatedAt: stamp is Timestamp ? stamp.toDate().toUtc() : null,
    );
  }

  @override
  Future<CloudDoc?> fetch(String id) => _guard(read: true, () async {
    final snapshot = await _collection().doc(id).get(_fromServer);
    final data = snapshot.data();
    return data == null ? null : _toCloudDoc(id, data);
  });

  @override
  Future<List<CloudDoc>> fetchAll() => _guard(read: true, () async {
    final snapshot = await _collection().get(_fromServer);
    return [for (final doc in snapshot.docs) _toCloudDoc(doc.id, doc.data())];
  });

  @override
  Future<List<CloudDoc>> fetchChangedSince(DateTime since) => _guard(
    read: true,
    () async {
      final snapshot = await _collection()
          .where(
            'serverUpdatedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(since),
          )
          .get(_fromServer);
      return [for (final doc in snapshot.docs) _toCloudDoc(doc.id, doc.data())];
    },
  );

  @override
  Future<void> write(String id, Map<String, dynamic> data) => _guard(
    read: false,
    () => _collection().doc(id).set({
      ...data,
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)),
  );
}
