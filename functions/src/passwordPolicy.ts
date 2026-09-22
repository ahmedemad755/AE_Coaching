import { MIN_PASSWORD_LENGTH } from './config';

export class WeakPasswordError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'WeakPasswordError';
  }
}

/**
 * Server-side password validation, checked BEFORE any challenge/OTP
 * state is touched (see completePasswordReset.ts) so a weak password
 * never burns an OTP attempt.
 *
 * NOTE — verified, not assumed: repository inspection found no
 * evidence of a custom Identity Platform password policy configured
 * for this project (the Flutter client has only ever used a uniform
 * "≥6 characters" rule across every registration/reset screen since
 * Phase 1). I could not obtain a definitive confirmation from Firebase
 * documentation on whether `admin.auth().updateUser` independently
 * enforces a project's configured password policy — so this function
 * does NOT rely on that; it is the sole enforcement point regardless
 * of what Admin SDK does or doesn't additionally check.
 *
 * ACTION ITEM before production: confirm in Firebase Console whether
 * a custom password policy has been configured for this project, and
 * update MIN_PASSWORD_LENGTH / add complexity rules here to match if
 * so.
 */
export function validatePasswordPolicy(newPassword: string): void {
  if (newPassword.length < MIN_PASSWORD_LENGTH) {
    throw new WeakPasswordError('Please choose a stronger password (at least 6 characters).');
  }
}
