import 'dart:async';

import 'package:ae_coaching/auth/domain/entities/auth_session_inspection.dart';
import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Phase 5B Stage 3 — OFF by default in every build, including normal
/// debug builds: only set when a developer explicitly passes
/// `--dart-define=USE_FUNCTIONS_EMULATOR=true`, and even then only takes
/// effect under [kDebugMode] (belt-and-braces: a stray dart-define can
/// never route a profile/release build to the emulator). This never
/// affects production — a normal `flutter run`/`flutter build` without
/// the dart-define behaves exactly as before.
const bool _useFunctionsEmulator = bool.fromEnvironment(
  'USE_FUNCTIONS_EMULATOR',
);

/// Host to reach the local Functions Emulator at. Defaults to
/// `localhost`, correct for iOS simulator/desktop. Override with
/// `--dart-define=FUNCTIONS_EMULATOR_HOST=10.0.2.2` for the Android
/// emulator (which does not see the host machine as `localhost`), or
/// with the host machine's LAN IP for a physical device on the same
/// network — `localhost` on a physical device would resolve to the
/// device itself, not the development machine, so it is deliberately
/// NOT assumed for anything other than the desktop/simulator default.
const String _functionsEmulatorHost = String.fromEnvironment(
  'FUNCTIONS_EMULATOR_HOST',
  defaultValue: 'localhost',
);

FirebaseFunctions _buildFunctionsInstance() {
  final instance = FirebaseFunctions.instanceFor(region: 'us-central1');
  if (kDebugMode && _useFunctionsEmulator) {
    instance.useFunctionsEmulator(_functionsEmulatorHost, 5001);
  }
  return instance;
}

abstract class AuthRemoteDataSource {
  Future<String> requestOtp(String phoneNumber);

  Future<AuthUser> registerWithOtp({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
    required String password,
  });

  Future<AuthUser> registerWithPhonePassword({
    required String name,
    required String phone,
    required String password,
  });

  Future<AuthUser> login(String phone, String password);

  Future<AuthSessionInspection> inspectCurrentSession();

  Future<void> linkPasswordToCurrentUser({
    required String phone,
    required String password,
  });

  Future<AuthUser> completeProfileForCurrentUser({
    required String name,
    required String phone,
  });

  /// Phase 4 — legacy migration. Sends an OTP to the ALREADY
  /// authenticated legacy account's own canonical phone (never a
  /// user-typed one). Distinct from [requestOtp] (fresh registration)
  /// even though both send SMS via the same underlying mechanism.
  Future<String> requestMigrationOtp(String phone);

  /// Phase 4 — legacy migration. Links the phone credential onto the
  /// CURRENTLY authenticated user via `linkWithCredential`. Never signs
  /// in with the phone credential and never creates a new Firebase user.
  Future<void> linkPhoneToCurrentUser({
    required String verificationId,
    required String smsCode,
  });

  /// Phase 5B — signed-out password reset. Calls the TRUSTED BACKEND
  /// (Cloud Function `requestPasswordReset`) to send an OTP for
  /// [phone]. The client makes no assumption about whether an account
  /// exists for it — the backend alone decides that, and never reveals
  /// it either way (see [verifyPasswordResetOtpAndUpdatePassword]).
  /// Returns an opaque backend-issued `challengeId` — never a Firebase
  /// phone-auth verificationId, and never usable with
  /// [PhoneAuthProvider].
  Future<String> requestPasswordResetOtp(String phone);

  /// Phase 5B — signed-out password reset. Calls the TRUSTED BACKEND
  /// (Cloud Function `completePasswordReset`) with [challengeId] (from
  /// [requestPasswordResetOtp]), the entered OTP, and the chosen new
  /// password. The client never calls `signInWithCredential`, never
  /// inspects `isNewUser`, and never calls `updatePassword` directly —
  /// the backend alone resolves identity and performs the update,
  /// which is what makes it provably impossible for this flow to
  /// create a Firebase Auth user (the client-only implementation this
  /// replaced could not make that guarantee — see the Phase 5B
  /// security audit).
  Future<void> verifyPasswordResetOtpAndUpdatePassword({
    required String challengeId,
    required String smsCode,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Phase 5B — pinned to the exact region the backend's callable
  // functions are deployed to (see functions/src/requestPasswordReset.ts
  // and completePasswordReset.ts, both explicit `region: 'us-central1'`).
  // Never left to the client-side default, so a future backend region
  // change can't silently mismatch.
  final FirebaseFunctions _functions = _buildFunctionsInstance();

  String _authEmailFromPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      throw Exception('Invalid phone number.');
    }
    return 'u$digitsOnly@ae-coaching.app';
  }

