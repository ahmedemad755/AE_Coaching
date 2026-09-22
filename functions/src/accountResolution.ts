import { Auth } from 'firebase-admin/auth';
import { syntheticEmailFromCanonicalPhone } from './syntheticEmail';

export interface AccountResolution {
  eligible: boolean;
  uid: string | null;
}

/**
 * Read-only Admin SDK lookups — NEVER creates, deletes, or modifies
 * any Firebase Auth user. Eligible only if BOTH lookups succeed and
 * resolve to the exact same UID (per the approved design: phone
 * provider and synthetic email/password provider must already belong
 * to the same account before a reset is ever attempted).
 *
 * Every other case — unknown phone, no synthetic-email account
 * (covers an unmigrated legacy password-only account, and also a
 * Phase-3 registration stuck in its own "needs password" partial
 * state), or a phone/email UID mismatch — is uniformly ineligible.
 * The caller must not distinguish these cases in any client-visible
 * way (see requestPasswordReset.ts).
 */
export async function resolveExistingAccount(
  auth: Auth,
  canonicalPhone: string
): Promise<AccountResolution> {
  const syntheticEmail = syntheticEmailFromCanonicalPhone(canonicalPhone);

  let phoneUid: string | null = null;
  let emailUid: string | null = null;

  try {
    const phoneUser = await auth.getUserByPhoneNumber(canonicalPhone);
    phoneUid = phoneUser.uid;
  } catch (err) {
    if (!isUserNotFound(err)) throw err;
  }

  try {
    const emailUser = await auth.getUserByEmail(syntheticEmail);
    emailUid = emailUser.uid;
  } catch (err) {
    if (!isUserNotFound(err)) throw err;
  }

  if (phoneUid !== null && emailUid !== null && phoneUid === emailUid) {
    return { eligible: true, uid: phoneUid };
  }
  // Mismatch, or either/both missing — never revealed to the client,
  // and never acted on beyond marking ineligible. A phone/email UID
  // mismatch specifically is a data-integrity anomaly worth a human
  // looking at (log server-side only, never surfaced to the caller).
  return { eligible: false, uid: null };
}

function isUserNotFound(err: unknown): boolean {
  return (
    typeof err === 'object' &&
    err !== null &&
    'code' in err &&
    (err as { code?: string }).code === 'auth/user-not-found'
  );
}
