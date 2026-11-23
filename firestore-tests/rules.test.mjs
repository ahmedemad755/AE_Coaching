// Emulator-only security tests for ../firestore.rules.
// Run from this folder:  npm test
// The project id is demo-ae-coaching. Firebase "demo-" projects can only
// ever talk to the local emulator, never to a real project.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  deleteField,
  disableNetwork,
  doc,
  enableNetwork,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

let env;

const ALICE = { uid: 'alice', email: 'alice@example.com' };
const BOB = { uid: 'bob', email: 'bob@example.com' };

/** Firestore client for a signed-in user with the given token claims. */
function db(user, { verified = true, email = user.email } = {}) {
  const claims = { email_verified: verified };
  if (email !== null) claims.email = email;
  return env.authenticatedContext(user.uid, claims).firestore();
}
const anon = () => env.unauthenticatedContext().firestore();

async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}
/** Every signed-in app user has a profile: the app confirms (or recovers)
 *  it at each sign-in and app start. Creating documents requires it
 *  (firestore.rules: canCreateIn). */
async function seedProfiles() {
  for (const user of [ALICE, BOB]) {
    await seed(`users/${user.uid}`, {
      uid: user.uid, name: 'Test', email: user.email,
      createdAt: Timestamp.fromMillis(1), updatedAt: Timestamp.fromMillis(1),
    });
  }
}

async function readRaw(path) {
  let data;
  await env.withSecurityRulesDisabled(async (ctx) => {
    data = (await getDoc(doc(ctx.firestore(), path))).data();
  });
  return data;
}

/** Exactly what FirestoreUserProfileStore writes for a missing profile. */
const newProfile = (user, extra = {}) => ({
  uid: user.uid,
  name: 'Ahmed Emad',
  email: user.email,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...extra,
});

// Documents shaped exactly like each model's toJson().
const SAMPLES = {
  exercise_sets: {
    exerciseName: 'Bench Press', weight: 80.5, reps: 8,
    date: '2026-11-07T10:00:00.000', notes: null, programId: 'p1',
    workoutTemplateId: 't1', workoutSessionId: null,
  },
  body_measurements: {
    date: '2026-11-07T10:00:00.000', chest: 100.0, waist: 80, hips: null,
    rightArm: null, leftArm: null, rightThigh: null, leftThigh: null,
    rightCalf: null, leftCalf: null, shoulders: 120.5, neck: null,
  },
  workout_programs: {
    id: 'program_1', name: 'Push Pull Legs', description: null,
    createdAt: '2026-11-07T10:00:00.000', startedAt: null, endedAt: null,
    isActive: true,
  },
  workout_templates: {
    id: 'template_1', programId: 'program_1', name: 'Push Day',
    createdAt: '2026-11-07T10:00:00.000', updatedAt: null,
    isArchived: false, orderIndex: 0,
  },
  workout_sessions: {
    id: 'session_1', programId: 'program_1', workoutTemplateId: 'template_1',
    workoutNameSnapshot: 'Push Day', date: '2026-11-07T10:00:00.000',
    startedAt: '2026-11-07T10:00:00.000', completedAt: null,
    status: 'active', totalVolume: 0.0, previousSessionId: null,
    workoutNote: null,
  },
};
// The field each collection's app query orders by.
const ORDER_FIELD = {
  exercise_sets: 'date', body_measurements: 'date',
  workout_programs: 'createdAt', workout_templates: 'createdAt',
  workout_sessions: 'date',
};
// One required field per collection, and one wrong-typed value.
const REQUIRED = {
  exercise_sets: ['reps', '8'], body_measurements: ['date', 20261107],
  workout_programs: ['isActive', 'yes'], workout_templates: ['isArchived', 0],
  workout_sessions: ['totalVolume', '0'],
};

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ae-coaching',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});
beforeEach(async () => env.clearFirestore());
after(async () => env.cleanup());

// ─────────────────────────────────────────────────────────────────────────
describe('Authentication and ownership', () => {
  it('unauthenticated clients can do nothing', async () => {
    await seed('users/alice', { uid: 'alice', name: 'Alice' });
    await assertFails(getDoc(doc(anon(), 'users/alice')));
    await assertFails(setDoc(doc(anon(), 'users/alice'), newProfile(ALICE)));
    for (const c of Object.keys(SAMPLES)) {
      await assertFails(getDoc(doc(anon(), `users/alice/${c}/x`)));
      await assertFails(setDoc(doc(anon(), `users/alice/${c}/x`), SAMPLES[c]));
      await assertFails(getDocs(collection(anon(), `users/alice/${c}`)));
    }
  });

  it("a user cannot read or modify another user's profile", async () => {
    await seed('users/bob', { uid: 'bob', name: 'Bob', email: BOB.email });
    await assertFails(getDoc(doc(db(ALICE), 'users/bob')));
    await assertFails(setDoc(doc(db(ALICE), 'users/bob'), newProfile(BOB)));
    await assertFails(updateDoc(doc(db(ALICE), 'users/bob'), {
      name: 'Hacked', updatedAt: serverTimestamp(),
    }));
    await assertFails(deleteDoc(doc(db(ALICE), 'users/bob')));
  });

  it('profiles cannot be listed (no user enumeration)', async () => {
    await seed('users/alice', { uid: 'alice', name: 'Alice' });
    await assertFails(getDocs(collection(db(ALICE), 'users')));
  });
});

// ─────────────────────────────────────────────────────────────────────────
describe('Registration and onboarding profile (before verification)', () => {
  const unverified = () => db(ALICE, { verified: false });

  it('an unverified user can create their own valid profile', async () => {
    await assertSucceeds(setDoc(doc(unverified(), 'users/alice'), newProfile(ALICE)));
  });

  it('the exact registration transaction (read, then create) succeeds',
    async () => {
      const f = unverified();
      await assertSucceeds(runTransaction(f, async (tx) => {
        const ref = doc(f, 'users/alice');
        const snap = await tx.get(ref);
        if (!snap.exists()) tx.set(ref, newProfile(ALICE));
      }));
    });

  it('an unverified user can read their own profile', async () => {
    await seed('users/alice', { uid: 'alice', name: 'Alice' });
    await assertSucceeds(getDoc(doc(unverified(), 'users/alice')));
  });

  it('ownership: uid must match the path and the caller', async () => {
    await assertFails(setDoc(doc(unverified(), 'users/alice'),
      newProfile(ALICE, { uid: 'bob' })));
    await assertFails(setDoc(doc(unverified(), 'users/bob'), newProfile(BOB)));
  });

  it('required fields, no extras, server timestamps only', async () => {
    const ref = doc(unverified(), 'users/alice');
    const { email, ...noEmail } = newProfile(ALICE);
    await assertFails(setDoc(ref, noEmail));
    await assertFails(setDoc(ref, newProfile(ALICE, { role: 'admin' })));
    await assertFails(setDoc(ref, newProfile(ALICE, { emailVerified: true })));
    await assertFails(setDoc(ref, newProfile(ALICE, {
      createdAt: Timestamp.fromDate(new Date('2020-01-01')),
    })));
    await assertFails(setDoc(ref, newProfile(ALICE, { updatedAt: 'now' })));
  });

  it('names follow the app rule (letters required, ≤60, trimmed); Arabic '
    + 'and single-letter names are fine', async () => {
    const ref = doc(unverified(), 'users/alice');
    for (const bad of ['', '   ', '12345', ' Ahmed', 'a'.repeat(61), 42]) {
      await assertFails(setDoc(ref, newProfile(ALICE, { name: bad })));
    }
    await assertSucceeds(setDoc(ref, newProfile(ALICE, { name: 'أحمد عماد' })));
    await env.clearFirestore();
    await assertSucceeds(setDoc(ref, newProfile(ALICE, { name: 'A' })));
  });

  it("the profile email must be the caller's own (token) email", async () => {
    await assertFails(setDoc(doc(unverified(), 'users/alice'),
      newProfile(ALICE, { email: 'someone@else.com' })));
    // The app lower-cases emails; the token may carry the original case.
    const mixedCase = db(ALICE, { verified: false, email: 'Alice@Example.com' });
    await assertSucceeds(setDoc(doc(mixedCase, 'users/alice'), newProfile(ALICE)));
  });

  it('an unverified user cannot update or delete a profile', async () => {
    await seed('users/alice', {
      uid: 'alice', name: '', email: ALICE.email, createdAt: Timestamp.now(),
    });
    await assertFails(updateDoc(doc(unverified(), 'users/alice'), {
      name: 'Ahmed', updatedAt: serverTimestamp(),
    }));
    await assertFails(deleteDoc(doc(unverified(), 'users/alice')));
  });
});

