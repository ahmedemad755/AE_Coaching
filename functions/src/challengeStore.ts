import { Firestore, Timestamp, Transaction } from 'firebase-admin/firestore';
import {
  CHALLENGES_COLLECTION,
  COMPLETED_RETENTION_SECONDS,
  LEASE_DURATION_SECONDS,
  OTP_EXPIRY_SECONDS,
  OTP_MAX_ATTEMPTS,
} from './config';
import { generateChallengeId, generateLeaseId, timingSafeEqualHex } from './crypto';

export type ChallengeState = 'pending' | 'applying' | 'completed' | 'failed';

/** Firestore document shape for `passwordResetChallenges/{challengeId}`.
 * Server-only — see firestore.rules.local for the (not yet deployed)
 * intended security rule denying ALL client read/write access. */
export interface ChallengeDoc {
  canonicalPhone: string;
  uid: string | null; // null only for a dead/ineligible challenge
  eligible: boolean;

  otpHash: string | null; // HMAC-SHA256(otp, OTP_HMAC_PEPPER); never plaintext
  otpAttemptCount: number;
  otpMaxAttempts: number;
  otpExpiresAt: Timestamp;

  passwordIntentHash: string | null; // HMAC-SHA256(rawPassword, PASSWORD_INTENT_HMAC_PEPPER)

  state: ChallengeState;
  leaseId: string | null;
  leaseExpiresAt: Timestamp | null;

  createdAt: Timestamp;
  /** Firestore TTL policy anchor field (see README-firestore-ttl.md /
   * the Phase 5B report — TTL must be explicitly enabled on this field
   * in Console/gcloud; it is NOT automatic just because this field
   * exists). Extended on completion so the idempotency window (below)
   * survives past the original OTP expiry. */
  retainUntil: Timestamp;
}

export type ClaimOutcome =
  | { kind: 'claimed'; uid: string; leaseId: string }
  | { kind: 'idempotentSuccess' }
  | { kind: 'rejected' };

function addSeconds(base: Timestamp, seconds: number): Timestamp {
  return Timestamp.fromMillis(base.toMillis() + seconds * 1000);
}

function isExpired(ts: Timestamp, now: Timestamp): boolean {
  return ts.toMillis() <= now.toMillis();
}

/** Creates a real, eligible challenge — called only AFTER the SMS
 * provider has already confirmed acceptance of the message (see
 * requestPasswordReset.ts; never write a usable challenge before the
 * OTP has actually been sent). */
export async function createEligibleChallenge(
  db: Firestore,
  params: { canonicalPhone: string; uid: string; otpHash: string }
): Promise<string> {
  const challengeId = generateChallengeId();
  const now = Timestamp.now();
  const doc: ChallengeDoc = {
    canonicalPhone: params.canonicalPhone,
    uid: params.uid,
    eligible: true,
    otpHash: params.otpHash,
    otpAttemptCount: 0,
    otpMaxAttempts: OTP_MAX_ATTEMPTS,
    otpExpiresAt: addSeconds(now, OTP_EXPIRY_SECONDS),
    passwordIntentHash: null,
    state: 'pending',
    leaseId: null,
    leaseExpiresAt: null,
    createdAt: now,
    retainUntil: addSeconds(now, OTP_EXPIRY_SECONDS + COMPLETED_RETENTION_SECONDS),
  };
  await db.collection(CHALLENGES_COLLECTION).doc(challengeId).set(doc);
  return challengeId;
}

/** Creates a "dead" challenge for an ineligible phone (unknown,
 * unmigrated-legacy, or UID-mismatched) — no real OTP, no SMS ever
 * sent, but the same document shape and later response behavior as a
 * real challenge, so the client cannot distinguish the two. */
export async function createDeadChallenge(
  db: Firestore,
  params: { canonicalPhone: string; unusableOtpHash: string }
): Promise<string> {
  const challengeId = generateChallengeId();
  const now = Timestamp.now();
  const doc: ChallengeDoc = {
    canonicalPhone: params.canonicalPhone,
    uid: null,
    eligible: false,
    otpHash: params.unusableOtpHash,
    otpAttemptCount: 0,
    otpMaxAttempts: OTP_MAX_ATTEMPTS,
    otpExpiresAt: addSeconds(now, OTP_EXPIRY_SECONDS),
    passwordIntentHash: null,
    state: 'pending',
    leaseId: null,
    leaseExpiresAt: null,
    createdAt: now,
    retainUntil: addSeconds(now, OTP_EXPIRY_SECONDS + COMPLETED_RETENTION_SECONDS),
  };
  await db.collection(CHALLENGES_COLLECTION).doc(challengeId).set(doc);
  return challengeId;
}

/**
 * Transaction #1 of the approved state machine. Implements scenarios
 * 1–8 exactly as specified in the Phase 5B finalized design. Never
 * calls Firebase Auth — that happens outside this transaction, only
 * when this function returns `{ kind: 'claimed' }`.
 */
