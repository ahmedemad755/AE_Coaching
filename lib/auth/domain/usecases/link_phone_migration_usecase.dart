import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

/// Phase 4: links the phone credential onto the CURRENTLY authenticated
/// legacy user. Never signs in with the phone credential and never
/// creates a new Firebase user — distinct from
/// [LinkPasswordToCurrentUserUseCase] (Phase 3's phone-first resume).
class LinkPhoneMigrationUseCase {
  final AuthRepository repository;

  LinkPhoneMigrationUseCase(this.repository);

  Future<void> call({required String verificationId, required String smsCode}) {
    return repository.linkPhoneToCurrentUser(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }
}
