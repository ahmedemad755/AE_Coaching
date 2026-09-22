import { Firestore, Timestamp, Transaction } from 'firebase-admin/firestore';
import {
  REQUESTS_PER_PHONE_WINDOW_MAX,
  REQUESTS_PER_PHONE_WINDOW_SECONDS,
  RESEND_COOLDOWN_SECONDS,
} from './config';

const RATE_LIMIT_COLLECTION = 'passwordResetRateLimits';

export class RateLimitExceededError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'RateLimitExceededError';
  }
}

interface RateLimitDoc {
  windowStart: Timestamp;
  count: number;
  lastRequestAt: Timestamp;
}

/**
 * Per-canonical-phone rate limiting: a resend cooldown plus a rolling
 * per-hour request cap. Implemented as a single Firestore transaction
 * per check so concurrent requests for the same phone can't both slip
 * through.
 *
 * DEFERRED, NOT IMPLEMENTED IN THIS STAGE: per-IP/per-device limiting.
 * A 2nd-gen callable function's request context does expose
 * `request.rawRequest.ip`, but this value is only as reliable as
 * whatever's in front of Cloud Functions (proxies/CDNs can make it
 * trivially spoofable or uniformly identical for many real users) —
 * treating it as a trustworthy rate-limit key would be pretending to a
 * safety property it doesn't reliably provide. App Check (see the
 * callable function wiring) is the primary non-per-phone abuse signal
 * in this design; a dedicated per-App-Check-instance limiter is a
 * reasonable future addition but is out of scope for this stage.
 */
export async function checkAndRecordPhoneRateLimit(db: Firestore, canonicalPhone: string): Promise<void> {
  const ref = db.collection(RATE_LIMIT_COLLECTION).doc(canonicalPhone);

  await db.runTransaction(async (tx: Transaction) => {
    const snap = await tx.get(ref);
    const now = Timestamp.now();

    if (!snap.exists) {
      const doc: RateLimitDoc = { windowStart: now, count: 1, lastRequestAt: now };
      tx.set(ref, doc);
      return;
    }

    const data = snap.data() as RateLimitDoc;
    const secondsSinceLast = (now.toMillis() - data.lastRequestAt.toMillis()) / 1000;
    if (secondsSinceLast < RESEND_COOLDOWN_SECONDS) {
      throw new RateLimitExceededError('Please wait before requesting another code.');
    }

    const secondsSinceWindowStart = (now.toMillis() - data.windowStart.toMillis()) / 1000;
    if (secondsSinceWindowStart > REQUESTS_PER_PHONE_WINDOW_SECONDS) {
      const doc: RateLimitDoc = { windowStart: now, count: 1, lastRequestAt: now };
      tx.set(ref, doc);
      return;
    }

    if (data.count >= REQUESTS_PER_PHONE_WINDOW_MAX) {
      throw new RateLimitExceededError('Too many requests. Please try again later.');
    }

    tx.update(ref, { count: data.count + 1, lastRequestAt: now });
  });
}