// ─────────────────────────────────────────────────────────────────────────
describe('Profile recovery and updates (verified)', () => {
  const T0 = Timestamp.fromDate(new Date('2026-01-01T00:00:00Z'));

  it('repairing a blank name keeps createdAt and every other field',
    async () => {
      await seed('users/alice', {
        uid: 'alice', name: '', email: ALICE.email, createdAt: T0, custom: 'kept',
      });
      await assertSucceeds(updateDoc(doc(db(ALICE), 'users/alice'), {
        name: 'Ahmed Emad', updatedAt: serverTimestamp(),
      }));
      const after = await readRaw('users/alice');
      assert(after.createdAt.isEqual(T0), 'createdAt preserved');
      assert(after.custom === 'kept', 'unrelated field preserved');
    });

  it('repair may fill a missing uid and createdAt (once, server time)',
    async () => {
      await seed('users/alice', { name: 'Ahmed' });
      await assertSucceeds(updateDoc(doc(db(ALICE), 'users/alice'), {
        uid: 'alice', email: ALICE.email,
        createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      }));
    });

  it('an existing createdAt can never be changed', async () => {
    await seed('users/alice', { uid: 'alice', name: 'Ahmed', createdAt: T0 });
    await assertFails(updateDoc(doc(db(ALICE), 'users/alice'), {
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db(ALICE), 'users/alice'), {
      createdAt: Timestamp.fromDate(new Date('2020-01-01')),
      updatedAt: serverTimestamp(),
    }));
  });

  it('ownership cannot change, and a conflicting document is never '
    + 'taken over', async () => {
    await seed('users/alice', { uid: 'alice', name: 'Ahmed', createdAt: T0 });
    await assertFails(updateDoc(doc(db(ALICE), 'users/alice'), {
      uid: 'bob', updatedAt: serverTimestamp(),
    }));
    await env.clearFirestore();
    await seed('users/alice', { uid: 'someone-else', name: '' });
    await assertFails(updateDoc(doc(db(ALICE), 'users/alice'), {
      name: 'Ahmed', updatedAt: serverTimestamp(),
    }));
  });

  it('non-profile and legacy fields cannot be added or changed', async () => {
    await seed('users/alice', {
      uid: 'alice', name: 'Ahmed', createdAt: T0,
      phoneNumber: '+201012345678', authEmail: 'u201012345678@ae-coaching.app',
    });
    for (const change of [
      { isAdmin: true }, { phoneNumber: '+201099999999' },
      { authEmail: 'x@ae-coaching.app' }, { emailVerified: true },
    ]) {
      await assertFails(updateDoc(doc(db(ALICE), 'users/alice'), {
        ...change, updatedAt: serverTimestamp(),
      }));
    }
  });

  it('every update must stamp updatedAt with the server time', async () => {
    await seed('users/alice', { uid: 'alice', name: 'Ahmed', createdAt: T0 });
    await assertFails(updateDoc(doc(db(ALICE), 'users/alice'), { name: 'New Name' }));
    await assertFails(updateDoc(doc(db(ALICE), 'users/alice'), {
      name: 'New Name', updatedAt: Timestamp.fromDate(new Date('2020-01-01')),
    }));
  });

  it('an invalid name is rejected on Complete Profile', async () => {
    await seed('users/alice', { uid: 'alice', name: '', createdAt: T0 });
    await assertFails(updateDoc(doc(db(ALICE), 'users/alice'), {
      name: '123', updatedAt: serverTimestamp(),
    }));
  });

  it('email sync: only to the caller\'s own current (token) email',
    async () => {
      await seed('users/alice', {
        uid: 'alice', name: 'Ahmed', email: 'old@example.com', createdAt: T0,
      });
      await assertSucceeds(updateDoc(doc(db(ALICE), 'users/alice'), {
        email: ALICE.email, updatedAt: serverTimestamp(),
      }));
      await assertFails(updateDoc(doc(db(ALICE), 'users/alice'), {
        email: 'attacker@example.com', updatedAt: serverTimestamp(),
      }));
    });

  it('a historical profile (legacy fields, long name, no createdAt) is not '
    + 'rejected over fields the write does not touch', async () => {
    await seed('users/alice', {
      uid: 'alice', name: 'A'.repeat(80), email: 'old@example.com',
      phoneNumber: '+201012345678',
    });
    await assertSucceeds(updateDoc(doc(db(ALICE), 'users/alice'), {
      email: ALICE.email, updatedAt: serverTimestamp(),
    }));
  });

  it('a verified owner reads their profile (normal login / restore)',
    async () => {
      await seed('users/alice', { uid: 'alice', name: 'Ahmed', createdAt: T0 });
      await assertSucceeds(getDoc(doc(db(ALICE), 'users/alice')));
    });

  it('profiles are never deleted by the client', async () => {
    await seed('users/alice', { uid: 'alice', name: 'Ahmed', createdAt: T0 });
    await assertFails(deleteDoc(doc(db(ALICE), 'users/alice')));
  });
});

// ─────────────────────────────────────────────────────────────────────────
for (const [name, sample] of Object.entries(SAMPLES)) {
  describe(`users/{uid}/${name}`, () => {
    beforeEach(async () => seedProfiles());
    const path = `users/alice/${name}/doc_1`;

    it('a verified owner can create, read, replace and delete', async () => {
      const f = db(ALICE);
      await assertSucceeds(setDoc(doc(f, path), sample));
      await assertSucceeds(getDoc(doc(f, path)));
      await assertSucceeds(setDoc(doc(f, path), { ...sample })); // update
      await assertSucceeds(deleteDoc(doc(f, path)));
    });

    it("the app's ordered query works for the verified owner", async () => {
      await seed(path, sample);
      const q = query(collection(db(ALICE), `users/alice/${name}`),
        orderBy(ORDER_FIELD[name], 'desc'));
      await assertSucceeds(getDocs(q));
    });

    it('an UNVERIFIED owner can neither read nor write', async () => {
      await seed(path, sample);
      const f = db(ALICE, { verified: false });
      await assertFails(getDoc(doc(f, path)));
      await assertFails(setDoc(doc(f, path), sample));
      await assertFails(deleteDoc(doc(f, path)));
      await assertFails(getDocs(collection(f, `users/alice/${name}`)));
    });

    it('another verified user is denied everything', async () => {
      await seed(path, sample);
      const f = db(BOB);
      await assertFails(getDoc(doc(f, path)));
      await assertFails(setDoc(doc(f, path), sample));
      await assertFails(deleteDoc(doc(f, path)));
      await assertFails(getDocs(collection(f, `users/alice/${name}`)));
    });

    it('unknown fields, missing required fields and wrong types are '
      + 'rejected', async () => {
      const f = db(ALICE);
      await assertFails(setDoc(doc(f, path), { ...sample, injected: true }));
      const [field, wrong] = REQUIRED[name];
      const missing = { ...sample };
      delete missing[field];
      await assertFails(setDoc(doc(f, path), missing));
      await assertFails(setDoc(doc(f, path), { ...sample, [field]: wrong }));
    });
  });
}

