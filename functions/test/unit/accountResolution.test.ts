import type { Auth, UserRecord } from 'firebase-admin/auth';
import { resolveExistingAccount } from '../../src/accountResolution';

/** UNIT-TEST TIER: this mocks the Admin SDK `Auth` surface directly —
 * no real Firebase project, no emulator, is involved. It proves
 * `resolveExistingAccount`'s own decision logic, not real Firebase
 * Auth lookup behavior end-to-end (that's covered by the emulator
 * tests in test/emulator/, which exercise this same function against
 * the real Auth Emulator with genuinely created test users). */

function notFoundError(): Error {
  const err = new Error('no user record') as Error & { code: string };
  err.code = 'auth/user-not-found';
  return err;
}

function makeAuth(overrides: {
  phoneUser?: Pick<UserRecord, 'uid'>;
  emailUser?: Pick<UserRecord, 'uid'>;
}): Auth {
  return {
    getUserByPhoneNumber: jest.fn(async () => {
      if (overrides.phoneUser) return overrides.phoneUser as UserRecord;
      throw notFoundError();
    }),
    getUserByEmail: jest.fn(async () => {
      if (overrides.emailUser) return overrides.emailUser as UserRecord;
      throw notFoundError();
    }),
  } as unknown as Auth;
}

describe('resolveExistingAccount', () => {
  test('eligible when phone and synthetic-email lookups resolve to the '
    + 'same uid (Phase 3 / Phase 4-migrated shape)', async () => {
    const auth = makeAuth({ phoneUser: { uid: 'UID_A' }, emailUser: { uid: 'UID_A' } });
    const result = await resolveExistingAccount(auth, '+201012345678');
    expect(result).toEqual({ eligible: true, uid: 'UID_A' });
  });

  test('ineligible for an unknown phone (no phone-provider user at all)', async () => {
    const auth = makeAuth({ emailUser: { uid: 'UID_A' } });
    const result = await resolveExistingAccount(auth, '+201099999999');
    expect(result).toEqual({ eligible: false, uid: null });
  });

  test('ineligible for an unmigrated legacy password-only account '
    + '(synthetic email exists, but no phone provider linked)', async () => {
    const auth = makeAuth({ emailUser: { uid: 'LEGACY_UID' } });
    const result = await resolveExistingAccount(auth, '+201012345678');
    expect(result).toEqual({ eligible: false, uid: null });
  });

  test('ineligible when phone and email resolve to DIFFERENT uids — '
    + 'never returns either uid, never merges', async () => {
    const auth = makeAuth({ phoneUser: { uid: 'PHONE_UID' }, emailUser: { uid: 'OTHER_UID' } });
    const result = await resolveExistingAccount(auth, '+201012345678');
    expect(result).toEqual({ eligible: false, uid: null });
  });

  test('ineligible when neither lookup finds anything', async () => {
    const auth = makeAuth({});
    const result = await resolveExistingAccount(auth, '+201000000000');
    expect(result).toEqual({ eligible: false, uid: null });
  });

  test('propagates a non-"user-not-found" error instead of silently '
    + 'treating it as ineligible', async () => {
    const auth = {
      getUserByPhoneNumber: jest.fn(async () => {
        throw new Error('some other transient error');
      }),
      getUserByEmail: jest.fn(async () => {
        throw notFoundError();
      }),
    } as unknown as Auth;
    await expect(resolveExistingAccount(auth, '+201012345678')).rejects.toThrow(
      'some other transient error'
    );
  });
});
