/// Thrown when a phone number cannot be normalized into a valid
/// Egyptian mobile number. Carries a user-facing [message].
class PhoneNormalizationException implements Exception {
  final String message;

  const PhoneNormalizationException(this.message);

  @override
  String toString() => message;
}

/// Single source of truth for turning any of the accepted Egyptian
/// mobile phone input formats into one canonical E.164 string
/// (`+20XXXXXXXXXX`).
///
/// Accepted equivalent inputs (formatting characters like spaces,
/// hyphens, and parentheses are stripped before validation):
///   01012345678
///   +201012345678
///   00201012345678
///   201012345678
/// all normalize to: +201012345678
///
/// Valid Egyptian mobile prefixes: 010, 011, 012, 015.
///
/// This normalizer only decides the canonical phone string. It does
/// NOT change how the synthetic Firebase Auth email is derived from
/// that string — `u<digitsOnly>@ae-coaching.app` still strips all
/// non-digit characters (including the leading `+`) from whatever
/// canonical value this returns, exactly as before.
class EgyptianPhoneNormalizer {
  const EgyptianPhoneNormalizer._();

  static const List<String> _validNationalPrefixes = ['10', '11', '12', '15'];

  /// Normalizes [rawInput] into the canonical `+20XXXXXXXXXX` form.
  ///
  /// Throws [PhoneNormalizationException] if the input is empty,
  /// the wrong length, uses an unsupported prefix, or otherwise
  /// cannot be recognized as a valid Egyptian mobile number.
  static String normalize(String rawInput) {
    if (rawInput.trim().isEmpty) {
      throw const PhoneNormalizationException('Phone number is required.');
    }

    final digitsOnly = rawInput.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      throw const PhoneNormalizationException('Phone number is required.');
    }

    final String? national = _extractNationalNumber(digitsOnly);

    if (national == null) {
      throw const PhoneNormalizationException(
        'Enter a valid Egyptian mobile number.',
      );
    }

    final prefix = national.substring(0, 2);
    if (!_validNationalPrefixes.contains(prefix)) {
      throw const PhoneNormalizationException(
        'Unsupported Egyptian mobile prefix. Use 010, 011, 012, or 015.',
      );
    }

    return '+20$national';
  }

  /// Returns the 10-digit national number (e.g. `1012345678`, no
  /// leading zero, no country code) for a recognized digit-length
  /// pattern, or null if [digits] doesn't match any known shape.
  static String? _extractNationalNumber(String digits) {
    // 00 20 1XXXXXXXXX  (14 digits)
    if (digits.length == 14 && digits.startsWith('0020')) {
      return digits.substring(4);
    }
    // 20 1XXXXXXXXX  (12 digits, e.g. from "+201XXXXXXXXX")
    if (digits.length == 12 && digits.startsWith('20')) {
      return digits.substring(2);
    }
    // 0 1XXXXXXXXX  (11 digits, local format)
    if (digits.length == 11 && digits.startsWith('01')) {
      return digits.substring(1);
    }
    // 1XXXXXXXXX  (10 digits, no leading zero, no country code)
    if (digits.length == 10 && digits.startsWith('1')) {
      return digits;
    }
    return null;
  }
}
