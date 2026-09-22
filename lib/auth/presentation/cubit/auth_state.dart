import 'package:ae_coaching/auth/domain/entities/auth_session_inspection.dart';
import 'package:ae_coaching/auth/domain/entities/auth_user.dart';

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

// تمت إضافة حالة نجاح إرسال كود الـ OTP مع الـ ID
class AuthOtpSent extends AuthState {
  final String verificationId;
  final String phone;
  AuthOtpSent(this.verificationId, this.phone);
}

/// A resumable, in-progress OTP registration is missing exactly one of
/// two things: a linked password, or a written `users/{uid}` profile.
/// Deliberately the only state added for Phase 3's recovery flow — no
/// larger state hierarchy.
class AuthPartialRegistration extends AuthState {
  final RegistrationRecoveryStep step;
  final String phone;
  AuthPartialRegistration({required this.step, required this.phone});
}

/// Phase 5B — signed-out Forgot Password: the trusted backend created
/// an OTP challenge. Deliberately distinct from [AuthOtpSent]:
/// [challengeId] is an opaque token issued by the Cloud Function, never
/// a Firebase phone-auth verificationId, and must never be stored in
/// [AuthOtpSent.verificationId]. Phase 3 (fresh registration) and
/// Phase 4 (legacy migration) continue to use real Firebase Phone Auth
/// and keep emitting [AuthOtpSent] unchanged.
class AuthPasswordResetOtpSent extends AuthState {
  final String challengeId;
  final String phone;
  AuthPasswordResetOtpSent({required this.challengeId, required this.phone});
}

/// Phase 5B — signed-out Forgot Password completed successfully.
/// Deliberately NOT [AuthSuccess]: every other screen in this app
/// treats [AuthSuccess] as "the user is now authenticated" and reacts
/// by writing a logged-in Hive session and navigating Home. A password
/// reset never authenticates the caller (the backend always ends
/// signed out) — using a distinct type makes that structurally
/// impossible to get wrong by copy-paste or by a future shared
/// listener, rather than relying on this one screen happening not to
/// react to [AuthSuccess] that way.
class AuthPasswordResetSuccess extends AuthState {
  final String message;
  AuthPasswordResetSuccess(this.message);
}
