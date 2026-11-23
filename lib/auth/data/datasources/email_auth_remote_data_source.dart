import 'dart:developer' as developer;

import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/entities/email_auth_messages.dart';
import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:ae_coaching/auth/domain/validation/profile_integrity.dart';
import 'package:ae_coaching/auth/data/datasources/user_profile_store.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Email-first Firebase Auth + `users/{uid}` profile access (Stage 3B).
///
/// Firebase Auth owns identity, credentials and `emailVerified`. The
/// profile document stores only display data (`uid`, `name`, `email`,
/// `createdAt`, `updatedAt`), never passwords, tokens or verification
/// state. Every user-facing error is one of the fixed English messages
/// below, which `localizeAuthError` translates.
abstract class EmailAuthRemoteDataSource {
  /// Creates the account, saves the name as the Auth display name,
  /// creates the profile and sends the verification email. Once the
  /// account exists, the remaining steps are best-effort and never fail
  /// the call: a retry must never try to create the same account again.
  Future<EmailSessionResolution> register({
    required String name,
    required String email,
    required String password,
    String? languageCode,
  });

  Future<EmailSessionResolution> login({
    required String email,
    required String password,
  });

  /// Authoritative check of the persisted session (startup, resume). It
  /// reloads the user from the server, so it needs network.
  Future<EmailSessionResolution> resolveCurrentSession();

  Future<void> resendVerificationEmail({String? languageCode});

  /// Reloads the user. Once verified, the ID token is force-refreshed so
  /// Firestore rules see `email_verified == true` straight away.
  Future<EmailSessionResolution> refreshEmailVerification();

  /// Sends a verification link to [newEmail]. The account's email changes
  /// only after that link is opened (`verifyBeforeUpdateEmail`), so a typo
  /// can never lock the user out.
  Future<void> requestEmailChange({
    required String newEmail,
    String? languageCode,
  });

  /// Always completes normally for an unknown email, so the screen can't
  /// be used to discover which emails have accounts.
  Future<void> sendPasswordResetEmail({
    required String email,
    String? languageCode,
  });

  /// Missing-profile recovery: creates `users/{uid}` (create-only) for the
  /// signed-in, verified user, then re-resolves.
  Future<EmailSessionResolution> completeProfile({required String name});

  Future<void> signOut();
}

class EmailAuthRemoteDataSourceImpl implements EmailAuthRemoteDataSource {
  final FirebaseAuth _auth;
  final UserProfileStore _profiles;

  EmailAuthRemoteDataSourceImpl({
    FirebaseAuth? auth,
    UserProfileStore? profiles,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _profiles = profiles ?? FirestoreUserProfileStore();

  // User-facing messages are defined in EmailAuthMessages (domain).
  static const String incorrectCredentialsMessage =
      EmailAuthMessages.incorrectCredentials;
  static const String emailInUseMessage = EmailAuthMessages.emailInUse;
  static const String newEmailInUseMessage = EmailAuthMessages.newEmailInUse;
  static const String recentLoginMessage = EmailAuthMessages.recentLogin;
  static const String sessionExpiredMessage = EmailAuthMessages.sessionExpired;
  static const String networkMessage = EmailAuthMessages.network;
  static const String tooManyRequestsMessage =
      EmailAuthMessages.tooManyRequests;
  static const String disabledMessage = EmailAuthMessages.disabled;
  static const String genericMessage = EmailAuthMessages.generic;
  static const String noSessionMessage = EmailAuthMessages.noSession;

  /// Codes that mean the persisted session can no longer be used. The
  /// user is signed out locally (nothing is deleted) and sent to Login.
  static const Set<String> _deadSessionCodes = {
    'user-disabled',
    'user-not-found',
    'user-token-expired',
    'invalid-user-token',
  };

  Exception _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return Exception(incorrectCredentialsMessage);
      case 'email-already-in-use':
        return Exception(emailInUseMessage);
      case 'invalid-email':
        return Exception(AuthInputGuard.invalidEmailMessage);
      case 'weak-password':
        return Exception(AuthInputGuard.weakPasswordMessage);
      case 'network-request-failed':
        return Exception(networkMessage);
      case 'too-many-requests':
        return Exception(tooManyRequestsMessage);
      case 'user-disabled':
        return Exception(disabledMessage);
      case 'requires-recent-login':
        return Exception(recentLoginMessage);
      case 'user-token-expired':
      case 'invalid-user-token':
        return Exception(sessionExpiredMessage);
      default:
        // Never surface e.message: it can contain Firebase internals.
        // The code alone is safe to log.
        developer.log(
          'Unmapped FirebaseAuthException code: ${e.code}',
          name: 'EmailAuth',
        );
        return Exception(genericMessage);
    }
  }

