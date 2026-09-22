import { Auth } from 'firebase-admin/auth';
import { Firestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { resolveExistingAccount } from './accountResolution';
import { createDeadChallenge, createEligibleChallenge } from './challengeStore';
import { generateSixDigitOtp, hmacSha256Hex } from './crypto';
import { isFunctionsEmulator } from './emulatorEnv';
import { EmulatorFileSmsProvider } from './emulatorSmsOutbox';
import { normalizeEgyptianPhone, PhoneNormalizationError } from './phoneNormalizer';
import { checkAndRecordPhoneRateLimit, RateLimitExceededError } from './rateLimiter';
import { OTP_HMAC_PEPPER, SMS_PROVIDER_ACCOUNT_SID, SMS_PROVIDER_AUTH_TOKEN, SMS_PROVIDER_FROM_NUMBER } from './secrets';
import { otpMessageBody, SmsProvider, TwilioSmsProvider } from './smsProvider';

/** Response message is IDENTICAL for every outcome (eligible,
 * unknown phone, unmigrated-legacy, UID mismatch, or a "dead" replay
 * of the ineligible path) — see the anti-enumeration section of the
 * Phase 5B report. */
const GENERIC_MESSAGE = "If an eligible account exists for this number, we've sent a verification code.";

/** Calibrated to sit in the same ballpark as a typical SMS-provider API
 * round trip, so the ineligible path doesn't finish suspiciously
 * faster than the eligible one. A mitigation, not a guarantee — see
 * the Phase 5B report's honest framing of this. */
const INELIGIBLE_PATH_DELAY_MS = 400;

export interface RequestPasswordResetDeps {
  db: Firestore;
  auth: Auth;
  smsProvider: SmsProvider;
  otpPepper: string;
}

export interface RequestPasswordResetInput {
  phone: unknown;
}

export interface RequestPasswordResetOutput {
  challengeId: string;
  message: string;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Business logic, deliberately separate from the `onCall` transport
 * wrapper below so it is directly unit/emulator-testable without
 * needing to simulate real App Check device attestation. App Check
 * enforcement itself is configured on the wrapper (`requestPasswordReset`
 * export), not bypassed here — see the Phase 5B report.
 *
 * Never returns: uid, synthetic email, eligible flag, provider state,
 * the OTP, or the OTP hash. Never creates or deletes a Firebase Auth
 * user (only `resolveExistingAccount`'s read-only lookups touch Auth
 * at all in this function).
 */
export async function handleRequestPasswordReset(
  input: RequestPasswordResetInput,
  deps: RequestPasswordResetDeps
): Promise<RequestPasswordResetOutput> {
  if (typeof input.phone !== 'string' || input.phone.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'A phone number is required.');
  }

  let canonicalPhone: string;
  try {
    canonicalPhone = normalizeEgyptianPhone(input.phone);
  } catch (err) {
    if (err instanceof PhoneNormalizationError) {
      throw new HttpsError('invalid-argument', err.message);
    }
    throw err;
  }

  try {
    await checkAndRecordPhoneRateLimit(deps.db, canonicalPhone);
  } catch (err) {
    if (err instanceof RateLimitExceededError) {
      throw new HttpsError('resource-exhausted', err.message);
    }
    throw err;
  }

  const resolution = await resolveExistingAccount(deps.auth, canonicalPhone);

  if (resolution.eligible && resolution.uid !== null) {
    const otp = generateSixDigitOtp();
    const otpHash = hmacSha256Hex(otp, deps.otpPepper);

    try {
      // MUST be awaited — no fire-and-forget (Phase 5B correction).
      await deps.smsProvider.send(canonicalPhone, otpMessageBody(otp));
    } catch {
      // SMS provider failed: create NO usable challenge. Honest
      // operational error — not an enumeration leak, since an attacker
      // cannot reliably induce provider failure only for real accounts.
      throw new HttpsError(
        'unavailable',
        "We couldn't send your verification code right now. Please try again."
      );
    }

    const challengeId = await createEligibleChallenge(deps.db, {
      canonicalPhone,
      uid: resolution.uid,
      otpHash,
    });
    return { challengeId, message: GENERIC_MESSAGE };
  }

  // Ineligible — unknown phone, unmigrated-legacy account, or a
  // phone/email UID mismatch. All handled identically: no real OTP,
  // no SMS call, a calibrated delay, and a dead challenge with a
  // random, unusable hash so completePasswordReset's later behavior is
  // indistinguishable from a real wrong-OTP case.
  await sleep(INELIGIBLE_PATH_DELAY_MS);
  const unusableOtpHash = hmacSha256Hex(
    generateSixDigitOtp() + generateSixDigitOtp(),
    deps.otpPepper
  );
  const challengeId = await createDeadChallenge(deps.db, {
    canonicalPhone,
    unusableOtpHash,
  });
  return { challengeId, message: GENERIC_MESSAGE };
}

/** Production callable wrapper. App Check enforcement is configured
 * HERE (`enforceAppCheck: true`) — this is the actual, deployed
 * enforcement point; it is never disabled to make tests pass (tests
 * call `handleRequestPasswordReset` directly instead — see above). */
export const requestPasswordReset = onCall(
  {
    // Made explicit (not a behavior change — this is the 2nd-gen
    // default) so the Flutter client has one unambiguous region to pin
    // against instead of relying on an implicit default that could
    // silently change.
    region: 'us-central1',
    secrets: [
      OTP_HMAC_PEPPER,
      SMS_PROVIDER_ACCOUNT_SID,
      SMS_PROVIDER_AUTH_TOKEN,
      SMS_PROVIDER_FROM_NUMBER,
    ],
    enforceAppCheck: true,
  },
  async (request) => {
    // Lazy imports so this module can be loaded by tests without
    // requiring a live Admin app / real secret values.
    const { getFirestore } = await import('firebase-admin/firestore');
    const { getAuth } = await import('firebase-admin/auth');

    // Only ever true when FUNCTIONS_EMULATOR=true, which the real
    // Functions Emulator sets on this process and a deployed function
    // never has — see emulatorEnv.ts. This swap never runs in
    // production; a deployed function always uses TwilioSmsProvider.
    const smsProvider: SmsProvider = isFunctionsEmulator()
      ? new EmulatorFileSmsProvider()
      : new TwilioSmsProvider(
          SMS_PROVIDER_ACCOUNT_SID.value(),
          SMS_PROVIDER_AUTH_TOKEN.value(),
          SMS_PROVIDER_FROM_NUMBER.value()
        );

    const deps: RequestPasswordResetDeps = {
      db: getFirestore(),
      auth: getAuth(),
      smsProvider,
      otpPepper: OTP_HMAC_PEPPER.value(),
    };
    return handleRequestPasswordReset(
      request.data as RequestPasswordResetInput,
      deps
    );
  }
);
