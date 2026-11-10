import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/validation/profile_integrity.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String? message;
  final AuthUser? user;

  AuthSuccess({this.message, this.user});
}

// تمت إضافة حالة الخطأ
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

/// The Firebase session was ended on purpose (Sign out from Verify Email,
/// Complete Profile or a failed account check). Screens react by going to
/// Login, never Home.
class AuthSignedOut extends AuthState {}

/// Signed in, but the email isn't verified. The only allowed screen is
/// Verify Email. Never treated as authenticated.
class AuthEmailVerificationRequired extends AuthState {
  final String email;

  /// True right after registration if the first email went out, so the
  /// screen starts the resend cooldown instead of offering an immediate
  /// resend.
  final bool verificationEmailSent;

  AuthEmailVerificationRequired({
    required this.email,
    this.verificationEmailSent = false,
  });
}

/// Verified, but `users/{uid}` is missing and no name could be
/// recovered. The user must enter a name.
class AuthProfileIncomplete extends AuthState {
  final String email;
  AuthProfileIncomplete(this.email);
}

/// A phone-era test account's session was found and signed out. The
/// account and its data are untouched.
class AuthLegacyAccountSignedOut extends AuthState {}

class AuthVerificationEmailSent extends AuthState {}

/// A link was sent to [newEmail]. The sign-in email changes only after it
/// is opened.
class AuthEmailChangeRequested extends AuthState {
  final String newEmail;
  AuthEmailChangeRequested(this.newEmail);
}

/// Neutral by design: shown whether or not an account exists.
class AuthPasswordResetEmailSent extends AuthState {
  final String email;
  AuthPasswordResetEmailSent(this.email);
}

/// Verified, but the profile could not be confirmed (offline, permission
/// denied, conflicting document). Never a success: the account check
/// shows the real reason with Retry / Sign out.
class AuthProfileUnavailable extends AuthState {
  final String email;
  final ProfileFailure failure;
  AuthProfileUnavailable({required this.email, required this.failure});
}
