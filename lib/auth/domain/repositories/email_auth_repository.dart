import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';

/// Email-first authentication (Stage 3B). See EmailAuthRemoteDataSource
/// for each method's contract.
abstract class EmailAuthRepository {
  Future<EmailSessionResolution> register({
    required String name,
    required String email,
    required String password,
    String? languageCode,
  });

  Future<EmailSessionResolution> login({
    required String email,
    required String password,
  });

  Future<EmailSessionResolution> resolveCurrentSession();

  Future<void> resendVerificationEmail({String? languageCode});

  Future<EmailSessionResolution> refreshEmailVerification();

  Future<void> requestEmailChange({
    required String newEmail,
    String? languageCode,
  });

  Future<void> sendPasswordResetEmail({
    required String email,
    String? languageCode,
  });

  Future<EmailSessionResolution> completeProfile({required String name});

  Future<void> signOut();
}
