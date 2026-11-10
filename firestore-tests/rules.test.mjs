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
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
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

  it('tokens can never be listed (no device enumeration)', async () => {
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
