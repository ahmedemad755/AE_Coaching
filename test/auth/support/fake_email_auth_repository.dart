import 'dart:async';

import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/domain/repositories/email_auth_repository.dart';

/// Repository-boundary fake for the email-first flow. Lets cubit and
/// widget tests drive every [EmailSessionResolution] outcome without
/// Firebase. The real Firebase behavior is covered separately by
/// email_auth_remote_data_source_test.dart (firebase_auth_mocks plus an
/// in-memory profile store).
class FakeEmailAuthRepository implements EmailAuthRepository {
  Exception? errorToThrow;
  Exception? signOutError;

  /// When set, every call waits on it (in-flight / duplicate-tap tests).
  Completer<void>? hold;

  EmailSessionResolution registerResult =
      const EmailSessionResolution.pendingVerification(
        'new@example.com',
        verificationEmailSent: true,
      );
  EmailSessionResolution loginResult = const EmailSessionResolution.authenticated(
    AuthUser(uid: 'uid-1', name: 'Ahmed', email: 'ahmed@example.com'),
  );
  EmailSessionResolution sessionResult =
      const EmailSessionResolution.unauthenticated();
  EmailSessionResolution refreshResult =
      const EmailSessionResolution.pendingVerification('ahmed@example.com');
  EmailSessionResolution completeProfileResult =
      const EmailSessionResolution.authenticated(
        AuthUser(uid: 'uid-1', name: 'Ahmed', email: 'ahmed@example.com'),
      );

  int registerCalls = 0;
  int loginCalls = 0;
  int resolveCalls = 0;
  int resendCalls = 0;
  int refreshCalls = 0;
  int emailChangeCalls = 0;
  int passwordResetCalls = 0;
  int completeProfileCalls = 0;
  int signOutCalls = 0;

  String? lastRegisterName;
  String? lastRegisterEmail;
  String? lastRegisterPassword;
  String? lastLoginEmail;
  String? lastLoginPassword;
  String? lastNewEmail;
  String? lastResetEmail;
  String? lastLanguageCode;
  String? lastProfileName;

  Future<void> _gate() async {
    final h = hold;
    if (h != null) await h.future;
    final e = errorToThrow;
    if (e != null) throw e;
  }

  @override
  Future<EmailSessionResolution> register({
    required String name,
    required String email,
    required String password,
    String? languageCode,
  }) async {
    registerCalls++;
    lastRegisterName = name;
    lastRegisterEmail = email;
    lastRegisterPassword = password;
    lastLanguageCode = languageCode;
    await _gate();
    return registerResult;
  }

  @override
  Future<EmailSessionResolution> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    lastLoginEmail = email;
    lastLoginPassword = password;
    await _gate();
    return loginResult;
  }

  @override
  Future<EmailSessionResolution> resolveCurrentSession() async {
    resolveCalls++;
    await _gate();
    return sessionResult;
  }

  @override
  Future<void> resendVerificationEmail({String? languageCode}) async {
    resendCalls++;
    lastLanguageCode = languageCode;
    await _gate();
  }

  @override
  Future<EmailSessionResolution> refreshEmailVerification() async {
    refreshCalls++;
    await _gate();
    return refreshResult;
  }

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    String? languageCode,
  }) async {
    emailChangeCalls++;
    lastNewEmail = newEmail;
    await _gate();
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    String? languageCode,
  }) async {
    passwordResetCalls++;
    lastResetEmail = email;
    lastLanguageCode = languageCode;
    await _gate();
  }

  @override
  Future<EmailSessionResolution> completeProfile({required String name}) async {
    completeProfileCalls++;
    lastProfileName = name;
    await _gate();
    return completeProfileResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final e = signOutError;
    if (e != null) throw e;
  }
}