describe('Batch and unknown paths', () => {
  it('the batch delete of exercise sets works for the verified owner',
    async () => {
      await seed('users/alice/exercise_sets/a', SAMPLES.exercise_sets);
      await seed('users/alice/exercise_sets/b', SAMPLES.exercise_sets);
      const f = db(ALICE);
      const batch = writeBatch(f);
      batch.delete(doc(f, 'users/alice/exercise_sets/a'));
      batch.delete(doc(f, 'users/alice/exercise_sets/b'));
      await assertSucceeds(batch.commit());
    });

  it('unknown paths are denied, even for a verified owner', async () => {
    const f = db(ALICE);
    for (const p of [
      'users/alice/settings/prefs',
      'users/alice/fcm_tokens/device1',
      'users/alice/exercise_sets/a/nested/x',
      'settings/global',
      'passwordResetChallenges/x',
    ]) {
      await assertFails(setDoc(doc(f, p), { any: 'thing' }));
      await assertFails(getDoc(doc(f, p)));
    }
  });
});

function assert(condition, message) {
  if (!condition) throw new Error(`Assertion failed: ${message}`);
}

// ─────────────────────────────────────────────────────────────────────────
// FCM device tokens (FcmDeviceService) — integrated with email auth.
// ─────────────────────────────────────────────────────────────────────────
import { createHash } from 'node:crypto';

const TOKEN = 'fcm-device-token-1';
const tokenId = (t) => createHash('sha256').update(t).digest('hex');
const tokenPath = (uid, t = TOKEN) => `users/${uid}/fcmTokens/${tokenId(t)}`;
/** Exactly the first write FcmDeviceService sends (set with merge). */
const firstTokenWrite = (t = TOKEN) => ({
  token: t,
  updatedAt: serverTimestamp(),
  platform: 'android',
  createdAt: serverTimestamp(),
});