  /// Phase 4 helper: does [user] already have a phone sign-in provider
  /// linked? Used by login()'s needsPhoneVerification computation, by
  /// linkPhoneToCurrentUser's idempotency check, and (restart-bypass
  /// fix) by inspectCurrentSession's completed-profile branch — never
  /// by the Phase 3 needsPassword/needsProfile recovery branches, which
  /// are unrelated and unchanged.
  bool _hasPhoneProviderLinked(User user) {
    return user.providerData.any((p) => p.providerId == 'phone');
  }

  /// Links the synthetic email/password credential onto [user] — the
  /// SAME uid the caller already has signed in via phone. Never calls
  /// createUserWithEmailAndPassword.
  ///
  /// On the two collision codes that prove this exact synthetic email is
  /// permanently owned by a different (legacy) account, the just-created
  /// phone-only [user] is cleaned up (see [_cleanUpOrphanedPhoneOnlyUser])
  /// before a clear, user-facing error is thrown. Every other failure
  /// (weak-password, network, unexpected) is rethrown unchanged so the
  /// phone-authenticated session is preserved for a safe retry.
  Future<void> _linkPasswordLogin({
    required User user,
    required String phone,
    required String password,
  }) async {
    final emailCredential = EmailAuthProvider.credential(
      email: _authEmailFromPhone(phone),
      password: password,
    );

    try {
      await user.linkWithCredential(emailCredential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        return;
      }
      if (e.code == 'credential-already-in-use' ||
          e.code == 'email-already-in-use') {
        await _cleanUpOrphanedPhoneOnlyUser(user);
        throw Exception(
          'An account already exists for this phone. Please log in instead.',
        );
      }
      // weak-password, network-request-failed, and anything else:
      // preserve the phone-authenticated session and let the caller
      // surface a recoverable error — never delete here.
      throw Exception(_mapFirebaseAuthException(e));
    }
  }

