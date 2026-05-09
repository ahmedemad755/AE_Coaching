import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRemoteDataSource {
  /// يقوم بإرسال رمز التحقق (OTP) إلى رقم الهاتف المدخل
  Future<void> requestOtp(String phoneNumber);

  /// يقوم بإتمام عملية التسجيل باستخدام معرف التحقق ورمز OTP
  Future<UserCredential> registerWithOtp({
    required String verificationId,
    required String smsCode,
  });

  /// يقوم بتسجيل الدخول التقليدي باستخدام البريد الإلكتروني وكلمة المرور
  Future<UserCredential> login(String email, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<void> requestOtp(String phoneNumber) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // في حال التحقق التلقائي (على أجهزة أندرويد مثلاً)
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        throw e; // سيتم التقاط الخطأ في الـ Repository أو الكيوبيت
      },
      codeSent: (String verificationId, int? resendToken) {
        // يمكنك استخدام الـ callback هنا لتخزين الـ verificationId 
        // أو إرساله لواجهة المستخدم عبر الـ Flow الخاص بك
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Future<UserCredential> registerWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    // إنشاء الكريدينشال باستخدام الكود المرسل
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    // إتمام تسجيل الدخول/التسجيل في فايربيز
    return await _auth.signInWithCredential(credential);
  }

  @override
  Future<UserCredential> login(String email, String password) async {
    // تسجيل الدخول العادي المستخدم في الـ LoginView
    return await _auth.signInWithEmailAndPassword(
      email: email, 
      password: password,
    );
  }
}