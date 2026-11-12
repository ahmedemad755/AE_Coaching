import 'package:ae_coaching/core/bootstrap/startup_destination.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The signed-in account that may read and write its notification
/// preferences: the same verified identity firestore.rules require.
/// Every preference operation is bound to the uid returned here and
/// re-checks it before writing, so a write can never land under another
/// account after a sign-out or account switch.
class VerifiedAccount {
  VerifiedAccount({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;

  String? currentUid() {
    final snapshot = StartupAuthSnapshot.read(auth: _auth ?? FirebaseAuth.instance);
    return hasVerifiedEmailIdentity(snapshot) ? snapshot.firebaseUid : null;
  }
}
