import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

/// Resume path (RegistrationRecoveryStep.needsPassword): links the
/// password credential onto the SAME already phone-authenticated
/// Firebase user. Never re-verifies phone.
class LinkPasswordToCurrentUserUseCase {
  final AuthRepository repository;

  LinkPasswordToCurrentUserUseCase(this.repository);

  Future<void> call({required String phone, required String password}) {
    return repository.linkPasswordToCurrentUser(
      phone: phone,
      password: password,
    );
  }
}
