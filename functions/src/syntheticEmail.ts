import { SYNTHETIC_EMAIL_DOMAIN } from './config';
import { PhoneNormalizationError } from './phoneNormalizer';

/**
 * Server-side re-implementation of `_authEmailFromPhone` in
 * `auth_remote_data_source.dart`. Must remain EXACTLY compatible —
 * this is what lets the backend resolve the same Firebase Auth user
 * the Flutter client's email/password provider is linked to.
 *
 * Given a canonical `+20XXXXXXXXXX` phone, strips all non-digit
 * characters (including the leading `+`) and builds
 * `u<digits>@ae-coaching.app` — identical algorithm, identical output.
 */
export function syntheticEmailFromCanonicalPhone(canonicalPhone: string): string {
  const digitsOnly = canonicalPhone.replace(/[^0-9]/g, '');
  if (digitsOnly.length === 0) {
    throw new PhoneNormalizationError('Invalid phone number.');
  }
  return `u${digitsOnly}@${SYNTHETIC_EMAIL_DOMAIN}`;
}