describe('users/{uid}/fcmTokens (push tokens)', () => {
  beforeEach(async () => seedProfiles());
  it('a verified owner registers, reads back, refreshes and deletes their '
    + 'token exactly as the app does', async () => {
    const f = db(ALICE);
    const ref = doc(f, tokenPath('alice'));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(setDoc(ref, firstTokenWrite(), { merge: true }));
    // Later registration of the same token: no createdAt, merge keeps it.
    await assertSucceeds(setDoc(ref, {
      token: TOKEN, updatedAt: serverTimestamp(), platform: 'android',
    }, { merge: true }));
    await assertSucceeds(deleteDoc(ref));
  });

  it('token rotation: new token + delete of the old one in one batch',
    async () => {
      const f = db(ALICE);
      await assertSucceeds(
        setDoc(doc(f, tokenPath('alice')), firstTokenWrite(), { merge: true }));
      const batch = writeBatch(f);
      batch.set(doc(f, tokenPath('alice', 'rotated')), firstTokenWrite('rotated'),
        { merge: true });
      batch.delete(doc(f, tokenPath('alice')));
      await assertSucceeds(batch.commit());
    });

  it('iOS and macOS platform names (camel-cased) are accepted', async () => {
    const f = db(ALICE);
    for (const platform of ['iOS', 'macOS']) {
      await assertSucceeds(setDoc(doc(f, tokenPath('alice', platform)),
        { ...firstTokenWrite(platform), platform }));
    }
    await assertFails(setDoc(doc(f, tokenPath('alice', 'web')),
      { ...firstTokenWrite('web'), platform: 'web' }));
  });

  it('an UNVERIFIED owner can never register a token', async () => {
    const f = db(ALICE, { verified: false });
    await assertFails(
      setDoc(doc(f, tokenPath('alice')), firstTokenWrite(), { merge: true }));
  });

  it('logout cleanup: the owner can always read and delete their own token',
    async () => {
      await seed(tokenPath('alice'), {
        token: TOKEN, platform: 'android',
        createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
      const f = db(ALICE, { verified: false });
      await assertSucceeds(getDoc(doc(f, tokenPath('alice'))));
      await assertSucceeds(deleteDoc(doc(f, tokenPath('alice'))));
    });

  it('another user (even verified) and anonymous clients are denied',
    async () => {
      await seed(tokenPath('alice'), {
        token: TOKEN, platform: 'android',
        createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      });
      for (const f of [db(BOB), anon()]) {
        await assertFails(getDoc(doc(f, tokenPath('alice'))));
        await assertFails(deleteDoc(doc(f, tokenPath('alice'))));
        await assertFails(setDoc(doc(f, tokenPath('alice', 'x')),
          firstTokenWrite('x')));
      }
    });

  it('tokens cannot be listed without a fresh sign-in (no device enumeration)', async () => {
    await assertFails(getDocs(collection(db(ALICE), 'users/alice/fcmTokens')));
  });

  it('shape: exact keys, server timestamps, real token, hashed id', async () => {
    const f = db(ALICE);
    const ref = doc(f, tokenPath('alice'));
    await assertFails(setDoc(ref, { ...firstTokenWrite(), extra: 1 }));
    const noPlatform = firstTokenWrite();
    delete noPlatform.platform;
    await assertFails(setDoc(ref, noPlatform));
    await assertFails(setDoc(ref, { ...firstTokenWrite(), token: '' }));
    await assertFails(setDoc(ref,
      { ...firstTokenWrite(), updatedAt: Timestamp.fromMillis(0) }));
    await assertFails(setDoc(ref,
      { ...firstTokenWrite(), createdAt: Timestamp.fromMillis(0) }));
    // Document id must be the SHA-256 hex of a token, not the raw token.
    await assertFails(setDoc(doc(f, `users/alice/fcmTokens/${TOKEN}`),
      firstTokenWrite()));
  });

  it('createdAt is immutable once set', async () => {
    await seed(tokenPath('alice'), {
      token: TOKEN, platform: 'android',
      createdAt: Timestamp.fromMillis(1000), updatedAt: Timestamp.now(),
    });
    await assertFails(setDoc(doc(db(ALICE), tokenPath('alice')), {
      token: TOKEN, platform: 'android',
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
  });
});

// ─────────────────────────────────────────────────────────────────────────
// Personal Hub name edit (UserProfileRepository.updateName).
// ─────────────────────────────────────────────────────────────────────────
describe('Personal Hub profile name edit', () => {
  const existing = () => ({
    uid: 'alice', name: 'Old Name', email: 'alice@example.com',
    createdAt: Timestamp.fromMillis(1000), updatedAt: Timestamp.fromMillis(1000),
  });
  /** Exactly what UserProfileRepository.updateName sends. */
  const nameEdit = (name) => ({
    uid: 'alice', name, updatedAt: serverTimestamp(),
  });

  it("the app's name update succeeds for the verified owner", async () => {
    await seed('users/alice', existing());
    await assertSucceeds(
      updateDoc(doc(db(ALICE), 'users/alice'), nameEdit('أحمد عماد')));
    const stored = await readRaw('users/alice');
    assert(stored.name === 'أحمد عماد', 'name saved');
    assert(stored.email === 'alice@example.com', 'email untouched');
  });

  it('also repairs a historical profile that has no uid field', async () => {
    const legacy = existing();
    delete legacy.uid;
    await seed('users/alice', legacy);
    await assertSucceeds(
      updateDoc(doc(db(ALICE), 'users/alice'), nameEdit('Ahmed')));
  });

  it('the pre-integration write (name only, no updatedAt) is denied',
    async () => {
      await seed('users/alice', existing());
      await assertFails(
        updateDoc(doc(db(ALICE), 'users/alice'), { name: 'Ahmed' }));
    });

  it('names the app rejects are also rejected server-side', async () => {
    await seed('users/alice', existing());
    for (const bad of ['', '123', ' Ahmed', 'a'.repeat(61)]) {
      await assertFails(
        updateDoc(doc(db(ALICE), 'users/alice'), nameEdit(bad)));
    }
  });

  it('unverified users and other users cannot edit the name', async () => {
    await seed('users/alice', existing());
    await assertFails(updateDoc(
      doc(db(ALICE, { verified: false }), 'users/alice'), nameEdit('Ahmed')));
    await assertFails(
      updateDoc(doc(db(BOB), 'users/alice'), nameEdit('Ahmed')));
  });
});

describe('Server-owned inactivity reminder documents (Cloud Functions only)', () => {
  const STATE = 'users/alice/notificationState/inactivity';
  const OWNER = 'fcmTokenOwners/0123abcd';

  it('the reminder state cannot be read, created, changed or deleted by clients', async () => {
    await seed(STATE, { nextReminderAt: Timestamp.fromMillis(1000), remindersSentInCycle: 1 });
    for (const f of [db(ALICE), db(BOB), anon()]) {
      await assertFails(getDoc(doc(f, STATE)));
      await assertFails(setDoc(doc(f, STATE), { nextReminderAt: null }));
      await assertFails(updateDoc(doc(f, STATE), { remindersSentInCycle: 0 }));
      await assertFails(deleteDoc(doc(f, STATE)));
      await assertFails(getDocs(collection(f, 'users/alice/notificationState')));
    }
  });

  it('the reminder delivery gate cannot be read or flipped by any client', async () => {
    const GATE = 'serverConfig/inactivityReminders';
    await seed(GATE, { deliveryMode: 'off' });
    for (const f of [db(ALICE), db(BOB), anon()]) {
      await assertFails(getDoc(doc(f, GATE)));
      await assertFails(setDoc(doc(f, GATE), { deliveryMode: 'all' }));
      await assertFails(updateDoc(doc(f, GATE), { deliveryMode: 'all' }));
      await assertFails(setDoc(doc(f, 'serverConfig/other'), { any: 'thing' }));
      await assertFails(deleteDoc(doc(f, GATE)));
      await assertFails(getDocs(collection(f, 'serverConfig')));
    }
    assert((await readRaw(GATE)).deliveryMode === 'off', 'gate unchanged');
  });

  it('the token ownership registry is invisible and read-only to clients', async () => {
    await seed(OWNER, { uid: 'alice', registeredAt: Timestamp.fromMillis(1000) });
    for (const f of [db(ALICE), db(BOB), anon()]) {
      await assertFails(getDoc(doc(f, OWNER)));
      await assertFails(setDoc(doc(f, OWNER), { uid: 'bob', registeredAt: Timestamp.fromMillis(2000) }));
      await assertFails(deleteDoc(doc(f, OWNER)));
      await assertFails(getDocs(collection(f, 'fcmTokenOwners')));
    }
  });
});

describe('users/{uid}/settings/notifications (reminder preferences)', () => {
  beforeEach(async () => seedProfiles());
  const PATH = 'users/alice/settings/notifications';
  /** The full document the app will write (Stage 3). */
  const prefs = (extra = {}) => ({
    inactivityRemindersEnabled: true,
    language: 'ar',
    timeZone: 'Africa/Cairo',
    updatedAt: serverTimestamp(),
    ...extra,
  });

  it('the verified owner can create, read back and update preferences', async () => {
    const f = db(ALICE);
    await assertSucceeds(setDoc(doc(f, PATH), prefs()));
    await assertSucceeds(getDoc(doc(f, PATH)));
    await assertSucceeds(updateDoc(doc(f, PATH), { inactivityRemindersEnabled: false, updatedAt: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(f, PATH), prefs({ language: 'en', timeZone: 'America/Argentina/Buenos_Aires' })));
    for (const zone of ['UTC', 'Etc/GMT+2', 'Asia/Riyadh', 'America/Port-au-Prince']) {
      await assertSucceeds(setDoc(doc(f, PATH), prefs({ timeZone: zone })));
    }
    const stored = await readRaw(PATH);
    assert(stored.timeZone === 'America/Port-au-Prince', 'time zone saved');
  });

  it('other users, unverified users and signed-out clients are denied', async () => {
    await seed(PATH, { inactivityRemindersEnabled: true, language: 'ar', timeZone: 'Africa/Cairo', updatedAt: Timestamp.fromMillis(1000) });
    for (const f of [db(BOB), db(ALICE, { verified: false }), anon()]) {
      await assertFails(getDoc(doc(f, PATH)));
      await assertFails(setDoc(doc(f, PATH), prefs()));
      await assertFails(updateDoc(doc(f, PATH), { inactivityRemindersEnabled: false, updatedAt: serverTimestamp() }));
    }
    await assertFails(setDoc(doc(db(BOB), 'users/bob/settings/other'), prefs()));
  });

  it('only the four approved fields, with valid values, are accepted', async () => {
    const f = db(ALICE);
    const bad = [
      prefs({ extra: 'x' }),
      prefs({ nextReminderAt: Timestamp.fromMillis(0) }),
      prefs({ inactivityRemindersEnabled: 'false' }),
      prefs({ inactivityRemindersEnabled: 0 }),
      prefs({ language: 'fr' }),
      prefs({ language: 'AR' }),
      prefs({ timeZone: '' }),
      prefs({ timeZone: 'Africa Cairo' }),
      prefs({ timeZone: '../../etc' }),
      prefs({ timeZone: 'A/B/C/D' }),
      prefs({ timeZone: `Zone/${'x'.repeat(60)}` }),
      prefs({ timeZone: 3 }),
      prefs({ updatedAt: Timestamp.fromMillis(1000) }),
      { inactivityRemindersEnabled: true, language: 'ar', updatedAt: serverTimestamp() },
    ];
    for (const data of bad) await assertFails(setDoc(doc(f, PATH), data));
  });

  it('partial updates must keep the document complete and stamp updatedAt', async () => {
    await seed(PATH, { inactivityRemindersEnabled: true, language: 'ar', timeZone: 'Africa/Cairo', updatedAt: Timestamp.fromMillis(1000) });
    const f = db(ALICE);
    await assertFails(updateDoc(doc(f, PATH), { inactivityRemindersEnabled: false }));
    await assertFails(updateDoc(doc(f, PATH), { language: 'de', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(f, PATH), { secret: true, updatedAt: serverTimestamp() }));
  });

  it('preferences cannot be listed, nor deleted without a fresh sign-in', async () => {
    await seed(PATH, { inactivityRemindersEnabled: true, language: 'ar', timeZone: 'Africa/Cairo', updatedAt: Timestamp.fromMillis(1000) });
    await assertFails(deleteDoc(doc(db(ALICE), PATH)));
    await assertFails(getDocs(collection(db(ALICE), 'users/alice/settings')));
  });
});

describe('fcmTokens: per-device server-reminder readiness', () => {
  beforeEach(async () => seedProfiles());
  /** What a build that receives server reminders writes. */
  const readyWrite = (t = TOKEN) => ({ ...firstTokenWrite(t), serverRemindersReadyAt: serverTimestamp() });
  /** What an older build writes on re-registration (set with merge). */
  const oldBuildRefresh = (t = TOKEN) => ({ token: t, updatedAt: serverTimestamp(), platform: 'android' });

  it('a new build confirms readiness with the same server time as updatedAt', async () => {
    await assertSucceeds(setDoc(doc(db(ALICE), tokenPath('alice')), readyWrite(), { merge: true }));
    const stored = await readRaw(tokenPath('alice'));
    assert(stored.serverRemindersReadyAt.isEqual(stored.updatedAt), 'marker equals updatedAt');
  });

  it('old builds keep working: without the marker, and over an existing one', async () => {
    const ref = doc(db(ALICE), tokenPath('alice'));
    await assertSucceeds(setDoc(ref, firstTokenWrite(), { merge: true }));
    await seed(tokenPath('alice'), {
      token: TOKEN,
      platform: 'android',
      createdAt: Timestamp.fromMillis(1000),
      updatedAt: Timestamp.fromMillis(2000),
      serverRemindersReadyAt: Timestamp.fromMillis(2000),
    });
    await assertSucceeds(setDoc(ref, oldBuildRefresh(), { merge: true }));
    const stored = await readRaw(tokenPath('alice'));
    // Carried unchanged, now older than updatedAt: the server reads it as stale.
    assert(stored.serverRemindersReadyAt.toMillis() === 2000, 'marker unchanged');
    assert(!stored.serverRemindersReadyAt.isEqual(stored.updatedAt), 'marker stale');
  });

  it('the marker cannot be backdated, forged or set on another account', async () => {
    const ref = doc(db(ALICE), tokenPath('alice'));
    await assertFails(setDoc(ref, { ...firstTokenWrite(), serverRemindersReadyAt: Timestamp.fromMillis(5) }));
    await assertFails(setDoc(ref, { ...firstTokenWrite(), serverRemindersReadyAt: true }));
    await assertSucceeds(setDoc(ref, readyWrite(), { merge: true }));
    await assertFails(setDoc(ref, { ...oldBuildRefresh(), serverRemindersReadyAt: Timestamp.fromMillis(5) }, { merge: true }));
    await assertFails(setDoc(doc(db(BOB), tokenPath('alice', 'bob-token')), readyWrite('bob-token'), { merge: true }));
  });
});

describe('in-app account deletion (Spark plan)', () => {
  const nowSeconds = () => Math.floor(Date.now() / 1000);
  /** A client that re-authenticated [authAgeSeconds] ago. */
  const client = (user, authAgeSeconds = 5) =>
    env.authenticatedContext(user.uid, {
      email: user.email,
      email_verified: true,
      auth_time: nowSeconds() - authAgeSeconds,
    }).firestore();

  async function seedAccount(uid) {
    await seed(`users/${uid}`, { uid, name: 'Test', email: `${uid}@example.com` });
    await seed(`users/${uid}/exercise_sets/s1`, SAMPLES.exercise_sets);
    await seed(`users/${uid}/workout_sessions/w1`, SAMPLES.workout_sessions);
    await seed(`users/${uid}/fcmTokens/${tokenId(`token-${uid}`)}`, { token: `token-${uid}`, platform: 'android' });
    await seed(`users/${uid}/settings/notifications`, {
      inactivityRemindersEnabled: true, language: 'ar', timeZone: 'Africa/Cairo', updatedAt: Timestamp.fromMillis(1),
    });
  }

  it('right after re-authenticating, the owner can remove all of their own data', async () => {
    await seedAccount('alice');
    const f = client(ALICE);
    await assertSucceeds(getDocs(collection(f, 'users/alice/fcmTokens'))); // every device
    await assertSucceeds(deleteDoc(doc(f, 'users/alice/exercise_sets/s1')));
    await assertSucceeds(deleteDoc(doc(f, 'users/alice/workout_sessions/w1')));
    await assertSucceeds(deleteDoc(doc(f, `users/alice/fcmTokens/${tokenId('token-alice')}`)));
    await assertSucceeds(deleteDoc(doc(f, 'users/alice/settings/notifications')));
    await assertSucceeds(deleteDoc(doc(f, 'users/alice')));
  });

  it('a stale sign-in cannot delete the profile or settings, nor list devices', async () => {
    await seedAccount('alice');
    const stale = client(ALICE, 60 * 60);
    await assertFails(deleteDoc(doc(stale, 'users/alice')));
    await assertFails(deleteDoc(doc(stale, 'users/alice/settings/notifications')));
    await assertFails(getDocs(collection(stale, 'users/alice/fcmTokens')));
  });

  it("nobody can delete another account's data, even freshly signed in", async () => {
    await seedAccount('alice');
    const bob = client(BOB);
    await assertFails(deleteDoc(doc(bob, 'users/alice')));
    await assertFails(deleteDoc(doc(bob, 'users/alice/exercise_sets/s1')));
    await assertFails(deleteDoc(doc(bob, 'users/alice/settings/notifications')));
    await assertFails(getDocs(collection(bob, 'users/alice/fcmTokens')));
    await assertFails(deleteDoc(doc(anon(), 'users/alice')));
  });

  it('server-owned documents stay closed, deletion or not', async () => {
    await seed('users/alice/notificationState/inactivity', { nextReminderAt: null });
    await seed('fcmTokenOwners/abc', { uid: 'alice', registeredAt: Timestamp.fromMillis(1) });
    const f = client(ALICE);
    await assertFails(deleteDoc(doc(f, 'users/alice/notificationState/inactivity')));
    await assertFails(deleteDoc(doc(f, 'fcmTokenOwners/abc')));
  });

  it('deletion requests are operator-only (support cases)', async () => {
    const PATH = 'accountDeletionRequests/alice';
    const request = { uid: 'alice', status: 'pending', requestedAt: serverTimestamp() };
    await assertFails(setDoc(doc(client(ALICE), PATH), request));
    await seed(PATH, { uid: 'alice', status: 'pending', requestedAt: Timestamp.fromMillis(1) });
    await assertFails(getDoc(doc(client(ALICE), PATH)));
    await assertFails(deleteDoc(doc(client(ALICE), PATH)));
  });
});

// ─────────────────────────────────────────────────────────────────────────
// Stage 2: revision-checked sync of workout days and custom exercises
// (lib/core/sync/revision_sync_engine.dart, schema 2).
// ─────────────────────────────────────────────────────────────────────────
const sha = (text) => createHash('sha256').update(text).digest('hex');
let writeCount = 0;
const nextWriteId = () => `install-a-${(++writeCount).toString(36)}`;
const DAY = 'users/alice/workout_templates/day_1';
const EXERCISE = 'users/alice/custom_exercises/custom_1';
const DELETED_AT = '2026-11-17T10:00:00.000Z';

const strengthActivity = (id) => ({
  id, type: 'strength', exerciseId: `repdb:${id}`, referenceType: 'builtIn',
  name: `Exercise ${id}`, strength: { sets: 3, repsMin: 8, repsMax: 12, restSeconds: 90 },
});
const cardioActivity = (id) => ({
  id, type: 'cardio', exerciseId: 'cardio:treadmill', referenceType: 'builtIn',
  name: 'Treadmill', cardio: { mode: 'countdown', durationSeconds: 1200, intensity: 'moderate' },
});
const activities = (n) => Array.from({ length: n }, (_, i) => strengthActivity(`a${i}`));

/** WorkoutTemplate.toCloudContent(). */
const dayContent = () => ({
  id: 'day_1', programId: 'program_1', name: 'Push Day',
  createdAt: '2026-11-07T10:00:00.000', updatedAt: null, isArchived: false,
  orderIndex: 0, activities: [strengthActivity('a1'), cardioActivity('a2')],
});
/** CustomExercise.toCloudContent(). */
const exerciseContent = () => ({
  id: 'custom_1', name: 'Sled push', muscleGroup: 'Legs', equipment: null,
  activityType: 'strength', createdAt: '2026-11-07T10:00:00.000',
});
/** The fields RevisionSyncEngine adds (+ serverUpdatedAt from FirestoreRevisionCloud). */
const revisionFields = (base) => ({
  schemaVersion: 2, baseRevision: base, revision: base + 1,
  writeId: nextWriteId(), contentHash: sha(`content-${base}-${writeCount}`),
  deleted: false, serverUpdatedAt: serverTimestamp(),
});
const dayWrite = (base, extra = {}) => ({ ...dayContent(), ...revisionFields(base), ...extra });
const exerciseWrite = (base, extra = {}) => ({ ...exerciseContent(), ...revisionFields(base), ...extra });
/** A schema 2 document as stored at [revision]. */
const stored = (content, revision, extra = {}) => ({
  ...content, schemaVersion: 2, baseRevision: revision - 1, revision,
  writeId: `stored-${revision}`, contentHash: sha(`stored-${revision}`),
  deleted: false, serverUpdatedAt: Timestamp.fromMillis(1), ...extra,
});
/** Exactly what builds before Stage 2 store: WorkoutTemplate.toJson(). */
const oldDay = (extra = {}) => ({ ...SAMPLES.workout_templates, id: 'day_1', ...extra });
/** Every schema 2 write is a set with merge. */
const write = (f, path, data) => setDoc(doc(f, path), data, { merge: true });

describe('workout days: schema 2 (revision-checked sync)', () => {
  beforeEach(async () => seedProfiles());
  it('migrating an old day: revision 0 → 1; its old exercise list stays untouched', async () => {
    const oldList = [{ assignmentId: 'sq', exerciseId: 'repdb:squat',
      exerciseNameSnapshot: 'Squat', referenceType: 'builtIn' }];
    await seed(DAY, oldDay({ exerciseAssignments: oldList }));
    await assertSucceeds(write(db(ALICE), DAY, dayWrite(0, { legacyDecision: 'restored' })));
    const day = await readRaw(DAY);
    assert(day.schemaVersion === 2 && day.revision === 1, 'migrated at revision 1');
    assert(day.activities.length === 2 && day.activities[1].cardio.durationSeconds === 1200,
      'activities stored with their plans');
    assert(JSON.stringify(day.exerciseAssignments) === JSON.stringify(oldList), 'old list kept');
    // A brand-new day starts at revision 1 too.
    await assertSucceeds(write(db(ALICE), 'users/alice/workout_templates/day_2',
      dayWrite(0, { id: 'day_2' })));
  });

  it('a schema 2 write can neither add nor change the old exercise list', async () => {
    await seed(DAY, oldDay({ exerciseAssignments: [{ assignmentId: 'sq' }] }));
    const f = db(ALICE);
    await assertFails(write(f, DAY, dayWrite(0, { exerciseAssignments: [] })));
    await assertFails(write(f, DAY, dayWrite(0, { exerciseAssignments: [{ assignmentId: 'x' }] })));
    await assertFails(write(f, 'users/alice/workout_templates/day_2',
      dayWrite(0, { id: 'day_2', exerciseAssignments: [] })));
  });

  it('only the next revision, based on the stored one, with a new write id', async () => {
    await seed(DAY, stored(dayContent(), 3));
    const f = db(ALICE);
    await assertFails(write(f, DAY, dayWrite(2))); // outdated base
    await assertFails(write(f, DAY, dayWrite(0))); // as if never synced
    await assertFails(write(f, DAY, dayWrite(3, { revision: 5 }))); // jump
    await assertFails(write(f, DAY, dayWrite(3, { revision: 3 }))); // no increase
    await assertFails(write(f, DAY, dayWrite(3, { writeId: 'stored-3' }))); // reused id
    const noBase = dayWrite(3);
    delete noBase.baseRevision;
    await assertFails(write(f, DAY, noBase));
    await assertSucceeds(write(f, DAY, dayWrite(3, { name: 'Renamed' })));
    const day = await readRaw(DAY);
    assert(day.revision === 4 && day.name === 'Renamed', 'revision 4 stored');
    // A missing document is revision 0.
    await assertFails(write(f, 'users/alice/workout_templates/day_9', dayWrite(1, { id: 'day_9' })));
  });

  it('two phones writing from the same revision: exactly one wins', async () => {
    await seed(DAY, stored(dayContent(), 1));
    const results = await Promise.allSettled([
      write(db(ALICE), DAY, dayWrite(1, { name: 'From A' })),
      write(db(ALICE), DAY, dayWrite(1, { name: 'From B' })),
    ]);
    const won = results.filter((r) => r.status === 'fulfilled');
    assert(won.length === 1, `exactly one write accepted (got ${won.length})`);
    const day = await readRaw(DAY);
    assert(day.revision === 2, 'revision 2');
    // The other phone rebases on revision 2 (after the user's choice).
    await assertSucceeds(write(db(ALICE), DAY, dayWrite(2, { name: 'Chosen' })));
  });

  it('a write queued offline is checked on arrival: an outdated one is rejected', async () => {
    await seed(DAY, stored(dayContent(), 1));
    const offline = db(ALICE);
    await disableNetwork(offline);
    const queued = write(offline, DAY, dayWrite(1, { name: 'Edited offline' }));
    await assertSucceeds(write(db(ALICE), DAY, dayWrite(1, { name: 'Edited online' })));
    await enableNetwork(offline);
    await assertFails(queued);
    const day = await readRaw(DAY);
    assert(day.name === 'Edited online' && day.revision === 2, 'the newer write is kept');
  });

  it('old builds: full writes and deletes work on old days, never on a schema 2 day', async () => {
    const f = db(ALICE);
    // What builds before Stage 2 send: set(toJson()) and delete().
    await assertSucceeds(setDoc(doc(f, DAY), oldDay()));
    await assertSucceeds(setDoc(doc(f, DAY), oldDay({ name: 'Renamed by an old build' })));
    await assertSucceeds(deleteDoc(doc(f, DAY)));

    await seed(DAY, stored(dayContent(), 2));
    await assertFails(setDoc(doc(f, DAY), oldDay()));
    await assertFails(setDoc(doc(f, DAY), oldDay(), { merge: true }));
    await assertFails(updateDoc(doc(f, DAY), { name: 'Renamed by an old build' }));
    await assertFails(deleteDoc(doc(f, DAY)));
    const day = await readRaw(DAY);
    assert(day.revision === 2 && day.activities.length === 2, 'the schema 2 day is intact');
  });

  it('a deletion is a revision-checked tombstone; only a tombstone can be removed', async () => {
    await seed(DAY, stored(dayContent(), 1));
    const f = db(ALICE);
    await assertFails(deleteDoc(doc(f, DAY)));
    await assertFails(write(f, DAY, dayWrite(1, { deleted: true }))); // no deletedAt
    await assertFails(write(f, DAY, dayWrite(0, { deleted: true, deletedAt: DELETED_AT })));
    await assertSucceeds(write(f, DAY, dayWrite(1, { deleted: true, deletedAt: DELETED_AT })));
    // Another phone keeps the day ("Restore the day"), then it is deleted again.
    await assertSucceeds(write(f, DAY, dayWrite(2, { deleted: false })));
    await assertFails(deleteDoc(doc(f, DAY)));
    await assertSucceeds(write(f, DAY, dayWrite(3, { deleted: true, deletedAt: DELETED_AT })));
    await assertSucceeds(deleteDoc(doc(f, DAY)));
  });

  it('a day holds at most 40 activities (WorkoutLimits.maxActivitiesPerDay)', async () => {
    const f = db(ALICE);
    await assertFails(write(f, DAY, dayWrite(0, { activities: activities(41) })));
    await assertSucceeds(write(f, DAY, dayWrite(0, { activities: activities(40) })));
    await assertFails(write(f, DAY, dayWrite(1, { activities: activities(41) })));
    await assertSucceeds(write(f, DAY, dayWrite(1, { activities: [] })));
  });

  it('shape: the path id, required fields, types, decisions, hash and server time', async () => {
    const f = db(ALICE);
    const missing = (key) => {
      const data = dayWrite(0);
      delete data[key];
      return data;
    };
    for (const bad of [
      dayWrite(0, { id: 'another_day' }),
      dayWrite(0, { injected: true }),
      missing('activities'),
      missing('programId'),
      missing('contentHash'),
      missing('serverUpdatedAt'),
      dayWrite(0, { activities: 'none' }),
      dayWrite(0, { isArchived: 0 }),
      dayWrite(0, { orderIndex: 1.5 }),
      dayWrite(0, { legacyDecision: 'maybe' }),
      dayWrite(0, { schemaVersion: 3 }),
      dayWrite(0, { revision: '1' }),
      dayWrite(0, { contentHash: 'abc' }),
      dayWrite(0, { contentHash: sha('x').toUpperCase() }),
      dayWrite(0, { writeId: '' }),
      dayWrite(0, { writeId: 'x'.repeat(65) }),
      dayWrite(0, { deleted: 'no' }),
      dayWrite(0, { serverUpdatedAt: Timestamp.fromMillis(1) }),
    ]) {
      await assertFails(write(f, DAY, bad));
    }
    await assertSucceeds(write(f, DAY, dayWrite(0, { legacyDecision: 'dismissed' })));
  });

  it('the "changed since" pull query works for the verified owner only', async () => {
    const at = (iso) => Timestamp.fromMillis(Date.parse(iso));
    await seed(DAY, stored(dayContent(), 1, { serverUpdatedAt: at('2026-11-17T10:00:00Z') }));
    await seed(EXERCISE, stored(exerciseContent(), 1, { serverUpdatedAt: at('2026-11-17T10:00:00Z') }));
    // RevisionSyncEngine via FirestoreRevisionCloud.fetchChangedSince.
    const changes = (f, name) => getDocs(query(
      collection(f, `users/alice/${name}`),
      where('serverUpdatedAt', '>=', at('2026-11-01T00:00:00Z'))));
    for (const name of ['workout_templates', 'custom_exercises']) {
      const page = await assertSucceeds(changes(db(ALICE), name));
      assert(page.size === 1, `${name}: the changed document is returned`);
      await assertFails(changes(db(BOB), name));
      await assertFails(changes(db(ALICE, { verified: false }), name));
      await assertFails(changes(anon(), name));
    }
  });

  it('unverified owners and other users are denied', async () => {
    await seed(DAY, stored(dayContent(), 1));
    const unverified = db(ALICE, { verified: false });
    await assertFails(getDoc(doc(unverified, DAY)));
    await assertFails(write(unverified, DAY, dayWrite(1)));
    const bob = db(BOB);
    await assertFails(getDoc(doc(bob, DAY)));
    await assertFails(write(bob, DAY, dayWrite(1)));
    await assertFails(getDocs(collection(bob, 'users/alice/workout_templates')));
    await seed(DAY, stored(dayContent(), 2, { deleted: true, deletedAt: DELETED_AT }));
    await assertFails(deleteDoc(doc(bob, DAY)));
  });
});

describe('users/{uid}/custom_exercises (schema 2 only)', () => {
  beforeEach(async () => seedProfiles());
  it('the owner creates, reads, lists and re-syncs', async () => {
    const f = db(ALICE);
    await assertSucceeds(write(f, EXERCISE, exerciseWrite(0)));
    await assertSucceeds(getDoc(doc(f, EXERCISE)));
    await assertSucceeds(getDocs(collection(f, 'users/alice/custom_exercises')));
    await assertSucceeds(write(f, EXERCISE, exerciseWrite(1, { activityType: 'cardio' })));
  });

  it('only revision-checked writes: no plain writes, no outdated revisions', async () => {
    const f = db(ALICE);
    await assertFails(setDoc(doc(f, EXERCISE), exerciseContent()));
    await assertSucceeds(write(f, EXERCISE, exerciseWrite(0)));
    await assertFails(write(f, EXERCISE, exerciseWrite(0))); // outdated
    await assertFails(write(f, EXERCISE, exerciseWrite(1, { revision: 3 })));
  });

  it('shape: the path id, a name, a known activity type', async () => {
    const f = db(ALICE);
    for (const bad of [
      exerciseWrite(0, { id: 'other' }),
      exerciseWrite(0, { name: '' }),
      exerciseWrite(0, { activityType: 'yoga' }),
      exerciseWrite(0, { muscleGroup: 5 }),
      exerciseWrite(0, { injected: true }),
    ]) {
      await assertFails(write(f, EXERCISE, bad));
    }
    await assertSucceeds(write(f, EXERCISE, exerciseWrite(0, { activityType: 'timed' })));
  });

  it('removed only as a tombstone', async () => {
    await seed(EXERCISE, stored(exerciseContent(), 1));
    const f = db(ALICE);
    await assertFails(deleteDoc(doc(f, EXERCISE)));
    await assertSucceeds(write(f, EXERCISE, exerciseWrite(1, { deleted: true, deletedAt: DELETED_AT })));
    await assertSucceeds(deleteDoc(doc(f, EXERCISE)));
  });

  it('unverified owners and other users are denied', async () => {
    await seed(EXERCISE, stored(exerciseContent(), 1));
    for (const f of [db(ALICE, { verified: false }), db(BOB)]) {
      await assertFails(getDoc(doc(f, EXERCISE)));
      await assertFails(write(f, EXERCISE, exerciseWrite(1)));
      await assertFails(getDocs(collection(f, 'users/alice/custom_exercises')));
    }
    await assertFails(write(anon(), EXERCISE, exerciseWrite(1)));
  });
});

describe('in-app account deletion with synced (schema 2) documents', () => {
  const nowSeconds = () => Math.floor(Date.now() / 1000);
  const client = (user, authAgeSeconds = 5) =>
    env.authenticatedContext(user.uid, {
      email: user.email, email_verified: true, auth_time: nowSeconds() - authAgeSeconds,
    }).firestore();

  async function seedSynced(uid) {
    const days = `users/${uid}/workout_templates`;
    await seed(`${days}/old`, oldDay({ id: 'old' }));
    await seed(`${days}/live`, stored({ ...dayContent(), id: 'live' }, 3));
    await seed(`${days}/gone`, stored({ ...dayContent(), id: 'gone' }, 2,
      { deleted: true, deletedAt: DELETED_AT }));
    await seed(`users/${uid}/custom_exercises/custom_1`, stored(exerciseContent(), 1));
  }

  /** FirebaseAccountDeletionRepository._deleteAll, step by step. */
  async function deleteAllLikeTheApp(f, path) {
    for (let round = 0; round < 10; round++) {
      const page = await getDocs(query(collection(f, path), limit(400)));
      if (page.empty) return;
      const live = page.docs.filter((d) => d.data().schemaVersion === 2 && d.data().deleted !== true);
      const batch = writeBatch(f);
      if (live.length > 0) {
        // tombstoneBeforeDelete(): a revision-checked tombstone, its own commit.
        for (const d of live) {
          const { revision, contentHash } = d.data();
          batch.set(d.ref, {
            schemaVersion: 2, baseRevision: revision, revision: revision + 1,
            writeId: `account-deletion-${round}-${d.id}`, contentHash,
            deleted: true, deletedAt: new Date().toISOString(),
            serverUpdatedAt: serverTimestamp(),
          }, { merge: true });
        }
      } else {
        for (const d of page.docs) batch.delete(d.ref);
      }
      await batch.commit();
    }
    throw new Error(`${path} was not emptied`);
  }

  it('live synced days and exercises are tombstoned first, then everything is deleted', async () => {
    await seedSynced('alice');
    const f = client(ALICE);
    await assertFails(deleteDoc(doc(f, 'users/alice/workout_templates/live')));
    await assertFails(deleteDoc(doc(f, 'users/alice/custom_exercises/custom_1')));
    await deleteAllLikeTheApp(f, 'users/alice/workout_templates');
    await deleteAllLikeTheApp(f, 'users/alice/custom_exercises');
    for (const path of ['workout_templates/old', 'workout_templates/live',
      'workout_templates/gone', 'custom_exercises/custom_1']) {
      assert((await readRaw(`users/alice/${path}`)) === undefined, `${path} deleted`);
    }
  });

  it('a tombstone and the delete in ONE batch are denied (rules see the state before the batch)', async () => {
    await seedSynced('alice');
    const f = client(ALICE);
    const ref = doc(f, 'users/alice/workout_templates/live');
    const batch = writeBatch(f);
    batch.set(ref, { ...revisionFields(3), deleted: true, deletedAt: DELETED_AT }, { merge: true });
    batch.delete(ref);
    await assertFails(batch.commit());
  });

  it('a tombstone based on an outdated revision is rejected (the app reads the page again)', async () => {
    await seedSynced('alice');
    const f = client(ALICE);
    await assertFails(write(f, 'users/alice/workout_templates/live',
      { ...revisionFields(2), deleted: true, deletedAt: DELETED_AT }));
    await assertSucceeds(write(f, 'users/alice/workout_templates/live',
      { ...revisionFields(3), deleted: true, deletedAt: DELETED_AT }));
  });

  it("nobody can tombstone or delete another account's synced data", async () => {
    await seedSynced('alice');
    const bob = client(BOB);
    await assertFails(write(bob, 'users/alice/workout_templates/live',
      { ...revisionFields(3), deleted: true, deletedAt: DELETED_AT }));
    await assertFails(deleteDoc(doc(bob, 'users/alice/workout_templates/gone')));
    await assertFails(deleteDoc(doc(bob, 'users/alice/workout_templates/old')));
    await assertFails(getDocs(collection(bob, 'users/alice/custom_exercises')));
  });
});

// ─────────────────────────────────────────────────────────────────────────
// Stage 2.2: nothing new can be created for an account once its deletion
// has started (another device may still hold a valid ID token for up to an
// hour). Cleanup (reads, updates of existing documents, deletes) still works.
// ─────────────────────────────────────────────────────────────────────────
describe('account deletion lock: nothing new after a deletion starts', () => {
  const nowSeconds = () => Math.floor(Date.now() / 1000);
  /** Re-authenticated [authAgeSeconds] ago (the deleting device). */
  const fresh = (user, authAgeSeconds = 5) =>
    env.authenticatedContext(user.uid, {
      email: user.email, email_verified: true, auth_time: nowSeconds() - authAgeSeconds,
    }).firestore();
  const lock = (f) => updateDoc(doc(f, 'users/alice'), { deletionStartedAt: serverTimestamp() });

  /** One NEW document per collection (ids tagged [tag]), as the app creates them. */
  const creations = (f, tag) => ({
    exercise_sets: () => setDoc(doc(f, `users/alice/exercise_sets/${tag}`), SAMPLES.exercise_sets),
    body_measurements: () => setDoc(doc(f, `users/alice/body_measurements/${tag}`), SAMPLES.body_measurements),
    workout_programs: () => setDoc(doc(f, `users/alice/workout_programs/${tag}`), SAMPLES.workout_programs),
    workout_sessions: () => setDoc(doc(f, `users/alice/workout_sessions/${tag}`), SAMPLES.workout_sessions),
    'workout_templates (older builds)': () => setDoc(doc(f, `users/alice/workout_templates/${tag}`),
      { ...SAMPLES.workout_templates, id: tag }),
    'workout_templates (schema 2)': () => write(f, `users/alice/workout_templates/${tag}-v2`,
      dayWrite(0, { id: `${tag}-v2` })),
    custom_exercises: () => write(f, `users/alice/custom_exercises/${tag}`, exerciseWrite(0, { id: tag })),
    fcmTokens: () => setDoc(doc(f, tokenPath('alice', `token-${tag}`)), firstTokenWrite(`token-${tag}`), { merge: true }),
  });
  let round = 0;

  /** Settings is a single document: created only if it does not exist yet. */
  const createSettings = (f) => setDoc(doc(f, 'users/alice/settings/notifications'), {
    inactivityRemindersEnabled: true, language: 'en', timeZone: 'UTC', updatedAt: serverTimestamp(),
  });

  async function expectCreates(f, allowed) {
    const all = { ...creations(f, `new${++round}`) };
    if (!(await readRaw('users/alice/settings/notifications'))) {
      all['settings/notifications'] = () => createSettings(f);
    }
    for (const [name, create] of Object.entries(all)) {
      try {
        await (allowed ? assertSucceeds(create()) : assertFails(create()));
      } catch (error) {
        throw new Error(`${name}: ${error.message}`);
      }
    }
  }

  it('creating needs the account profile (every signed-in user has one)', async () => {
    await expectCreates(db(ALICE), false); // no profile
    await seedProfiles();
    await expectCreates(db(ALICE), true);
  });

  it('once deletion starts, another device creates nothing in any collection; '
    + 'reads, updates and deletes still work so the deletion can finish', async () => {
    await seedProfiles();
    await seed('users/alice/exercise_sets/old', SAMPLES.exercise_sets);
    await seed('users/alice/workout_templates/live', stored({ ...dayContent(), id: 'live' }, 3));
    await assertSucceeds(lock(fresh(ALICE)));

    const otherDevice = db(ALICE); // valid token, signed in long ago
    await expectCreates(otherDevice, false);
    await expectCreates(fresh(ALICE), false); // not even the deleting device
    // Existing documents: still readable, updatable, deletable.
    await assertSucceeds(getDocs(collection(otherDevice, 'users/alice/exercise_sets')));
    await assertSucceeds(setDoc(doc(otherDevice, 'users/alice/exercise_sets/old'), SAMPLES.exercise_sets));
    await assertSucceeds(write(otherDevice, 'users/alice/workout_templates/live',
      { ...revisionFields(3), deleted: true, deletedAt: DELETED_AT })); // tombstone
    const deleting = fresh(ALICE);
    await assertSucceeds(deleteDoc(doc(deleting, 'users/alice/exercise_sets/old')));
    await assertSucceeds(deleteDoc(doc(deleting, 'users/alice/workout_templates/live')));
    await assertSucceeds(deleteDoc(doc(deleting, 'users/alice/settings/notifications')));
    await assertSucceeds(deleteDoc(doc(deleting, 'users/alice')));
    // After the profile is gone (end of the deletion): still nothing.
    await expectCreates(otherDevice, false);
  });

  it('a retried deletion: the lock can be stamped again; a deletion whose '
    + 'profile is already gone has nothing to lock', async () => {
    await seedProfiles();
    await assertSucceeds(lock(fresh(ALICE)));
    await assertSucceeds(lock(fresh(ALICE)));
    await env.withSecurityRulesDisabled(async (ctx) => deleteDoc(doc(ctx.firestore(), 'users/alice')));
    await assertFails(lock(fresh(ALICE))); // not-found: the app moves on
  });

  it('only the owner, right after re-authenticating, sets the lock: server time, '
    + 'nothing else; it can never be removed or changed afterwards', async () => {
    await seedProfiles();
    await assertFails(lock(db(ALICE))); // stale sign-in
    await assertFails(lock(fresh(BOB))); // another account
    await assertFails(lock(anon()));
    await assertFails(updateDoc(doc(fresh(ALICE), 'users/alice'),
      { deletionStartedAt: Timestamp.fromMillis(5) })); // not the server time
    await assertFails(updateDoc(doc(fresh(ALICE), 'users/alice'),
      { deletionStartedAt: serverTimestamp(), name: 'Renamed' })); // nothing else
    await assertSucceeds(lock(fresh(ALICE)));
    const stored1 = await readRaw('users/alice');
    assert(stored1.deletionStartedAt instanceof Timestamp, 'lock stored');

    await assertFails(updateDoc(doc(fresh(ALICE), 'users/alice'), { deletionStartedAt: deleteField() }));
    await assertFails(setDoc(doc(fresh(ALICE), 'users/alice'), {
      uid: 'alice', name: 'Test', email: ALICE.email,
      createdAt: Timestamp.fromMillis(1), updatedAt: serverTimestamp(),
    })); // a full replace would drop it
    // The app's normal profile updates (name edit, email sync) keep it.
    await assertSucceeds(updateDoc(doc(db(ALICE), 'users/alice'),
      { name: 'Alice B', updatedAt: serverTimestamp() }));
    const stored2 = await readRaw('users/alice');
    assert(stored2.deletionStartedAt instanceof Timestamp, 'lock kept');
    await expectCreates(db(ALICE), false);
  });

  it('historical profiles (phone-era fields, no createdAt) can be locked too', async () => {
    await seed('users/alice', { uid: 'alice', name: 'Alice', phoneNumber: '+201000000000', authEmail: 'x@y.z' });
    await expectCreates(db(ALICE), true);
    await assertSucceeds(lock(fresh(ALICE)));
    await expectCreates(db(ALICE), false);
  });
});
