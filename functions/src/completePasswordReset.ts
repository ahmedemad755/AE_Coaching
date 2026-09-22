import { Auth } from 'firebase-admin/auth';
import { Firestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { claimChallenge, commitCompletion } from './challengeStore';
import { hmacSha256Hex } from './crypto';
import { validatePasswordPolicy, WeakPasswordError } from './passwordPolicy';
import { OTP_HMAC_PEPPER, PASSWORD_INTENT_HMAC_PEPPER } from './secrets';

const GENERIC_INVALID_OR_EXPIRED = 'This code is invalid or has expired. Please request a new one.';

export interface CompletePasswordResetDeps {
  db: Firestore;
  auth: Auth;
  otpPepper: string;
  passwordIntentPepper: string;
}

/** Client-supplied input. Deliberately ONLY these three fields — no
 * uid, phone, email, or "eligible"/"otpVerified" flag is ever accepted
 * from the client (see the Phase 5B design: the client cannot be
 * trusted to assert any of that). */
export interface CompletePasswordResetInput {
  challengeId: unknown;
  otp: unknown;
  newPassword: unknown;
}

export interface CompletePasswordResetOutput {
  success: true;
}

/**
 * Business logic, separate from the `onCall` wrapper for the same
 * testability reason as requestPasswordReset.ts. Implements the
 * approved state machine exactly:
 *   1. validate password policy BEFORE touching any challenge state
 *      (so a weak password never burns an OTP attempt)
 *   2. transaction #1 (claimChallenge) — the only place OTP/lease/
 *      password-intent decisions are made
 *   3. admin.auth().updateUser(...) OUTSIDE any transaction, using
 *      only the server-resolved uid from the claim result
 *   4. transaction #2 (commitCompletion) — marks completed, retains
 *      hashes for the idempotency window
 *
 * Never calls createUser, deleteUser, linkWithCredential,
 * signInWithCredential, or verifyPhoneNumber. The only Firebase Auth
 * mutation anywhere in this function is the one intentional
 * updateUser(existingUid, { password }) call.
 */
export async function handleCompletePasswordReset(
  input: CompletePasswordResetInput,
  deps: CompletePasswordResetDeps
): Promise<CompletePasswordResetOutput> {
  if (
    typeof input.challengeId !== 'string' ||
    input.challengeId.length === 0 ||
    typeof input.otp !== 'string' ||
    input.otp.length === 0 ||
    typeof input.newPassword !== 'string'
  ) {
    throw new HttpsError('invalid-argument', 'Missing required fields.');
  }

  const challengeId = input.challengeId;
  const otp = input.otp;
  const newPassword = input.newPassword;

  // Step 1 — password policy FIRST, before any challenge/OTP state is
  // touched. A weak password costs the caller nothing.
  try {
    validatePasswordPolicy(newPassword);
  } catch (err) {
    if (err instanceof WeakPasswordError) {
      throw new HttpsError('invalid-argument', err.message);
    }
    throw err;
  }

  const otpCandidateHash = hmacSha256Hex(otp, deps.otpPepper);
  const intentCandidateHash = hmacSha256Hex(newPassword, deps.passwordIntentPepper);

  // Step 2 — transaction #1.
  const claim = await claimChallenge(deps.db, challengeId, otpCandidateHash, intentCandidateHash);

  if (claim.kind === 'idempotentSuccess') {
    return { success: true };
  }
  if (claim.kind === 'rejected') {
    throw new HttpsError('invalid-argument', GENERIC_INVALID_OR_EXPIRED);
  }

  // claim.kind === 'claimed' — only NOW do we touch Firebase Auth, and
  // only for the exact uid resolved and stored on the challenge at
  // creation time. Never a client-supplied uid.
  try {
    await deps.auth.updateUser(claim.uid, { password: newPassword });
  } catch (err) {
    // updateUser failed (e.g. account disabled, or a genuine Admin SDK
    // rejection). The challenge remains 'applying' with an active
    // lease that will expire and become reclaimable — no state
    // corruption, no silent success.
    throw new HttpsError('internal', 'We could not update your password. Please try again.');
  }

  // Step 4 — transaction #2. Never revert the password change that
  // already happened, even if this can't commit after bounded retries.
  await commitCompletion(deps.db, challengeId, claim.leaseId);

  return { success: true };
}

/** Production callable wrapper. App Check enforcement is configured
 * HERE — never disabled for tests (tests call
 * `handleCompletePasswordReset` directly instead). */
export const completePasswordReset = onCall(
  {
    // Explicit for the same reason as requestPasswordReset.ts — both
    // callables in this codebase must stay on the same region.
    region: 'us-central1',
    secrets: [OTP_HMAC_PEPPER, PASSWORD_INTENT_HMAC_PEPPER],
    enforceAppCheck: true,
  },
  async (request) => {
    const { getFirestore } = await import('firebase-admin/firestore');
    const { getAuth } = await import('firebase-admin/auth');

    const deps: CompletePasswordResetDeps = {
      db: getFirestore(),
      auth: getAuth(),
      otpPepper: OTP_HMAC_PEPPER.value(),
      passwordIntentPepper: PASSWORD_INTENT_HMAC_PEPPER.value(),
    };
    return handleCompletePasswordReset(
      request.data as CompletePasswordResetInput,
      deps
    );
  }
);
