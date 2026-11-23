/// Single definition of what registration and password inputs are
/// acceptable. The UI uses it for instant, localized feedback. The use
/// cases re-check it before anything reaches Firebase, so client form
/// validation is never the only line. The real enforcement still lives
/// in Firebase Auth (password rules) and in the password-reset Cloud
/// Function (`functions/src/passwordPolicy.ts`).
library;

enum NameInputError { required, tooLong, noLetters }

enum PasswordInputError { required, tooShort, tooLong, edgeWhitespace }

enum ConfirmPasswordInputError { required, mismatch }

enum EmailInputError { required, invalid, tooLong, reservedDomain }

class AuthInputRules {
  const AuthInputRules._();

  /// Firebase Auth's default minimum. It must equal
  /// `MIN_PASSWORD_LENGTH` in functions/src/config.ts, or a password
  /// accepted at registration could be rejected by Forgot Password (or
  /// the reverse).
  static const int passwordMinLength = 6;

  /// Generous upper bound so a pasted blob can't be submitted by mistake.
  static const int passwordMaxLength = 128;

  static const int nameMaxLength = 60;

  /// RFC 5321 practical maximum.
  static const int emailMaxLength = 254;

  /// Domain of the synthetic sign-in emails phone-era accounts were
  /// created with (`u<digits>@ae-coaching.app`). Reserved: a new account
  /// must never collide with, or impersonate, one of those dormant
  /// accounts.
  static const String reservedEmailDomain = 'ae-coaching.app';

  // Deliberately loose (something@something.tld, no spaces). Firebase is
  // the real validator, and over-strict patterns reject valid addresses.
  static final RegExp _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static final RegExp _anyLetter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _whitespaceRun = RegExp(r'\s+');

  /// Trims and collapses internal whitespace ("  Ahmed   Emad " →
  /// "Ahmed Emad"). Never applied to passwords.
  static String normalizeName(String raw) =>
      raw.trim().replaceAll(_whitespaceRun, ' ');

  /// Deliberately permissive: any script (Arabic, Latin, …), hyphens,
  /// apostrophes, single-letter names. It only rejects blank input, input
  /// with no letters at all (e.g. "123"), and absurd lengths.
  static NameInputError? validateName(String raw) {
    final name = normalizeName(raw);
    if (name.isEmpty) return NameInputError.required;
    if (name.length > nameMaxLength) return NameInputError.tooLong;
    if (!_anyLetter.hasMatch(name)) return NameInputError.noLetters;
    return null;
  }

  /// Trimmed and lower-cased. Firebase Auth treats emails
  /// case-insensitively, and storing one form keeps `users/{uid}.email`
  /// consistent.
  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  static EmailInputError? validateEmail(String raw) {
    final email = normalizeEmail(raw);
    if (email.isEmpty) return EmailInputError.required;
    if (email.length > emailMaxLength) return EmailInputError.tooLong;
    if (!_emailShape.hasMatch(email)) return EmailInputError.invalid;
    if (isReservedEmail(email)) return EmailInputError.reservedDomain;
    return null;
  }

  static bool isReservedEmail(String email) {
    final normalized = normalizeEmail(email);
    return normalized.endsWith('@$reservedEmailDomain') ||
        normalized.endsWith('.$reservedEmailDomain');
  }

  /// Rules for a password being SET (registration, set-password resume,
  /// reset).
  ///
  /// Compatibility note (Stage 2 audit): every historical write path
  /// trimmed passwords before sending them to Firebase, and so does login.
  /// No stored password can start or end with whitespace. New passwords
  /// are therefore REJECTED (not silently trimmed) when they have edge
  /// whitespace. Firebase then stores exactly what the user typed, and
  /// the trimming in [passwordForSignIn] stays a no-op for them.
  static PasswordInputError? validateNewPassword(String raw) {
    if (raw.isEmpty) return PasswordInputError.required;
    if (raw.trim() != raw) return PasswordInputError.edgeWhitespace;
    if (raw.length < passwordMinLength) return PasswordInputError.tooShort;
    if (raw.length > passwordMaxLength) return PasswordInputError.tooLong;
    return null;
  }

  static ConfirmPasswordInputError? validateConfirmation(
    String password,
    String confirmation,
  ) {
    if (confirmation.isEmpty) return ConfirmPasswordInputError.required;
    if (confirmation != password) return ConfirmPasswordInputError.mismatch;
    return null;
  }

  /// The password to send for SIGN-IN. Kept trimming for backward
  /// compatibility: every account's stored password was trimmed when it
  /// was created, and password managers or keyboards sometimes append a
  /// trailing space. Removing this would lock those users out.
  static String passwordForSignIn(String raw) => raw.trim();
}

/// Domain-boundary guards used by the use cases. Each throws a plain
/// [Exception] carrying an English message, the same convention as the
/// data source. `localizeAuthError` translates these for the UI.
class AuthInputGuard {
  const AuthInputGuard._();

  static const String weakPasswordMessage =
      'Please choose a stronger password (at least 6 characters).';
  static const String passwordEdgeWhitespaceMessage =
      "Your password can't start or end with a space.";
  static const String invalidNameMessage = 'Please enter a valid name.';
  static const String invalidEmailMessage = 'Enter a valid email address.';

  /// Returns the normalized email, or throws.
  static String requireEmail(String email) {
    if (AuthInputRules.validateEmail(email) != null) {
      throw Exception(invalidEmailMessage);
    }
    return AuthInputRules.normalizeEmail(email);
  }

  static void requireNewPassword(String password) {
    switch (AuthInputRules.validateNewPassword(password)) {
      case null:
        return;
      case PasswordInputError.edgeWhitespace:
        throw Exception(passwordEdgeWhitespaceMessage);
      case PasswordInputError.required:
      case PasswordInputError.tooShort:
      case PasswordInputError.tooLong:
        throw Exception(weakPasswordMessage);
    }
  }

  /// Returns the normalized name, or throws.
  static String requireName(String name) {
    if (AuthInputRules.validateName(name) != null) {
      throw Exception(invalidNameMessage);
    }
    return AuthInputRules.normalizeName(name);
  }
}
