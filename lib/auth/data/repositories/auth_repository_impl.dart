import 'package:ae_coaching/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> requestOtp(String phoneNumber) async {
    try {
      // تمرير الطلب إلى الـ Data Source مباشرة
      return await remoteDataSource.requestOtp(phoneNumber);
    } catch (e) {
      // هنا ممكن مستقبلاً تحول الـ Exception لـ Failure مخصص
      rethrow;
    }
  }

  @override
  Future<UserCredential> registerWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      // تنفيذ عملية التسجيل عبر الـ Remote Data Source
      return await remoteDataSource.registerWithOtp(
        verificationId: verificationId,
        smsCode: smsCode,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserCredential> login(String email, String password) async {
    try {
      // تنفيذ عملية تسجيل الدخول التقليدية
      return await remoteDataSource.login(email, password);
    } catch (e) {
      rethrow;
    }
  }
}