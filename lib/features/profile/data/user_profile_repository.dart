import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Updates only the profile name of the signed-in user.
///
/// The write matches the `users/{uid}` update rule in firestore.rules:
/// the name follows [AuthInputRules.validateName] (normalized, 1–60
/// characters, at least one letter), `updatedAt` is stamped with the
/// server time, and `uid` is written as the owner so a historical profile
/// without a `uid` field is repaired instead of rejected. Email and other
/// identity fields are never touched here.
class UserProfileRepository {
  UserProfileRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> updateName({required String uid, required String name}) async {
    if (uid.isEmpty || _auth.currentUser?.uid != uid) {
      throw StateError('Refusing to update another user profile.');
    }
    if (AuthInputRules.validateName(name) != null) {
      throw ArgumentError.value(
        name,
        'name',
        'Name must contain 1-${AuthInputRules.nameMaxLength} characters '
            'and at least one letter.',
      );
    }
    final normalizedName = AuthInputRules.normalizeName(name);

    await _firestore.collection('users').doc(uid).update({
      'uid': uid,
      'name': normalizedName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final user = _auth.currentUser;
    if (user != null && user.uid == uid) {
      try {
        await user.updateDisplayName(normalizedName);
      } catch (_) {
        // Firestore is the profile source of truth; Auth display name is a fallback.
      }
    }
  }
}
