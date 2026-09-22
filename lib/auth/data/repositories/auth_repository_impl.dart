import 'package:ae_coaching/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ae_coaching/auth/domain/entities/auth_session_inspection.dart';
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
  Future<AuthUser> registerWithOtp({
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
  Future<AuthUser> registerWithPhonePassword({
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      return await remoteDataSource.registerWithPhonePassword(
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

  @override
  Future<AuthSessionInspection> inspectCurrentSession() async {
    try {
      return await remoteDataSource.inspectCurrentSession();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> linkPasswordToCurrentUser({
    required String phone,
    required String password,
  }) async {
    try {
      return await remoteDataSource.linkPasswordToCurrentUser(
        phone: phone,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<AuthUser> completeProfileForCurrentUser({
    required String name,
    required String phone,
  }) async {
    try {
      return await remoteDataSource.completeProfileForCurrentUser(
        name: name,
        phone: phone,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String> requestMigrationOtp(String phone) async {
    try {
      return await remoteDataSource.requestMigrationOtp(phone);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> linkPhoneToCurrentUser({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      return await remoteDataSource.linkPhoneToCurrentUser(
        verificationId: verificationId,
        smsCode: smsCode,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String> requestPasswordResetOtp(String phone) async {
    try {
      return await remoteDataSource.requestPasswordResetOtp(phone);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> verifyPasswordResetOtpAndUpdatePassword({
    required String challengeId,
    required String smsCode,
    required String newPassword,
  }) async {
    try {
      return await remoteDataSource.verifyPasswordResetOtpAndUpdatePassword(
        challengeId: challengeId,
        smsCode: smsCode,
        newPassword: newPassword,
      );
    } catch (e) {
      rethrow;
    }
  }
}
