import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

/// Phase 5 — signed-out Forgot Password. Sends an OTP to the phone the
/// user typed on the Forgot Password screen. Distinct from
/// [RequestOtpUseCase] and [RequestPhoneMigrationOtpUseCase] — never
/// used for fresh registration or legacy migration.
class RequestPasswordResetOtpUseCase {
  final AuthRepository repository;

  RequestPasswordResetOtpUseCase(this.repository);

  Future<String> call(String phone) =>
      repository.requestPasswordResetOtp(phone);
}
