/**
 * Server-side re-implementation of the Flutter app's
 * `EgyptianPhoneNormalizer` (lib/core/utils/phone_normalizer.dart).
 *
 * This MUST stay behaviorally identical to the Dart version — the
 * backend never trusts client-side normalization (a client could send
 * anything), so every phone number is re-normalized here from scratch
 * before it's used for account lookup or SMS delivery.
 */

export class PhoneNormalizationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PhoneNormalizationError';
  }
}

const VALID_NATIONAL_PREFIXES = ['10', '11', '12', '15'];

/** Extracts the 10-digit national number (e.g. "1012345678", no
 * leading zero, no country code) for a recognized digit-length
 * pattern, or null if `digits` doesn't match any known shape. Mirrors
 * `_extractNationalNumber` in the Dart implementation exactly. */
function extractNationalNumber(digits: string): string | null {
  // 00 20 1XXXXXXXXX (14 digits)
  if (digits.length === 14 && digits.startsWith('0020')) {
    return digits.substring(4);
  }
  // 20 1XXXXXXXXX (12 digits, e.g. from "+201XXXXXXXXX")
  if (digits.length === 12 && digits.startsWith('20')) {
    return digits.substring(2);
  }
  // 0 1XXXXXXXXX (11 digits, local format)
  if (digits.length === 11 && digits.startsWith('01')) {
    return digits.substring(1);
  }
  // 1XXXXXXXXX (10 digits, no leading zero, no country code)
  if (digits.length === 10 && digits.startsWith('1')) {
    return digits;
  }
  return null;
}

/**
 * Normalizes `rawInput` into the canonical `+20XXXXXXXXXX` form.
 * Throws `PhoneNormalizationError` for empty, malformed, or
 * unsupported-prefix input — never guesses.
 */
export function normalizeEgyptianPhone(rawInput: string): string {
  if (rawInput.trim().length === 0) {
    throw new PhoneNormalizationError('Phone number is required.');
  }

  const digitsOnly = rawInput.replace(/[^0-9]/g, '');

  if (digitsOnly.length === 0) {
    throw new PhoneNormalizationError('Phone number is required.');
  }

  const national = extractNationalNumber(digitsOnly);

  if (national === null) {
    throw new PhoneNormalizationError('Enter a valid Egyptian mobile number.');
  }

  const prefix = national.substring(0, 2);
  if (!VALID_NATIONAL_PREFIXES.includes(prefix)) {
    throw new PhoneNormalizationError(
      'Unsupported Egyptian mobile prefix. Use 010, 011, 012, or 015.'
    );
  }

  return `+20${national}`;
}