  /// Bounded, non-destructive cleanup for the ONE scenario where a
  /// brand-new phone-only Firebase user was just created by this
  /// registration attempt, but the synthetic email it needs is already
  /// permanently owned by a different account. Deletes ONLY the
  /// just-created, still-empty phone-only identity — it never reads,
  /// modifies, deletes, or merges any other (legacy) account or its
  /// data. This is not an automatic-merge mechanism.
  Future<void> _cleanUpOrphanedPhoneOnlyUser(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        // Safety guard: this cleanup must only ever touch a fresh,
        // still-empty phone-only identity. If a profile somehow already
        // exists for this uid, do nothing destructive.
        return;
      }
      try {
        await user.delete();
      } on FirebaseAuthException {
        // Best-effort only (e.g. requires-recent-login on an older
        // resumed session). The sign-out below still removes the stray
        // session from view; the orphaned, data-less phone-only record
        // may persist in Firebase Auth but can never complete
        // registration under this email, so it is harmless clutter
        // rather than a fragmentation risk.
      }
    } finally {
      if (_auth.currentUser?.uid == user.uid) {
        await _auth.signOut();
      }
    }
  }

  /// Writes `users/{user.uid}` with exactly the approved fields — no
  /// password/hash. Shared by fresh registration and by the
  /// needs-profile resume path so both always write the identical
  /// shape.
  Future<void> _writeUserProfile({
    required User user,
    required String name,
    required String phone,
  }) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'phoneNumber': phone,
      'authEmail': _authEmailFromPhone(phone),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect phone number or password.';
      case 'invalid-verification-code':
        return 'The code you entered is incorrect. Please try again.';
      case 'invalid-verification-id':
      case 'session-expired':
        return 'This code has expired. Please request a new one.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'operation-not-allowed':
        return 'Enable Email/Password sign-in method in Firebase Authentication.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'requires-recent-login':
        return 'Please verify your phone again to continue.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-mismatch':
        return 'This does not match the signed-in account.';
      default:
        // Never surface e.message/e.code directly — it can contain
        // Firebase implementation details.
        return 'Something went wrong. Please try again.';
    }
  }

  /// Low-level "send an SMS OTP to this phone" primitive shared by both
  /// [requestOtp] (fresh registration) and [requestMigrationOtp] (legacy
  /// migration) — the two callers differ only in what validation they
  /// perform before reaching this point, never in how the SMS is sent.
  Future<String> _sendOtpCode(String phoneNumber) async {
    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {},
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(_mapFirebaseAuthException(e)));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );

    return completer.future;
  }

  @override
  Future<String> requestOtp(String phoneNumber) => _sendOtpCode(phoneNumber);

  @override
  Future<AuthUser> registerWithOtp({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
    required String password,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final User user;
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final signedInUser = userCredential.user;
      if (signedInUser == null) {
        throw Exception('Unable to complete registration.');
      }
      user = signedInUser;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthException(e));
    }

    // From here on, `user` is the durable checkpoint: if anything below
    // fails, the phone-authenticated session survives for a safe retry
    // or cross-restart resume (see inspectCurrentSession).
    await _linkPasswordLogin(user: user, phone: phone, password: password);

    await _writeUserProfile(user: user, name: name, phone: phone);

    return AuthUser(uid: user.uid, name: name, phoneNumber: phone);
  }

  @override
  Future<AuthUser> registerWithPhonePassword({
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _authEmailFromPhone(phone),
        password: password,
      );
      final user = userCredential.user;

      if (user == null) {
        throw Exception('Unable to complete registration.');
      }

      await user.updateDisplayName(name);

      await _writeUserProfile(user: user, name: name, phone: phone);

      return AuthUser(uid: user.uid, name: name, phoneNumber: phone);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Account already exists. Please login.');
      }
      throw Exception(_mapFirebaseAuthException(e));
    }
  }

  @override
  Future<AuthUser> login(String phone, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _authEmailFromPhone(phone),
        password: password,
      );
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Unable to login. Please try again.');
      }

      final userRef = _firestore.collection('users').doc(firebaseUser.uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        await userRef.set({
          'uid': firebaseUser.uid,
          'phoneNumber': phone,
          'authEmail': _authEmailFromPhone(phone),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final userData = userDoc.data() ?? {};

      return AuthUser(
        uid: firebaseUser.uid,
        name: (userData['name'] as String?) ?? '',
        phoneNumber: (userData['phoneNumber'] as String?) ?? phone,
        // Phase 4 detection point: only AFTER a successful
        // phone+password authentication do we inspect providerData.
        // Credential verification itself above is completely unchanged.
        needsPhoneVerification: !_hasPhoneProviderLinked(firebaseUser),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthException(e));
    }
  }

  @override
  Future<AuthSessionInspection> inspectCurrentSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const AuthSessionInspection.noSession();
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      return AuthSessionInspection.complete(
        AuthUser(
          uid: user.uid,
          name: (data['name'] as String?) ?? '',
          phoneNumber:
              (data['phoneNumber'] as String?) ?? (user.phoneNumber ?? ''),
          // Phase 4 restart-bypass fix: a completed users/{uid} profile
          // does NOT by itself mean a legacy account has finished
          // mandatory phone migration — reuses the same
          // _hasPhoneProviderLinked check login() already uses, so a
          // reconciled session correctly reports the same
          // needsPhoneVerification a fresh login would have. Phase 3
          // accounts always have the phone provider linked by the time
          // their profile exists, so this is false for them exactly as
          // before.
          needsPhoneVerification: !_hasPhoneProviderLinked(user),
        ),
      );
    }

    final providerIds = user.providerData.map((p) => p.providerId).toSet();
    final hasPassword = providerIds.contains('password');
    final hasPhone =
        providerIds.contains('phone') ||
        (user.phoneNumber != null && user.phoneNumber!.isNotEmpty);
    final phone = user.phoneNumber ?? '';

    if (hasPassword && phone.isNotEmpty) {
      return AuthSessionInspection.recovery(
        RegistrationRecoveryStep.needsProfile,
        phone,
      );
    }
    if (hasPhone && phone.isNotEmpty) {
      return AuthSessionInspection.recovery(
        RegistrationRecoveryStep.needsPassword,
        phone,
      );
    }

    // No usable providers/phone number and no profile — nothing that can
    // be safely resumed.
    return const AuthSessionInspection.noSession();
  }

  @override
  Future<void> linkPasswordToCurrentUser({
    required String phone,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No active session to resume. Please register again.');
    }
    await _linkPasswordLogin(user: user, phone: phone, password: password);
  }

  @override
  Future<AuthUser> completeProfileForCurrentUser({
    required String name,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No active session to resume. Please register again.');
    }
    await _writeUserProfile(user: user, name: name, phone: phone);
    return AuthUser(uid: user.uid, name: name, phoneNumber: phone);
  }

  // ── Phase 4: legacy user phone-provider migration ──────────────────
  //
  // The user must already be authenticated as the legacy password user
  // (via the unchanged login() above) before either method below is
  // ever called. Neither method may re-authenticate or create a second
  // Firebase user by any mechanism — see the repository safety-search
  // results in the Phase 4 report.

  @override
  Future<String> requestMigrationOtp(String phone) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to verify your phone.');
    }
    if (_hasPhoneProviderLinked(user)) {
      // Already migrated — the caller should not have reached this
      // screen, but refuse to re-send rather than guessing.
      throw Exception('This phone number is already verified on your account.');
    }

    // The phone identity used for migration must be the account's own
    // canonical phone, never a user-typed one. Cross-check it against
    // the actual signed-in synthetic email before sending any SMS — if
    // they don't match, stop safely instead of silently proceeding.
    final expectedEmail = _authEmailFromPhone(phone);
    if (user.email != expectedEmail) {
      throw Exception(
        'Your account phone number does not match your login details. '
        'Please contact support.',
      );
    }

    return _sendOtpCode(phone);
  }

  @override
  Future<void> linkPhoneToCurrentUser({
    required String verificationId,
    required String smsCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to verify your phone.');
    }

    final uidBefore = user.uid;
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        // Idempotent ONLY after actually confirming the phone provider
        // is present on the SAME uid — never assumed.
        final refreshedUser = _auth.currentUser;
        if (refreshedUser != null &&
            refreshedUser.uid == uidBefore &&
            _hasPhoneProviderLinked(refreshedUser)) {
          return;
        }
        throw Exception(
          'Something went wrong verifying your phone. Please try again.',
        );
      }
      if (e.code == 'credential-already-in-use') {
        // This phone is already linked to a DIFFERENT Firebase user.
        // Never merge, delete, overwrite, or sign into that other
        // account — the currently authenticated legacy account and all
        // of its data are left completely untouched.
        throw Exception(
          'This phone number is already linked to a different account. '
          'Please contact support to resolve this.',
        );
      }
      // invalid-verification-code, session-expired, too-many-requests,
      // network-request-failed, and anything unexpected: preserve the
      // still-authenticated legacy session and surface a recoverable
      // error — never delete or sign out here.
      throw Exception(_mapFirebaseAuthException(e));
    }

    // Fatal invariant: linking must never change which Firebase user we
    // are signed in as. If it somehow did, refuse to treat this as a
    // successful migration.
    final uidAfter = _auth.currentUser?.uid;
    if (uidAfter != uidBefore) {
      throw Exception(
        'A critical account error occurred. Please contact support.',
      );
    }
  }

  // ── Phase 5B: signed-out password reset (Forgot Password) ──────────
  //
  // The client-only implementation this replaced consumed a phone
  // credential via a client-side phone sign-in call and inspected an
  // "is this a new user" flag to decide whether an account already
  // existed — the Phase 5B security audit established that Firebase
  // creates the Auth user as part of that same call, BEFORE the client
  // can ever inspect the result, so "detect and clean up a new user" is
  // not equivalent to "prevent one from ever being created." Both
  // methods below now do nothing more than call the TRUSTED BACKEND
  // (Cloud Functions `requestPasswordReset` / `completePasswordReset`),
  // which alone resolves identity (read-only Admin SDK lookups) and
  // performs the password change via the Admin SDK — never a
  // client-side Firebase Auth call. This file's own phone-credential
  // sign-in and client-side password-change calls above (registerWithOtp,
  // linkPhoneToCurrentUser) belong to Phase 3/4 and are completely
  // unrelated and unchanged.

  @override
  Future<String> requestPasswordResetOtp(String phone) async {
    try {
      final callable = _functions.httpsCallable('requestPasswordReset');
      final result = await callable.call<Map<String, dynamic>>({
        'phone': phone,
      });
      final challengeId = result.data['challengeId'] as String?;
      if (challengeId == null || challengeId.isEmpty) {
        throw Exception('Something went wrong. Please try again.');
      }
      return challengeId;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(_mapFunctionsException(e));
    }
  }

  @override
  Future<void> verifyPasswordResetOtpAndUpdatePassword({
    required String challengeId,
    required String smsCode,
    required String newPassword,
  }) async {
    try {
      final callable = _functions.httpsCallable('completePasswordReset');
      await callable.call<Map<String, dynamic>>({
        'challengeId': challengeId,
        'otp': smsCode,
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(_mapFunctionsException(e));
    }
  }

  /// Maps a [FirebaseFunctionsException] to a safe, user-facing
  /// message. The backend's own error messages are already generic and
  /// safe by design (see the Phase 5B architecture report — they never
  /// leak UID, synthetic email, provider state, or challenge internals),
  /// so they are passed through as-is; only a missing/empty message
  /// falls back to a generic string. Never surfaces `e.details` or a
  /// stack trace.
  String _mapFunctionsException(FirebaseFunctionsException e) {
    final message = e.message;
    if (message == null || message.isEmpty) {
      return 'Something went wrong. Please try again.';
    }
    return message;
  }
}
