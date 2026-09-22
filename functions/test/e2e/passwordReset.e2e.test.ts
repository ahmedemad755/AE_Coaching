/**
 * PHASE 5B STAGE 3 — CALLABLE END-TO-END TESTS.
 *
 * Unlike test/emulator/passwordReset.emulator.test.ts (which calls
 * `handleRequestPasswordReset`/`handleCompletePasswordReset` directly,
 * in-process), every test here goes through the REAL wire protocol:
 *
 *   this test process --HTTP--> Functions Emulator (separate process)
 *     --admin SDK--> Auth Emulator / Firestore Emulator
 *
 * This is the only tier that actually proves: (a) the `main`/`outDir`
 * fix means the Functions Emulator loads these two callables at all,
 * (b) the onCall wrapper (region, App Check enforcement, secret
 * wiring) works end-to-end, not just the pure handler functions.
 *
 * SMS: the real onCall wrapper always uses EmulatorFileSmsProvider
 * instead of TwilioSmsProvider while FUNCTIONS_EMULATOR=true (see
 * requestPasswordReset.ts / emulatorEnv.ts) — no real SMS is ever sent,
 * and the OTP is recovered from that local file, never guessed.
 *
 * App Check: enforceAppCheck stays true on both functions, exactly as
 * configured for production. Requests here carry a syntactically-valid
 * but unsigned token; they succeed only because the Functions Emulator
 * itself sets FIREBASE_DEBUG_MODE / skipTokenVerification on the
 * function process — production verification is never weakened. See
 * callableClient.ts for the exact mechanism (verified by reading
 * firebase-tools/firebase-functions source, not assumed).
 */
import {
  clearAuthEmulator,
  countAuthUsers,
  createFixtureUser,
  resetEmulators,
  signInWithEmailPassword,
} from '../emulator/testHarness';
import { clearEmulatorSmsOutbox } from '../../src/emulatorSmsOutbox';
import { syntheticEmailFromCanonicalPhone } from '../../src/syntheticEmail';
import { callCallable } from './callableClient';
import { readLatestOtpForPhone } from './smsOutboxReader';

interface RequestPasswordResetResult {
  challengeId: string;
  message: string;
}

async function requestReset(phone: string) {
  return callCallable<RequestPasswordResetResult>('requestPasswordReset', { phone });
}

async function completeReset(challengeId: string, otp: string, newPassword: string) {
  return callCallable<{ success: true }>('completePasswordReset', {
    challengeId,
    otp,
    newPassword,
  });
}

