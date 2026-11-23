import 'package:ae_coaching/auth/data/datasources/email_auth_remote_data_source.dart';
import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/domain/repositories/email_auth_repository.dart';

class EmailAuthRepositoryImpl implements EmailAuthRepository {
  final EmailAuthRemoteDataSource remoteDataSource;

  EmailAuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<EmailSessionResolution> register({
    required String name,
    required String email,
    required String password,
    String? languageCode,
  }) => remoteDataSource.register(
    name: name,
    email: email,
    password: password,
    languageCode: languageCode,
  );

  @override
  Future<EmailSessionResolution> login({
    required String email,
    required String password,
  }) => remoteDataSource.login(email: email, password: password);

  @override
  Future<EmailSessionResolution> resolveCurrentSession() =>
      remoteDataSource.resolveCurrentSession();

  @override
  Future<void> resendVerificationEmail({String? languageCode}) =>
      remoteDataSource.resendVerificationEmail(languageCode: languageCode);

  @override
  Future<EmailSessionResolution> refreshEmailVerification() =>
      remoteDataSource.refreshEmailVerification();

  @override
  Future<void> requestEmailChange({
    required String newEmail,
    String? languageCode,
  }) => remoteDataSource.requestEmailChange(
    newEmail: newEmail,
    languageCode: languageCode,
  );

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    String? languageCode,
  }) => remoteDataSource.sendPasswordResetEmail(
    email: email,
    languageCode: languageCode,
  );

  @override
  Future<EmailSessionResolution> completeProfile({required String name}) =>
      remoteDataSource.completeProfile(name: name);

  @override
  Future<void> signOut() => remoteDataSource.signOut();
}
