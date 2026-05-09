import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterWithOtpUseCase {
  final AuthRepository repository;

  RegisterWithOtpUseCase(this.repository);

  /// إتمام عملية التسجيل باستخدام الكود ومعرف التحقق
  Future<UserCredential> call({
    required String verificationId,
    required String smsCode,
  }) async {
    return await repository.registerWithOtp(
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }
}