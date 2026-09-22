import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

/// Resume path (RegistrationRecoveryStep.needsProfile): writes
/// `users/{uid}` for the SAME already-authenticated Firebase user.
/// Never repeats phone or password authentication.
class CompleteProfileForCurrentUserUseCase {
  final AuthRepository repository;

  CompleteProfileForCurrentUserUseCase(this.repository);

  Future<AuthUser> call({required String name, required String phone}) {
    return repository.completeProfileForCurrentUser(name: name, phone: phone);
  }
}
