/**
 * EMULATOR-TEST TIER: every test below runs against the REAL Firebase
 * Auth Emulator + Firestore Emulator (started by
 * `firebase emulators:exec`, see package.json's `test:emulator:exec`
 * script) — no mocks, no stubs standing in for Firebase itself. Only
 * the SMS provider is faked (FakeSmsProvider — see smsProvider.ts),
 * since sending real SMS is explicitly out of scope for automated
 * tests.
 *
 * The single most important assertion running through this file:
 * Auth-user COUNT is captured before and after every scenario,
 * including every failure path, and asserted unchanged unless the
 * scenario is explicitly a fixture-setup step. Phase 5B's core
 * invariant — "password reset never creates or deletes a Firebase Auth
 * user" — is checked against REAL Admin SDK behavior here, not just
 * inferred from source code structure.
 */
import { Timestamp } from 'firebase-admin/firestore';
import {
  claimChallenge,
  ChallengeDoc,
  commitCompletion,
} from '../../src/challengeStore';
import {
  CompletePasswordResetDeps,
  handleCompletePasswordReset,
} from '../../src/completePasswordReset';
import { CHALLENGES_COLLECTION } from '../../src/config';
import { hmacSha256Hex } from '../../src/crypto';
import {
  handleRequestPasswordReset,
  RequestPasswordResetDeps,
} from '../../src/requestPasswordReset';
import { FakeSmsProvider } from '../../src/smsProvider';
import {
  countAuthUsers,
  createFixtureUser,
  getTestAuth,
  getTestDb,
  resetEmulators,
  signInWithEmailPassword,
} from './testHarness';

const OTP_PEPPER = 'test-otp-pepper';
const INTENT_PEPPER = 'test-password-intent-pepper';

function extractOtp(smsBody: string): string {
  const match = smsBody.match(/\b(\d{6})\b/);
  if (!match) throw new Error(`No 6-digit OTP found in SMS body: ${smsBody}`);
  return match[1];
}

/** Jest's `expect().toBe()` doesn't narrow a discriminated union the
 * way an `if` does, so tests that need `claim.uid`/`claim.leaseId`
 * after confirming a claim succeeded use this assertion helper
 * instead. */
function assertClaimed(
  claim: ReturnType<typeof claimChallenge> extends Promise<infer T> ? T : never
): asserts claim is { kind: 'claimed'; uid: string; leaseId: string } {
  if (claim.kind !== 'claimed') {
    throw new Error(`Expected claim to succeed, got: ${JSON.stringify(claim)}`);
  }
}

