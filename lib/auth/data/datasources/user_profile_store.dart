import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:ae_coaching/auth/domain/validation/profile_integrity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}` profile access for the email-first flow. A seam, so the
/// data source's decisions can be tested without Firestore.
/// Implementations throw [FirebaseException] on failure. They never
/// swallow it, so `permission-denied` always reaches the caller.
///
/// Profile shape (Stage 3B): `uid`, `name`, `email`, `createdAt`,
/// `updatedAt`. Never a password, token or verification flag: Firebase
/// Auth is authoritative for those.
abstract class UserProfileStore {
  Future<Map<String, dynamic>?> read(String uid);

  /// Makes the profile [ProfileCondition.valid] without destroying data,
  /// following [assessProfile]:
  /// - missing     → create every field;
  /// - repairable  → fill ONLY the missing/invalid required fields
  ///                 (`uid`, `name`) plus absent `email`/`createdAt`;
  /// - valid       → untouched (a retry is a no-op);
  /// - conflicting → untouched (never write another account's document).
  ///
  /// `createdAt` and a valid existing `name` are never overwritten.
  Future<void> createOrRepair({
    required String uid,
    required String name,
    required String email,
  });

  /// Keeps the display copy of the email in sync after an email change.
  /// Only `email` and `updatedAt` change.
  Future<void> updateEmail({required String uid, required String email});
}

/// Computes the write [createOrRepair] performs. Pure, so the
/// field-preservation rules are unit-tested without Firestore. `null` =
/// no write. [now] is the timestamp sentinel to use.
Map<String, dynamic>? profileWriteFor({
  required Map<String, dynamic>? existing,
  required String uid,
  required String name,
  required String email,
  required Object now,
}) {
  switch (assessProfile(existing, uid)) {
    case ProfileCondition.valid:
    case ProfileCondition.conflicting:
      return null;
    case ProfileCondition.missing:
      return {
        'uid': uid,
        'name': name,
        'email': email,
        'createdAt': now,
        'updatedAt': now,
      };
    case ProfileCondition.repairable:
      final current = existing!;
      final currentName = current['name'];
      final nameValid =
          currentName is String &&
          AuthInputRules.validateName(currentName) == null;
      return {
        if (current['uid'] == null) 'uid': uid,
        if (!nameValid) 'name': name,
        if (current['email'] == null && email.isNotEmpty) 'email': email,
        if (current['createdAt'] == null) 'createdAt': now,
        'updatedAt': now,
      };
  }
}

class FirestoreUserProfileStore implements UserProfileStore {
  final FirebaseFirestore _firestore;

  FirestoreUserProfileStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Future<Map<String, dynamic>?> read(String uid) async {
    final snapshot = await _ref(uid).get();
    return snapshot.exists ? (snapshot.data() ?? <String, dynamic>{}) : null;
  }

  /// Transactional, so the decision and the write see the same document.
  /// This replaces the phone-era `set(..., SetOptions(merge: true))`, which
  /// re-stamped `createdAt` on every retry.
  @override
  Future<void> createOrRepair({
    required String uid,
    required String name,
    required String email,
  }) async {
    final ref = _ref(uid);
    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final write = profileWriteFor(
        existing: snapshot.exists ? snapshot.data() : null,
        uid: uid,
        name: name,
        email: email,
        now: FieldValue.serverTimestamp(),
      );
      if (write == null) return;
      if (snapshot.exists) {
        tx.update(ref, write);
      } else {
        tx.set(ref, write);
      }
    });
  }

  @override
  Future<void> updateEmail({required String uid, required String email}) =>
      _ref(
        uid,
      ).update({'email': email, 'updatedAt': FieldValue.serverTimestamp()});
}
