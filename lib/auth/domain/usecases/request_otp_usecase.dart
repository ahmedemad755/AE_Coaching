import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

class RequestOtpUseCase {
  final AuthRepository repository;

  RequestOtpUseCase(this.repository);

  /// طلب إرسال كود التحقق لرقم الهاتف
  Future<void> call(String phoneNumber) async {
    return await repository.requestOtp(phoneNumber);
  }
}