import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

class RegisterWithPhonePasswordUseCase {
  final AuthRepository repository;

  RegisterWithPhonePasswordUseCase(this.repository);

  Future<AuthUser> call({
    required String name,
    required String phone,
    required String password,
  }) async {
    return repository.registerWithPhonePassword(
      name: name,
      phone: phone,
      password: password,
    );
  }
}