export async function claimChallenge(
  db: Firestore,
  challengeId: string,
  otpCandidateHash: string,
  intentCandidateHash: string
): Promise<ClaimOutcome> {
  const ref = db.collection(CHALLENGES_COLLECTION).doc(challengeId);

  return db.runTransaction(async (tx: Transaction): Promise<ClaimOutcome> => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      return { kind: 'rejected' };
    }
    const d = snap.data() as ChallengeDoc;
    const now = Timestamp.now();

    // Top-of-function expiry / attempt-budget checks (scenario 8, and
    // the attempt-cap check shared by 'pending' and 'applying').
    if (d.state === 'pending' && isExpired(d.otpExpiresAt, now)) {
      tx.update(ref, { state: 'failed', otpHash: null, passwordIntentHash: null });
      return { kind: 'rejected' };
    }
    if ((d.state === 'pending' || d.state === 'applying') && d.otpAttemptCount >= d.otpMaxAttempts) {
      tx.update(ref, { state: 'failed', otpHash: null, passwordIntentHash: null });
      return { kind: 'rejected' };
    }

    switch (d.state) {
      case 'pending': {
        // scenario 1
        const otpMatches = d.otpHash !== null && timingSafeEqualHex(otpCandidateHash, d.otpHash);
        if (!otpMatches || d.eligible !== true) {
          const nextCount = d.otpAttemptCount + 1;
          if (nextCount >= d.otpMaxAttempts) {
            tx.update(ref, {
              otpAttemptCount: nextCount,
              state: 'failed',
              otpHash: null,
              passwordIntentHash: null,
            });
          } else {
            tx.update(ref, { otpAttemptCount: nextCount });
          }
          return { kind: 'rejected' };
        }
        // Correct OTP, eligible — claim the lease and bind intent for
        // the FIRST time.
        const leaseId = generateLeaseId();
        tx.update(ref, {
          state: 'applying',
          leaseId,
          leaseExpiresAt: addSeconds(now, LEASE_DURATION_SECONDS),
          passwordIntentHash: intentCandidateHash,
        });
        return { kind: 'claimed', uid: d.uid as string, leaseId };
      }

      case 'applying': {
        if (d.leaseExpiresAt !== null && !isExpired(d.leaseExpiresAt, now)) {
          // scenario 2 — active lease held by someone else right now.
          return { kind: 'rejected' };
        }
        // Lease expired — reclaim path.
        const otpMatches = d.otpHash !== null && timingSafeEqualHex(otpCandidateHash, d.otpHash);
        if (!otpMatches) {
          const nextCount = d.otpAttemptCount + 1;
          if (nextCount >= d.otpMaxAttempts) {
            tx.update(ref, {
              otpAttemptCount: nextCount,
              state: 'failed',
              otpHash: null,
              passwordIntentHash: null,
            });
          } else {
            tx.update(ref, { otpAttemptCount: nextCount });
          }
          return { kind: 'rejected' };
        }
        const intentMatches =
          d.passwordIntentHash !== null && timingSafeEqualHex(intentCandidateHash, d.passwordIntentHash);
        if (!intentMatches) {
          // scenario 4 — different password intent. Reject WITHOUT
          // touching passwordIntentHash.
          return { kind: 'rejected' };
        }
        // scenario 3 — same OTP, same password intent: reclaim.
        const leaseId = generateLeaseId();
        tx.update(ref, {
          leaseId,
          leaseExpiresAt: addSeconds(now, LEASE_DURATION_SECONDS),
        });
        return { kind: 'claimed', uid: d.uid as string, leaseId };
      }

      case 'completed': {
        const otpMatches = d.otpHash !== null && timingSafeEqualHex(otpCandidateHash, d.otpHash);
        const intentMatches =
          d.passwordIntentHash !== null && timingSafeEqualHex(intentCandidateHash, d.passwordIntentHash);
        if (otpMatches && intentMatches) {
          // scenario 5 — idempotent success, no Auth call.
          return { kind: 'idempotentSuccess' };
        }
        // scenario 6 (wrong OTP) and the "same OTP, different
        // password" case both land here — generic rejection either way.
        return { kind: 'rejected' };
      }

      case 'failed':
      default:
        // scenario 7
        return { kind: 'rejected' };
    }
  });
}

/**
 * Transaction #2. Marks the challenge `completed` ONLY if it is still
 * `applying` with the exact lease this caller acquired. Never reverts
 * a password change that has already taken effect — if this can't
 * commit after bounded retries, the caller must still report success
 * to the user (the Auth-side change already happened).
 */
export async function commitCompletion(
  db: Firestore,
  challengeId: string,
  leaseId: string,
  maxRetries = 3
): Promise<'committed' | 'staleNoop'> {
  const ref = db.collection(CHALLENGES_COLLECTION).doc(challengeId);

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const result = await db.runTransaction(async (tx: Transaction): Promise<'committed' | 'staleNoop'> => {
        const snap = await tx.get(ref);
        if (!snap.exists) return 'staleNoop';
        const d = snap.data() as ChallengeDoc;
        if (d.state === 'applying' && d.leaseId === leaseId) {
          const now = Timestamp.now();
          tx.update(ref, {
            state: 'completed',
            leaseId: null,
            leaseExpiresAt: null,
            // otpHash / passwordIntentHash RETAINED for the idempotency
            // window (see the schema comment) — not cleared here.
            retainUntil: addSeconds(now, COMPLETED_RETENTION_SECONDS),
          });
          return 'committed';
        }
        return 'staleNoop';
      });
      return result;
    } catch (err) {
      if (attempt === maxRetries - 1) {
        // Exhausted retries on a transient Firestore error. The
        // password change already happened server-side; we do not
        // attempt to undo it. Caller reports a generic response.
        return 'staleNoop';
      }
    }
  }
  return 'staleNoop';
}