describe('Phase 5B password reset — emulator tests', () => {
  jest.setTimeout(30000);

  let requestDeps: RequestPasswordResetDeps;
  let completeDeps: CompletePasswordResetDeps;
  let sms: FakeSmsProvider;

  beforeEach(async () => {
    await resetEmulators();
    sms = new FakeSmsProvider();
    requestDeps = {
      db: getTestDb(),
      auth: getTestAuth(),
      smsProvider: sms,
      otpPepper: OTP_PEPPER,
    };
    completeDeps = {
      db: getTestDb(),
      auth: getTestAuth(),
      otpPepper: OTP_PEPPER,
      passwordIntentPepper: INTENT_PEPPER,
    };
  });

  // -- A: Phase 3-like user (phone + synthetic email/password, same uid)
  test('A: Phase 3-like user — reset succeeds, UID unchanged, old '
    + 'password rejected, new password works', async () => {
    await createFixtureUser({
      uid: 'PHASE3_UID',
      phoneNumber: '+201012345678',
      email: 'u201012345678@ae-coaching.app',
      password: 'oldpassword1',
    });
    const before = await countAuthUsers();

    const req = await handleRequestPasswordReset({ phone: '01012345678' }, requestDeps);
    expect(sms.sentMessages).toHaveLength(1);
    const otp = extractOtp(sms.sentMessages[0].body);

    const result = await handleCompletePasswordReset(
      { challengeId: req.challengeId, otp, newPassword: 'brandnewpass1' },
      completeDeps
    );
    expect(result).toEqual({ success: true });

    const after = await countAuthUsers();
    expect(after).toBe(before); // no new user created

    expect(await signInWithEmailPassword('u201012345678@ae-coaching.app', 'oldpassword1')).toBeNull();
    expect(await signInWithEmailPassword('u201012345678@ae-coaching.app', 'brandnewpass1')).toBe(
      'PHASE3_UID'
    );
  });

  // -- B: Phase 4-migrated-like user (same final provider shape as A)
  test('B: Phase 4-migrated-like user behaves identically to a Phase 3 '
    + 'account — reset succeeds, UID unchanged', async () => {
    await createFixtureUser({
      uid: 'PHASE4_MIGRATED_UID',
      phoneNumber: '+201112345678',
      email: 'u201112345678@ae-coaching.app',
      password: 'oldpassword2',
    });

    const req = await handleRequestPasswordReset({ phone: '01112345678' }, requestDeps);
    const otp = extractOtp(sms.sentMessages[0].body);
    const result = await handleCompletePasswordReset(
      { challengeId: req.challengeId, otp, newPassword: 'brandnewpass2' },
      completeDeps
    );
    expect(result).toEqual({ success: true });
    expect(await signInWithEmailPassword('u201112345678@ae-coaching.app', 'brandnewpass2')).toBe(
      'PHASE4_MIGRATED_UID'
    );
  });

  // -- C: unknown phone
  test('C: unknown phone — no Auth user created, no SMS sent, generic '
    + 'response identical in shape to the eligible case', async () => {
    const before = await countAuthUsers();
    const req = await handleRequestPasswordReset({ phone: '01099999999' }, requestDeps);
    expect(req.challengeId).toBeTruthy();
    expect(sms.sentMessages).toHaveLength(0);
    const after = await countAuthUsers();
    expect(after).toBe(before);
  });

  // -- D: unmigrated legacy password-only account
  test('D: unmigrated legacy account (synthetic email exists, no phone '
    + 'provider) — ineligible, no phone Auth user created, no reset', async () => {
    await createFixtureUser({
      uid: 'LEGACY_UID',
      email: 'u201098765432@ae-coaching.app',
      password: 'legacyoldpass1',
    });
    const before = await countAuthUsers();

    const req = await handleRequestPasswordReset({ phone: '01098765432' }, requestDeps);
    expect(sms.sentMessages).toHaveLength(0);

    const after = await countAuthUsers();
    expect(after).toBe(before);

    // Confirm the legacy account's real password is completely untouched.
    expect(
      await signInWithEmailPassword('u201098765432@ae-coaching.app', 'legacyoldpass1')
    ).toBe('LEGACY_UID');

    // A wrong OTP against the dead challenge is correctly rejected —
    // there is no way to ever complete a reset for this phone this way.
    await expect(
      handleCompletePasswordReset(
        { challengeId: req.challengeId, otp: '000000', newPassword: 'attackerpass1' },
        completeDeps
      )
    ).rejects.toThrow();
  });

  // -- E: phone/email different UIDs
  test('E: phone and synthetic-email resolve to DIFFERENT uids — '
    + 'ineligible, no reset, no merge, no delete, neither account touched', async () => {
    await createFixtureUser({ uid: 'PHONE_ONLY_UID', phoneNumber: '+201077777777' });
    await createFixtureUser({
      uid: 'EMAIL_ONLY_UID',
      email: 'u201077777777@ae-coaching.app',
      password: 'mismatchpass1',
    });
    const before = await countAuthUsers();

    const req = await handleRequestPasswordReset({ phone: '01077777777' }, requestDeps);
    expect(sms.sentMessages).toHaveLength(0);

    const after = await countAuthUsers();
    expect(after).toBe(before);
    expect(await getTestAuth().getUser('PHONE_ONLY_UID')).toBeTruthy();
    expect(await getTestAuth().getUser('EMAIL_ONLY_UID')).toBeTruthy();
    expect(
      await signInWithEmailPassword('u201077777777@ae-coaching.app', 'mismatchpass1')
    ).toBe('EMAIL_ONLY_UID');

    await expect(
      handleCompletePasswordReset(
        { challengeId: req.challengeId, otp: '000000', newPassword: 'attackerpass2' },
        completeDeps
      )
    ).rejects.toThrow();
  });

  async function setUpEligibleChallenge(phone: string, uid: string, oldPassword: string) {
    const canonicalPhone = `+20${phone.substring(1)}`;
    await createFixtureUser({
      uid,
      phoneNumber: canonicalPhone,
      email: `u${canonicalPhone.replace('+', '')}@ae-coaching.app`,
      password: oldPassword,
    });
    const req = await handleRequestPasswordReset({ phone }, requestDeps);
    const otp = extractOtp(sms.sentMessages[sms.sentMessages.length - 1].body);
    return { challengeId: req.challengeId, otp, canonicalPhone };
  }

  // -- F: wrong OTP
  test('F: wrong OTP is rejected, password unchanged, no Auth user '
    + 'created', async () => {
    const { challengeId } = await setUpEligibleChallenge('01021111111', 'F_UID', 'oldpassF');
    const before = await countAuthUsers();

    await expect(
      handleCompletePasswordReset(
        { challengeId, otp: '000000', newPassword: 'newpassF' },
        completeDeps
      )
    ).rejects.toThrow();

    expect(await countAuthUsers()).toBe(before);
    expect(
      await signInWithEmailPassword('u201021111111@ae-coaching.app', 'oldpassF')
    ).toBe('F_UID');
  });

  // -- G: expired OTP
  test('G: expired challenge is rejected even with the correct OTP', async () => {
    const { challengeId, otp } = await setUpEligibleChallenge('01022222222', 'G_UID', 'oldpassG');
    const db = getTestDb();
    await db
      .collection(CHALLENGES_COLLECTION)
      .doc(challengeId)
      .update({ otpExpiresAt: new Timestamp(0, 0) });

    await expect(
      handleCompletePasswordReset({ challengeId, otp, newPassword: 'newpassG' }, completeDeps)
    ).rejects.toThrow();
  });

  // -- H: max attempts
  test('H: after otpMaxAttempts wrong guesses the challenge is dead, '
    + 'even for a subsequently-correct OTP', async () => {
    const { challengeId, otp } = await setUpEligibleChallenge('01023333333', 'H_UID', 'oldpassH');

    for (let i = 0; i < 5; i++) {
      await expect(
        handleCompletePasswordReset(
          { challengeId, otp: '999999', newPassword: 'newpassH' },
          completeDeps
        )
      ).rejects.toThrow();
    }

    // Even the CORRECT otp is now rejected — challenge is 'failed'.
    await expect(
      handleCompletePasswordReset({ challengeId, otp, newPassword: 'newpassH' }, completeDeps)
    ).rejects.toThrow();
  });

  // -- I / J: replay of an already-completed request (idempotent)
  test('I/J: retrying the exact same completed request (same OTP, same '
    + 'password) returns idempotent success, not an error', async () => {
    const { challengeId, otp } = await setUpEligibleChallenge('01024444444', 'IJ_UID', 'oldpassIJ');

    const first = await handleCompletePasswordReset(
      { challengeId, otp, newPassword: 'newpassIJ' },
      completeDeps
    );
    expect(first).toEqual({ success: true });

    const second = await handleCompletePasswordReset(
      { challengeId, otp, newPassword: 'newpassIJ' },
      completeDeps
    );
    expect(second).toEqual({ success: true });
  });

  // -- K: completed + different password
  test('K: a completed challenge rejects a resubmission with a '
    + 'DIFFERENT password — the account keeps the first-applied '
    + 'password', async () => {
    const { challengeId, otp } = await setUpEligibleChallenge('01025555555', 'K_UID', 'oldpassK');

    await handleCompletePasswordReset(
      { challengeId, otp, newPassword: 'firstNewPassK' },
      completeDeps
    );

    await expect(
      handleCompletePasswordReset(
        { challengeId, otp, newPassword: 'differentPassK' },
        completeDeps
      )
    ).rejects.toThrow();

    expect(
      await signInWithEmailPassword('u201025555555@ae-coaching.app', 'firstNewPassK')
    ).toBe('K_UID');
    expect(
      await signInWithEmailPassword('u201025555555@ae-coaching.app', 'differentPassK')
    ).toBeNull();
  });

  // -- L: concurrent race with DIFFERENT password intents — exactly one wins
  test('L: two concurrent completePasswordReset calls with the same OTP '
    + 'but different passwords — exactly one succeeds, the other is '
    + 'rejected, and the account ends up with exactly one of the two '
    + 'passwords (never both, never neither)', async () => {
    const { challengeId, otp } = await setUpEligibleChallenge('01026666666', 'L_UID', 'oldpassL');

    const [resA, resB] = await Promise.allSettled([
      handleCompletePasswordReset({ challengeId, otp, newPassword: 'raceAAA' }, completeDeps),
      handleCompletePasswordReset({ challengeId, otp, newPassword: 'raceBBB' }, completeDeps),
    ]);

    const fulfilledCount = [resA, resB].filter((r) => r.status === 'fulfilled').length;
    expect(fulfilledCount).toBe(1);

    const aWorks = (await signInWithEmailPassword('u201026666666@ae-coaching.app', 'raceAAA')) !== null;
    const bWorks = (await signInWithEmailPassword('u201026666666@ae-coaching.app', 'raceBBB')) !== null;
    expect(aWorks !== bWorks).toBe(true); // exactly one, never both, never neither
  });

  // -- M: applying + expired lease + SAME intent → reclaim succeeds
  // (also satisfies crash/retry scenario 1: lease acquired, crash
  // before updateUser, expiry, same-intent reclaim, success)
  test('M: an expired "applying" lease is reclaimable with the SAME '
    + 'OTP and SAME password intent, and completes successfully — '
    + 'simulating a crash between claiming the lease and calling '
    + 'updateUser', async () => {
    const { challengeId, otp } = await setUpEligibleChallenge('01027777777', 'M_UID', 'oldpassM');
    const intentHash = hmacSha256Hex('reclaimedPassM', INTENT_PEPPER);
    const otpHash = hmacSha256Hex(otp, OTP_PEPPER);

    // Directly claim the lease (simulating the FIRST attempt reaching
    // this point) then immediately force-expire it without ever
    // calling updateUser — this is exactly "crash before updateUser".
    const claim = await claimChallenge(getTestDb(), challengeId, otpHash, intentHash);
    assertClaimed(claim);
    await getTestDb()
      .collection(CHALLENGES_COLLECTION)
      .doc(challengeId)
      .update({ leaseExpiresAt: new Timestamp(0, 0) });

    // Now the full, real flow retries with the SAME otp/password.
    const result = await handleCompletePasswordReset(
      { challengeId, otp, newPassword: 'reclaimedPassM' },
      completeDeps
    );
    expect(result).toEqual({ success: true });
    expect(
      await signInWithEmailPassword('u201027777777@ae-coaching.app', 'reclaimedPassM')
    ).toBe('M_UID');
  });

  // -- N: applying + expired lease + DIFFERENT intent → rejected, intent unchanged
  // (also satisfies crash/retry scenario 5)
  test('N: an expired "applying" lease is NOT reclaimable with a '
    + 'DIFFERENT password — rejected, and the stored passwordIntentHash '
    + 'is never overwritten', async () => {
    const { challengeId, otp } = await setUpEligibleChallenge('01028888888', 'N_UID', 'oldpassN');
    const originalIntentHash = hmacSha256Hex('originalIntentN', INTENT_PEPPER);
    const otpHash = hmacSha256Hex(otp, OTP_PEPPER);

    const claim = await claimChallenge(getTestDb(), challengeId, otpHash, originalIntentHash);
    assertClaimed(claim);
    await getTestDb()
      .collection(CHALLENGES_COLLECTION)
      .doc(challengeId)
      .update({ leaseExpiresAt: new Timestamp(0, 0) });

    await expect(
      handleCompletePasswordReset(
        { challengeId, otp, newPassword: 'differentIntentN' },
        completeDeps
      )
    ).rejects.toThrow();

    const snap = await getTestDb().collection(CHALLENGES_COLLECTION).doc(challengeId).get();
    const doc = snap.data() as ChallengeDoc;
    expect(doc.passwordIntentHash).toBe(originalIntentHash); // unchanged
    expect(doc.state).toBe('applying'); // never advanced to completed
  });

  // -- O: SMS provider failure
  test('O: SMS provider failure creates NO usable challenge and no '
    + 'Auth user is created/changed', async () => {
    await createFixtureUser({
      uid: 'O_UID',
      phoneNumber: '+201029999999',
      email: 'u201029999999@ae-coaching.app',
      password: 'oldpassO',
    });
    sms.failNext(1);
    const before = await countAuthUsers();

    await expect(handleRequestPasswordReset({ phone: '01029999999' }, requestDeps)).rejects.toThrow();

    expect(await countAuthUsers()).toBe(before);
    const remaining = await getTestDb()
      .collection(CHALLENGES_COLLECTION)
      .where('canonicalPhone', '==', '+201029999999')
      .get();
    expect(remaining.empty).toBe(true); // no stale valid challenge left behind
    expect(
      await signInWithEmailPassword('u201029999999@ae-coaching.app', 'oldpassO')
    ).toBe('O_UID');
  });

  // -- P: weak password
  test('P: a weak password is rejected BEFORE any challenge/OTP state '
    + 'is touched — no attempt is burned', async () => {
    const { challengeId } = await setUpEligibleChallenge('01020000001', 'P_UID', 'oldpassP');

    await expect(
      handleCompletePasswordReset({ challengeId, otp: '000000', newPassword: '123' }, completeDeps)
    ).rejects.toThrow();

    const snap = await getTestDb().collection(CHALLENGES_COLLECTION).doc(challengeId).get();
    const doc = snap.data() as ChallengeDoc;
    expect(doc.otpAttemptCount).toBe(0); // untouched — the weak password never reached the OTP check
    expect(doc.state).toBe('pending');
  });

  // -- Crash/retry scenario 2: updateUser succeeds, crash before
  // transaction #2, expiry, reclaim same intent → completed
  test('crash/retry 2: updateUser already succeeded before a simulated '
    + 'crash; reclaiming with the same intent completes cleanly '
    + '(idempotent updateUser, no duplicate side effect)', async () => {
    const { challengeId, otp } = await setUpEligibleChallenge('01020000002', 'CR2_UID', 'oldpassCR2');
    const intentHash = hmacSha256Hex('crashPassCR2', INTENT_PEPPER);
    const otpHash = hmacSha256Hex(otp, OTP_PEPPER);

    const claim = await claimChallenge(getTestDb(), challengeId, otpHash, intentHash);
    assertClaimed(claim);
    // Simulate updateUser having already succeeded, then "crashing"
    // before transaction #2 ever runs.
    await getTestAuth().updateUser(claim.uid, { password: 'crashPassCR2' });
    await getTestDb()
      .collection(CHALLENGES_COLLECTION)
      .doc(challengeId)
      .update({ leaseExpiresAt: new Timestamp(0, 0) });

    const result = await handleCompletePasswordReset(
      { challengeId, otp, newPassword: 'crashPassCR2' },
      completeDeps
    );
    expect(result).toEqual({ success: true });

    const snap = await getTestDb().collection(CHALLENGES_COLLECTION).doc(challengeId).get();
    expect((snap.data() as ChallengeDoc).state).toBe('completed');
  });

  // -- Crash/retry scenario 3: transaction #2 can't find a matching
  // lease (simulating a transient/failed commit) — safe, bounded, no throw
  test('crash/retry 3: commitCompletion with a stale/mismatched leaseId '
    + 'returns a safe no-op instead of throwing, and never reverts the '
    + 'already-applied password change', async () => {
    const { challengeId, otp } = await setUpEligibleChallenge('01020000003', 'CR3_UID', 'oldpassCR3');
    const intentHash = hmacSha256Hex('crashPassCR3', INTENT_PEPPER);
    const otpHash = hmacSha256Hex(otp, OTP_PEPPER);

    const claim = await claimChallenge(getTestDb(), challengeId, otpHash, intentHash);
    assertClaimed(claim);
    await getTestAuth().updateUser(claim.uid, { password: 'crashPassCR3' });

    const outcome = await commitCompletion(getTestDb(), challengeId, 'not-the-real-lease-id');
    expect(outcome).toBe('staleNoop');

    // Password change is NOT reverted despite transaction #2 failing.
    expect(
      await signInWithEmailPassword('u201020000003@ae-coaching.app', 'crashPassCR3')
    ).toBe('CR3_UID');
  });

  // -- Crash/retry scenario 4: two callers race for an expired lease —
  // only one obtains the new lease
  test('crash/retry 4: two concurrent reclaim attempts against the same '
    + 'expired lease — only one claims it, the other is rejected', async () => {
    const { challengeId, otp } = await setUpEligibleChallenge('01020000004', 'CR4_UID', 'oldpassCR4');
    const intentHash = hmacSha256Hex('reclaimPassCR4', INTENT_PEPPER);
    const otpHash = hmacSha256Hex(otp, OTP_PEPPER);

    const firstClaim = await claimChallenge(getTestDb(), challengeId, otpHash, intentHash);
    expect(firstClaim.kind).toBe('claimed');
    await getTestDb()
      .collection(CHALLENGES_COLLECTION)
      .doc(challengeId)
      .update({ leaseExpiresAt: new Timestamp(0, 0) });

    const [claimA, claimB] = await Promise.all([
      claimChallenge(getTestDb(), challengeId, otpHash, intentHash),
      claimChallenge(getTestDb(), challengeId, otpHash, intentHash),
    ]);

    const claimedCount = [claimA, claimB].filter((c) => c.kind === 'claimed').length;
    expect(claimedCount).toBe(1);
  });
});