  Exception _mapFirestoreError(FirebaseException e) {
    if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
      return Exception(networkMessage);
    }
    if (e.code == 'permission-denied') {
      return Exception(EmailAuthMessages.profilePermissionDenied);
    }
    developer.log(
      'Profile access failed: ${e.plugin}/${e.code}',
      name: 'EmailAuth',
    );
    return Exception(genericMessage);
  }

  Future<void> _applyLanguage(String? languageCode) async {
    if (languageCode == null || languageCode.isEmpty) return;
    try {
      await _auth.setLanguageCode(languageCode);
    } catch (_) {
      // Best-effort: the email then falls back to the project default
      // template language.
    }
  }

  bool _usesPassword(User user) =>
      user.providerData.any((p) => p.providerId == 'password');

  /// Single decision point shared by login, startup, refresh and
  /// registration.
  Future<EmailSessionResolution> _resolve(User user) async {
    final email = AuthInputRules.normalizeEmail(user.email ?? '');

    if (AuthInputRules.isReservedEmail(email)) {
      return const EmailSessionResolution.legacyAccount();
    }

    // Mandatory only for Email/Password. Federated providers (Google,
    // Apple, later stages) come back already verified by the provider.
    if (_usesPassword(user) && !user.emailVerified) {
      return EmailSessionResolution.pendingVerification(email);
    }

    // Firestore rules authorize from the ID token, not the reloaded user.
    await _ensureTokenIsCurrent(user, email);
    return _resolveProfile(user, email);
  }

  ProfileFailure _failureFor(FirebaseException e) {
    developer.log(
      'Profile access failed: ${e.plugin}/${e.code}',
      name: 'EmailAuth',
    );
    switch (e.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return ProfileFailure.permissionDenied;
      case 'unavailable':
      case 'deadline-exceeded':
        return ProfileFailure.network;
      default:
        return ProfileFailure.unknown;
    }
  }

  /// Verified identity: only a profile that is CONFIRMED valid on the
  /// server may produce [AuthStatus.authenticated]. Every failure is
  /// returned as [AuthStatus.profileUnavailable] with its real reason,
  /// never swallowed into success.
  Future<EmailSessionResolution> _resolveProfile(
    User user,
    String email,
  ) async {
    Map<String, dynamic>? data;
    try {
      data = await _profiles.read(user.uid);
    } on FirebaseException catch (e) {
      return EmailSessionResolution.profileUnavailable(email, _failureFor(e));
    }

    var condition = assessProfile(data, user.uid);
    if (condition == ProfileCondition.conflicting) {
      return EmailSessionResolution.profileUnavailable(
        email,
        ProfileFailure.conflicting,
      );
    }

    if (condition != ProfileCondition.valid) {
      // Missing (sign-up interrupted) or repairable (required data
      // absent). Recover from the name saved at sign-up. Ask for a name
      // only if there isn't a usable one.
      final displayName = user.displayName ?? '';
      if (AuthInputRules.validateName(displayName) != null) {
        return EmailSessionResolution.incompleteProfile(email);
      }
      try {
        await _profiles.createOrRepair(
          uid: user.uid,
          name: AuthInputRules.normalizeName(displayName),
          email: email,
        );
        // Re-read: the write call returning is not proof of a valid
        // profile.
        data = await _profiles.read(user.uid);
      } on FirebaseException catch (e) {
        return EmailSessionResolution.profileUnavailable(email, _failureFor(e));
      }
      condition = assessProfile(data, user.uid);
      if (condition != ProfileCondition.valid) {
        return EmailSessionResolution.profileUnavailable(
          email,
          condition == ProfileCondition.conflicting
              ? ProfileFailure.conflicting
              : ProfileFailure.unknown,
        );
      }
    }

    final profile = data!;
    final storedEmail = (profile['email'] as String?) ?? '';
    if (email.isNotEmpty && storedEmail != email) {
      // The account email changed (verifyBeforeUpdateEmail). The profile
      // copy is display data only (Auth is authoritative), so a failed
      // sync is logged with its real code but doesn't block sign-in.
      try {
        await _profiles.updateEmail(uid: user.uid, email: email);
      } on FirebaseException catch (e) {
        developer.log('Email sync failed: ${e.code}', name: 'EmailAuth');
      }
    }
    return EmailSessionResolution.authenticated(
      AuthUser(
        uid: user.uid,
        name: AuthInputRules.normalizeName(profile['name'] as String),
        email: email,
      ),
    );
  }

  /// `reload()` refreshes the user record but not the ID token, and the
  /// token's `email_verified` / `email` claims can lag for up to an hour
  /// (e.g. after the user opened the verification link and restarted the
  /// app). Firestore rules (firestore.rules) authorize from those claims,
  /// so a stale token would deny profile repair, the email sync and every
  /// workout write. Refresh only when the claims are actually stale.
  /// Offline: best-effort, and the profile read then reports the real
  /// failure.
  Future<void> _ensureTokenIsCurrent(User user, String email) async {
    try {
      final claims = (await user.getIdTokenResult()).claims ?? const {};
      final tokenEmail = (claims['email'] as String?)?.toLowerCase() ?? '';
      final stale =
          (_usesPassword(user) && claims['email_verified'] != true) ||
          (email.isNotEmpty && tokenEmail != email);
      if (stale) await user.getIdToken(true);
    } on FirebaseAuthException catch (e) {
      developer.log('Token refresh skipped: ${e.code}', name: 'EmailAuth');
    }
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw Exception(noSessionMessage);
    return user;
  }

  @override
  Future<EmailSessionResolution> register({
    required String name,
    required String email,
    required String password,
    String? languageCode,
  }) async {
    final User user;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final created = credential.user;
      if (created == null) throw Exception(genericMessage);
      user = created;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }

    // The account now exists. Everything below is recoverable: the
    // profile is re-created on the next resolve (from the display name),
    // and the verification email can be resent.
    try {
      await user.updateDisplayName(name);
    } catch (e) {
      developer.log('Display name not saved: $e', name: 'EmailAuth');
    }
    try {
      await _profiles.createOrRepair(uid: user.uid, name: name, email: email);
    } on FirebaseException catch (e) {
      // Not hidden: the profile is re-checked, and created or repaired,
      // after verification. A persistent failure then surfaces as
      // profileUnavailable with its real reason (e.g. permission-denied).
      developer.log('Profile write deferred: ${e.code}', name: 'EmailAuth');
    }
    var sent = false;
    try {
      await _applyLanguage(languageCode);
      await user.sendEmailVerification();
      sent = true;
    } catch (e) {
      developer.log('Verification email not sent: $e', name: 'EmailAuth');
    }
    return EmailSessionResolution.pendingVerification(
      email,
      verificationEmailSent: sent,
    );
  }

  @override
  Future<EmailSessionResolution> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw Exception(genericMessage);
      return await _resolve(user);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<EmailSessionResolution> resolveCurrentSession() async {
    final user = _auth.currentUser;
    if (user == null) return const EmailSessionResolution.unauthenticated();
    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (_deadSessionCodes.contains(e.code)) {
        await _auth.signOut();
        return const EmailSessionResolution.unauthenticated();
      }
      throw _mapAuthError(e);
    }
    final fresh = _auth.currentUser;
    if (fresh == null) return const EmailSessionResolution.unauthenticated();
    return _resolve(fresh);
  }

  @override
  Future<void> resendVerificationEmail({String? languageCode}) async {
    final user = _requireUser();
    try {
      await _applyLanguage(languageCode);
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  @override
  Future<EmailSessionResolution> refreshEmailVerification() async {
    final user = _requireUser();
    try {
      await user.reload();
      final fresh = _requireUser();
      if (fresh.emailVerified) {
        // The cached ID token still says email_verified=false until it
        // is refreshed. Force it, so server rules agree immediately.
        await fresh.getIdToken(true);
      }
      return await _resolve(fresh);
    } on FirebaseAuthException catch (e) {
      if (_deadSessionCodes.contains(e.code)) {
        // e.g. the email was changed via its link and the old session
        // was revoked.
        await _auth.signOut();
        throw Exception(sessionExpiredMessage);
      }
      throw _mapAuthError(e);
    }
  }

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    String? languageCode,
  }) async {
    final user = _requireUser();
    try {
      await _applyLanguage(languageCode);
      await user.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception(newEmailInUseMessage);
      }
      throw _mapAuthError(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    String? languageCode,
  }) async {
    try {
      await _applyLanguage(languageCode);
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Projects without email-enumeration protection report unknown
      // addresses. Swallow that, so the screen reads the same whether or
      // not an account exists.
      if (e.code == 'user-not-found') return;
      throw _mapAuthError(e);
    }
  }

  @override
  Future<EmailSessionResolution> completeProfile({required String name}) async {
    final user = _requireUser();
    final email = AuthInputRules.normalizeEmail(user.email ?? '');
    try {
      final existing = await _profiles.read(user.uid);
      if (assessProfile(existing, user.uid) == ProfileCondition.conflicting) {
        throw Exception(EmailAuthMessages.profileConflicting);
      }
      await _profiles.createOrRepair(uid: user.uid, name: name, email: email);
    } on FirebaseException catch (e) {
      throw _mapFirestoreError(e);
    }
    try {
      await user.updateDisplayName(name);
    } catch (_) {}
    return _resolve(user);
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
