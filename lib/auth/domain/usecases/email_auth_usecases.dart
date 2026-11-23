import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/domain/repositories/email_auth_repository.dart';
import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';

/// Email-first use cases (Stage 3B), grouped in one file because each is
/// a one-line delegation plus its domain-boundary input check. Inputs are
/// validated and normalized HERE, never only in the UI.
class RegisterWithEmailUseCase {
  final EmailAuthRepository repository;
  RegisterWithEmailUseCase(this.repository);

  Future<EmailSessionResolution> call({
    required String name,
    required String email,
    required String password,
    String? languageCode,
  }) async {
    final normalizedName = AuthInputGuard.requireName(name);
    final normalizedEmail = AuthInputGuard.requireEmail(email);
    AuthInputGuard.requireNewPassword(password);
    return repository.register(
      name: normalizedName,
      email: normalizedEmail,
      password: password, // exactly as typed (Stage 2 policy)
      languageCode: languageCode,
    );
  }
}

class LoginWithEmailUseCase {
  final EmailAuthRepository repository;
  LoginWithEmailUseCase(this.repository);

  Future<EmailSessionResolution> call({
    required String email,
    required String password,
  }) async {
    return repository.login(
      email: AuthInputGuard.requireEmail(email),
      // Trim kept for compatibility (see AuthInputRules.passwordForSignIn).
      password: AuthInputRules.passwordForSignIn(password),
    );
  }
}

class ResolveEmailSessionUseCase {
  final EmailAuthRepository repository;
  ResolveEmailSessionUseCase(this.repository);

  Future<EmailSessionResolution> call() => repository.resolveCurrentSession();
}

class ResendVerificationEmailUseCase {
  final EmailAuthRepository repository;
  ResendVerificationEmailUseCase(this.repository);

  Future<void> call({String? languageCode}) =>
      repository.resendVerificationEmail(languageCode: languageCode);
}

class RefreshEmailVerificationUseCase {
  final EmailAuthRepository repository;
  RefreshEmailVerificationUseCase(this.repository);

  Future<EmailSessionResolution> call() =>
      repository.refreshEmailVerification();
}

class RequestEmailChangeUseCase {
  final EmailAuthRepository repository;
  RequestEmailChangeUseCase(this.repository);

  /// Returns the normalized address the link was sent to.
  Future<String> call({required String newEmail, String? languageCode}) async {
    final normalized = AuthInputGuard.requireEmail(newEmail);
    await repository.requestEmailChange(
      newEmail: normalized,
      languageCode: languageCode,
    );
    return normalized;
  }
}

class SendPasswordResetEmailUseCase {
  final EmailAuthRepository repository;
  SendPasswordResetEmailUseCase(this.repository);

  /// Returns the normalized address, for the neutral confirmation text.
  Future<String> call({required String email, String? languageCode}) async {
    final normalized = AuthInputGuard.requireEmail(email);
    await repository.sendPasswordResetEmail(
      email: normalized,
      languageCode: languageCode,
    );
    return normalized;
  }
}

class CompleteProfileUseCase {
  final EmailAuthRepository repository;
  CompleteProfileUseCase(this.repository);

  Future<EmailSessionResolution> call({required String name}) async =>
      repository.completeProfile(name: AuthInputGuard.requireName(name));
}

class EmailSignOutUseCase {
  final EmailAuthRepository repository;
  EmailSignOutUseCase(this.repository);

  /// Ends the Firebase session only. Never deletes the account or data.
  Future<void> call() => repository.signOut();
}

/// Bundles the email-first use cases for AuthCubit (one DI registration,
/// one constructor parameter).
class EmailAuthUseCases {
  final RegisterWithEmailUseCase register;
  final LoginWithEmailUseCase login;
  final ResolveEmailSessionUseCase resolveSession;
  final ResendVerificationEmailUseCase resendVerification;
  final RefreshEmailVerificationUseCase refreshVerification;
  final RequestEmailChangeUseCase requestEmailChange;
  final SendPasswordResetEmailUseCase sendPasswordReset;
  final CompleteProfileUseCase completeProfile;
  final EmailSignOutUseCase signOut;

  EmailAuthUseCases(EmailAuthRepository repository)
    : register = RegisterWithEmailUseCase(repository),
      login = LoginWithEmailUseCase(repository),
      resolveSession = ResolveEmailSessionUseCase(repository),
      resendVerification = ResendVerificationEmailUseCase(repository),
      refreshVerification = RefreshEmailVerificationUseCase(repository),
      requestEmailChange = RequestEmailChangeUseCase(repository),
      sendPasswordReset = SendPasswordResetEmailUseCase(repository),
      completeProfile = CompleteProfileUseCase(repository),
      signOut = EmailSignOutUseCase(repository);
}
