import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

/// Phase 5B — signed-out Forgot Password. Submits the OTP + new
/// password to the trusted backend (Cloud Function
/// `completePasswordReset`), which alone resolves identity and decides
/// whether to update the password. The client never signs in, never
/// calls Firebase Auth directly for this flow, and never creates a
/// second Firebase user.
class ResetPasswordWithOtpUseCase {
  final AuthRepository repository;

  ResetPasswordWithOtpUseCase(this.repository);

  Future<void> call({
    required String challengeId,
    required String smsCode,
    required String newPassword,
  }) {
    return repository.verifyPasswordResetOtpAndUpdatePassword(
      challengeId: challengeId,
      smsCode: smsCode,
      newPassword: newPassword,
    );
  }
}
