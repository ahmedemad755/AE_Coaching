import 'package:ae_coaching/auth/domain/entities/auth_user.dart';

/// The exact step a new-user OTP registration is missing when a Firebase
/// session is found without a completed `users/{uid}` profile. Kept to
/// these two values deliberately — no larger state hierarchy is needed
/// to describe "what's left to finish."
enum RegistrationRecoveryStep {
  /// Phone provider is linked (phone-authenticated), but no password
  /// provider is linked yet.
  needsPassword,

  /// Phone + password providers are both linked, but `users/{uid}` has
  /// not been written yet.
  needsProfile,
}

/// Result of inspecting the current Firebase session at app startup,
/// used to decide whether a Hive-logged-out UI is hiding a real,
/// resumable Firebase session underneath it. Exactly one of
/// [completedUser] or [recoveryStep] is non-null; both are null only
/// when there is no session to reconcile at all.
class AuthSessionInspection {
  final AuthUser? completedUser;
  final RegistrationRecoveryStep? recoveryStep;
  final String? phone;

  const AuthSessionInspection.noSession()
    : completedUser = null,
      recoveryStep = null,
      phone = null;

  const AuthSessionInspection.complete(AuthUser user)
    : completedUser = user,
      recoveryStep = null,
      phone = null;

  const AuthSessionInspection.recovery(
    RegistrationRecoveryStep step,
    this.phone,
  ) : completedUser = null,
      recoveryStep = step;
}
