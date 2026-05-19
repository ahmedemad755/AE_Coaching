abstract class AuthRepository {
  Future<String> requestOtp(String phoneNumber);

  Future<void> registerWithOtp({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
    required String password,
  });

  Future<void> login(String phone, String password);
}