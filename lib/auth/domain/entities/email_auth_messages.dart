/// Fixed English messages produced by the email-first auth flow. They
/// live in the domain layer so views can react to one (e.g. an expired
/// session) without importing the data layer. `localizeAuthError`
/// translates each of them, and its test fails if one is added
/// untranslated.
class EmailAuthMessages {
  const EmailAuthMessages._();

  static const String incorrectCredentials = 'Incorrect email or password.';
  static const String emailInUse =
      'An account already exists for this email. Please log in instead.';
  static const String newEmailInUse =
      'This email address is already used by another account.';
  static const String recentLogin =
      'For your security, please sign in again to change your email.';
  static const String sessionExpired =
      'Your session has expired. Please sign in again.';
  static const String network =
      'Network error. Please check your connection and try again.';
  static const String tooManyRequests =
      'Too many attempts. Please try again later.';
  static const String disabled =
      'This account has been disabled. Please contact support.';
  static const String generic = 'Something went wrong. Please try again.';
  static const String noSession =
      'Your session has ended. Please sign in again.';

  /// Saving the name on Complete Profile was rejected by Firestore.
  static const String profilePermissionDenied =
      "We couldn't save your profile because access was denied. Please contact support.";

  /// The profile document belongs to a different account.
  static const String profileConflicting =
      'Your account profile needs attention. Please contact support.';

  /// Errors after which the session is gone and the user belongs on Login.
  static const Set<String> endedSession = {sessionExpired, noSession};
}
