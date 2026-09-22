import 'package:ae_coaching/auth/domain/entities/auth_session_inspection.dart';
import 'package:ae_coaching/auth/domain/entities/auth_user.dart';

abstract class AuthRepository {
  Future<String> requestOtp(String phoneNumber);

  /// Full fresh registration: consumes the OTP credential (creating or
  /// resolving the phone-authenticated Firebase user), links the
  /// synthetic email/password credential onto that SAME uid, then
  /// writes `users/{uid}`. Returns the completed [AuthUser] only after
  /// every step succeeds.
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

  /// Inspects the current Firebase session (if any) against
  /// `users/{uid}` to determine whether it's a fully reconciled login,
  /// a resumable partial registration, or nothing to reconcile at all.
  /// Never creates a new UID.
  Future<AuthSessionInspection> inspectCurrentSession();

  /// Resume path for a phone-authenticated-only session: links the
  /// password credential onto the SAME already-signed-in user. Never
  /// calls verifyPhoneNumber/signInWithCredential.
  Future<void> linkPasswordToCurrentUser({
    required String phone,
    required String password,
  });

  /// Resume path for a phone+password-linked session with no Firestore
  /// profile yet: writes `users/{uid}` for the SAME already-signed-in
  /// user. Never repeats authentication.
  Future<AuthUser> completeProfileForCurrentUser({
    required String name,
    required String phone,
  });

  /// Phase 4 — legacy migration. See
  /// AuthRemoteDataSource.requestMigrationOtp for the exact contract.
  Future<String> requestMigrationOtp(String phone);

  /// Phase 4 — legacy migration. See
  /// AuthRemoteDataSource.linkPhoneToCurrentUser for the exact contract.
  Future<void> linkPhoneToCurrentUser({
    required String verificationId,
    required String smsCode,
  });

  /// Phase 5B — signed-out password reset. See
  /// AuthRemoteDataSource.requestPasswordResetOtp for the exact
  /// contract. Returns an opaque backend-issued challenge ID — never a
  /// Firebase phone-auth verificationId.
  Future<String> requestPasswordResetOtp(String phone);

  /// Phase 5B — signed-out password reset. See
  /// AuthRemoteDataSource.verifyPasswordResetOtpAndUpdatePassword for
  /// the exact contract.
  Future<void> verifyPasswordResetOtpAndUpdatePassword({
    required String challengeId,
    required String smsCode,
    required String newPassword,
  });
}
