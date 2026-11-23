import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Debug and profile builds only:
/// `--dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1`
/// points Auth and Firestore at the local Firebase Emulator (on a phone,
/// through `adb reverse tcp:8080 tcp:8080` and `adb reverse tcp:9099
/// tcp:9099`), so a development build can be tried on a device without
/// reaching the real project (profile builds run at near-release speed).
/// Ignored in release builds.
abstract final class DebugFirebaseEmulator {
  static const _host = String.fromEnvironment('FIREBASE_EMULATOR_HOST');

  static bool get enabled => !kReleaseMode && _host.isNotEmpty;

  /// Must run right after `Firebase.initializeApp`, before anything uses
  /// Auth or Firestore.
  static Future<void> connect() async {
    FirebaseFirestore.instance.useFirestoreEmulator(_host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(_host, 9099);
    // A sign-in kept from the real project means nothing to the emulator:
    // it is signed out here. Signing out deletes nothing on the phone.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final known = await user
          .reload()
          .timeout(const Duration(seconds: 5))
          .then<bool>(
            (_) => true,
            onError: (Object error) {
              debugPrint('[Emulator] kept sign-in not usable here: $error');
              return false;
            },
          );
      if (!known) await FirebaseAuth.instance.signOut();
    }
    debugPrint('[Emulator] Firebase Emulator at $_host (not a release build)');
  }
}