describe('Phase 5B password reset — callable Functions Emulator E2E', () => {
  beforeEach(async () => {
    await resetEmulators();
    clearEmulatorSmsOutbox();
  });

  test('A: eligible existing (Phase-3-like) user — full HTTP round trip, same UID, old password rejected, new password works', async () => {
    const phone = '+201011112221';
    const email = syntheticEmailFromCanonicalPhone(phone);
    await createFixtureUser({ uid: 'e2e-a-uid', phoneNumber: phone, email, password: 'oldpass123' });

    const before = await countAuthUsers();

    const reqRes = await requestReset(phone);
    expect(reqRes.httpStatus).toBe(200);
    expect(reqRes.result?.challengeId).toBeTruthy();

    const otp = readLatestOtpForPhone(phone);
    expect(otp).not.toBeNull();

    const completeRes = await completeReset(reqRes.result!.challengeId, otp as string, 'newpass456');
    expect(completeRes.httpStatus).toBe(200);
    expect(completeRes.result?.success).toBe(true);

    const after = await countAuthUsers();
    expect(after).toBe(before); // no new/deleted Auth user

    const oldSignIn = await signInWithEmailPassword(email, 'oldpass123');
    expect(oldSignIn).toBeNull();

    const newSignIn = await signInWithEmailPassword(email, 'newpass456');
    expect(newSignIn).toBe('e2e-a-uid'); // same UID preserved
  });

  test('B: unknown phone — generic safe response, ZERO new Firebase Auth users', async () => {
    const phone = '+201211112224';
    const before = await countAuthUsers();

    const reqRes = await requestReset(phone);
    expect(reqRes.httpStatus).toBe(200);
    expect(reqRes.result?.challengeId).toBeTruthy();
    expect(reqRes.result?.message).toBe(
      "If an eligible account exists for this number, we've sent a verification code."
    );

    // No SMS actually sent for an unknown phone.
    expect(readLatestOtpForPhone(phone)).toBeNull();

    const after = await countAuthUsers();
    expect(after).toBe(before);
  });

  test('C: legacy password-only account (synthetic email exists, no phone provider) — ZERO new Firebase Auth users', async () => {
    const phone = '+201511112225';
    const email = syntheticEmailFromCanonicalPhone(phone);
    // No phoneNumber on this fixture — mirrors an unmigrated legacy user.
    await createFixtureUser({ uid: 'e2e-c-uid', email, password: 'legacypass1' });

    const before = await countAuthUsers();
    const reqRes = await requestReset(phone);
    expect(reqRes.httpStatus).toBe(200);
    expect(readLatestOtpForPhone(phone)).toBeNull(); // ineligible path, no real OTP sent

    const after = await countAuthUsers();
    expect(after).toBe(before);

    // Legacy password must still work — nothing touched it.
    const stillWorks = await signInWithEmailPassword(email, 'legacypass1');
    expect(stillWorks).toBe('e2e-c-uid');
  });

  test('D: phone/email resolve to DIFFERENT uids — ZERO new Firebase Auth users, ZERO deleted, neither account touched', async () => {
    const phone = '+201099998889';
    const email = syntheticEmailFromCanonicalPhone(phone);
    await createFixtureUser({ uid: 'e2e-d-phone-uid', phoneNumber: phone, password: 'phoneacct1' });
    await createFixtureUser({ uid: 'e2e-d-email-uid', email, password: 'emailacct1' });

    const before = await countAuthUsers();
    const reqRes = await requestReset(phone);
    expect(reqRes.httpStatus).toBe(200);
    expect(readLatestOtpForPhone(phone)).toBeNull();

    const after = await countAuthUsers();
    expect(after).toBe(before); // no create, no delete

    // Both original accounts remain exactly as they were.
    expect(await signInWithEmailPassword(email, 'emailacct1')).toBe('e2e-d-email-uid');
  });

  test('E: wrong OTP is rejected over the real HTTP path — password unchanged, no Auth user created', async () => {
    const phone = '+201099998881';
    const email = syntheticEmailFromCanonicalPhone(phone);
    await createFixtureUser({ uid: 'e2e-e-uid', phoneNumber: phone, email, password: 'staysthesame1' });

    const before = await countAuthUsers();
    const reqRes = await requestReset(phone);
    const challengeId = reqRes.result!.challengeId;

    const completeRes = await completeReset(challengeId, '000000', 'attackerpass1');
    expect(completeRes.httpStatus).not.toBe(200);
    expect(completeRes.error?.message).toBe(
      'This code is invalid or has expired. Please request a new one.'
    );

    const after = await countAuthUsers();
    expect(after).toBe(before);

    expect(await signInWithEmailPassword(email, 'staysthesame1')).toBe('e2e-e-uid');
    expect(await signInWithEmailPassword(email, 'attackerpass1')).toBeNull();
  });

  test('F: replaying a completed challenge with the SAME otp/password is idempotent — no double side effect, still exactly one matching Auth user', async () => {
    const phone = '+201099998882';
    const email = syntheticEmailFromCanonicalPhone(phone);
    await createFixtureUser({ uid: 'e2e-f-uid', phoneNumber: phone, email, password: 'original1' });

    const reqRes = await requestReset(phone);
    const challengeId = reqRes.result!.challengeId;
    const otp = readLatestOtpForPhone(phone) as string;

    const first = await completeReset(challengeId, otp, 'replayedpass1');
    expect(first.httpStatus).toBe(200);
    expect(first.result?.success).toBe(true);

    const before = await countAuthUsers();
    const second = await completeReset(challengeId, otp, 'replayedpass1');
    expect(second.httpStatus).toBe(200);
    expect(second.result?.success).toBe(true); // idempotent success, not an error
    const after = await countAuthUsers();
    expect(after).toBe(before); // no second account created by the replay

    expect(await signInWithEmailPassword(email, 'replayedpass1')).toBe('e2e-f-uid');
  });
});

afterAll(async () => {
  await clearAuthEmulator();
});
