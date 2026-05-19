import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

class RegisterWithOtpUseCase {
  final AuthRepository repository;

  RegisterWithOtpUseCase(this.repository);

  /// إتمام عملية التسجيل باستخدام الكود ومعرف التحقق وباقي بيانات المستخدم
  Future<void> call({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
    required String password,
  }) async {
    return await repository.registerWithOtp(
      verificationId: verificationId,
      smsCode: smsCode,
      name: name,
      phone: phone,
      password: password,
    );
  }
}