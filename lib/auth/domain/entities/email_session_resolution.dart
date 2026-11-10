import 'package:ae_coaching/auth/domain/entities/auth_status.dart';
import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/validation/profile_integrity.dart';

export 'package:ae_coaching/auth/domain/validation/profile_integrity.dart'
    show ProfileFailure;

export 'package:ae_coaching/auth/domain/entities/auth_status.dart';

/// Outcome of resolving the current email-first session against Firebase
/// Auth and `users/{uid}`. Produced by login, registration, startup and
/// verification refresh, so every entry point routes through the same
/// [AuthStatus] decision.
class EmailSessionResolution {
  final AuthStatus status;

  /// Set only for [AuthStatus.authenticated].
  final AuthUser? user;

  /// The account email, for the Verify Email and Complete Profile
  /// screens.
  final String email;

  /// Registration only: whether the verification email actually went
  /// out. If false, the Verify Email screen asks the user to tap Resend.
  final bool verificationEmailSent;

  /// Set only for [AuthStatus.profileUnavailable].
  final ProfileFailure? profileFailure;

  const EmailSessionResolution._(
    this.status, {
    this.user,
    this.email = '',
    this.verificationEmailSent = false,
    this.profileFailure,
  });

  const EmailSessionResolution.unauthenticated()
    : this._(AuthStatus.unauthenticated);

  const EmailSessionResolution.authenticated(AuthUser user)
    : this._(AuthStatus.authenticated, user: user, email: '');

  const EmailSessionResolution.pendingVerification(
    String email, {
    bool verificationEmailSent = false,
  }) : this._(
         AuthStatus.pendingEmailVerification,
         email: email,
         verificationEmailSent: verificationEmailSent,
       );

  const EmailSessionResolution.incompleteProfile(String email)
    : this._(AuthStatus.incompleteProfile, email: email);

  const EmailSessionResolution.legacyAccount()
    : this._(AuthStatus.unsupportedLegacyAccount);

  const EmailSessionResolution.profileUnavailable(
    String email,
    ProfileFailure failure,
  ) : this._(
        AuthStatus.profileUnavailable,
        email: email,
        profileFailure: failure,
      );
}
