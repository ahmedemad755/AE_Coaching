import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  /// تنفيذ عملية تسجيل الدخول
  /// يتم استدعاء الكلاس كـ function بفضل استخدام الـ call method
  Future<UserCredential> call(String email, String password) async {
    return await repository.login(email, password);
  }
}