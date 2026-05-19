import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

class RequestOtpUseCase {
  final AuthRepository repository;

  RequestOtpUseCase(this.repository);

  // تم التعديل لترجع String
  Future<String> call(String phoneNumber) async {
    return await repository.requestOtp(phoneNumber);
  }
}