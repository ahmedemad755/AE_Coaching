import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Updates only the existing profile name field. Phone changes remain in the
/// verified OTP flow and are intentionally not exposed as ordinary edits.
class UserProfileRepository {
  UserProfileRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> updateName({required String uid, required String name}) async {
    final trimmedName = name.trim();
    if (uid.isEmpty || _auth.currentUser?.uid != uid) {
      throw StateError('Refusing to update another user profile.');
    }
    if (trimmedName.isEmpty || trimmedName.length > 80) {
      throw ArgumentError.value(
        name,
        'name',
        'Name must contain 1-80 characters.',
      );
    }

    await _firestore.collection('users').doc(uid).update({'name': trimmedName});
    final user = _auth.currentUser;
    if (user != null && user.uid == uid) {
      try {
        await user.updateDisplayName(trimmedName);
      } catch (_) {
        // Firestore is the profile source of truth; Auth display name is a fallback.
      }
    }
  }
}
