import 'package:ae_coaching/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<String> requestOtp(String phoneNumber) async {
    try {
      return await remoteDataSource.requestOtp(phoneNumber); 
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> registerWithOtp({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      return await remoteDataSource.registerWithOtp(
        verificationId: verificationId,
        smsCode: smsCode,
        name: name,
        phone: phone,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<AuthUser> login(String phone, String password) async {
    try {
      return await remoteDataSource.login(phone, password);
    } catch (e) {
      rethrow;
    }
  }
}
