import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

/// Phase 4: sends an OTP to the ALREADY authenticated legacy account's
/// own canonical phone. Distinct from [RequestOtpUseCase] — never used
/// for fresh registration.
class RequestPhoneMigrationOtpUseCase {
  final AuthRepository repository;

  RequestPhoneMigrationOtpUseCase(this.repository);

  Future<String> call(String phone) => repository.requestMigrationOtp(phone);
}
