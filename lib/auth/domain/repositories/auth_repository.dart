import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  /// طلب إرسال كود OTP لرقم الهاتف
  Future<void> requestOtp(String phoneNumber);

  /// تسجيل مستخدم جديد أو تفعيل الحساب باستخدام الكود المستلم ومعرف التحقق
  Future<UserCredential> registerWithOtp({
    required String verificationId,
    required String smsCode,
  });

  /// تسجيل الدخول العادي بالبريد الإلكتروني وكلمة المرور
  Future<UserCredential> login(String email, String password);
}