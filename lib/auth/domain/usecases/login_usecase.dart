import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  /// تنفيذ عملية تسجيل الدخول
  /// تم تعديل النوع لـ Future<void> ليتوافق مع الـ Repository الجديد
  Future<void> call(String phone, String password) async {
    await repository.login(phone, password);
  }
}