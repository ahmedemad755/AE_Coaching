/**
 * Account deletion against the local Firestore + Auth emulators
 * (`npm run test:emulator:exec`; demo project only, never a real one).
 */
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { type Auth, getAuth } from 'firebase-admin/auth';
import { type Firestore, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { runAccountDeletionCli } from '../../src/account/entrypoints/accountDeletionCli';
import { DELETION_REQUESTS_COLLECTION } from '../../src/account/infrastructure/firebaseAccountStores';

const PROJECT_ID = 'demo-ae-coaching';
let app: App;
let db: Firestore;
let auth: Auth;

beforeAll(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error('Firestore and Auth emulators must both be running: refusing to run against a real project.');
  }
  app = initializeApp({ projectId: PROJECT_ID }, 'account-deletion-emulator-tests');
  db = getFirestore(app);
  auth = getAuth(app);
});

beforeEach(async () => {
  const firestore = await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  const accounts = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/accounts`,
    { method: 'DELETE' },
  );
  expect(firestore.ok && accounts.ok).toBe(true);
});

afterAll(async () => {
  await deleteApp(app);
});

/** Every kind of data the app and the reminder backend store for a user. */
async function seedUser(uid: string, email: string) {
  await auth.createUser({ uid, email, password: 'correct-horse-battery', emailVerified: true });
  const user = db.doc(`users/${uid}`);
  await user.set({ uid, name: 'Test', email });
  for (const [path, data] of [
    ['exercise_sets/s1', { exerciseName: 'Squat', weight: 100, reps: 5, date: '2026-11-01T10:00:00.000' }],
    ['exercise_sets/s2', { exerciseName: 'Bench', weight: 60, reps: 8, date: '2026-11-02T10:00:00.000' }],
    ['workout_sessions/w1', { status: 'completed' }],
    ['workout_programs/p1', { name: 'PPL' }],
    ['workout_templates/t1', { name: 'Push' }],
    ['body_measurements/m1', { date: '2026-11-01' }],
    ['fcmTokens/tok', { token: `token-${uid}`, platform: 'android' }],
    ['settings/notifications', { inactivityRemindersEnabled: true, language: 'ar', timeZone: 'Africa/Cairo' }],
    ['notificationState/inactivity', { nextReminderAt: null }],
  ] as const) {
    await user.collection(path.split('/')[0]).doc(path.split('/')[1]).set(data);
  }
  // A deeper level, to prove deletion is truly recursive.
  await user.collection('workout_programs').doc('p1').collection('notes').doc('n1').set({ text: 'deep' });
  await db.doc(`fcmTokenOwners/owner-${uid}`).set({ uid, registeredAt: Timestamp.fromMillis(1) });
}

const fileRequest = (uid: string) =>
  db.doc(`${DELETION_REQUESTS_COLLECTION}/${uid}`).set({ uid, status: 'pending', requestedAt: Timestamp.now() });

async function treeSize(uid: string): Promise<number> {
  let total = (await db.doc(`users/${uid}`).get()).exists ? 1 : 0;
  const walk = async (ref: FirebaseFirestore.DocumentReference): Promise<void> => {
    for (const collection of await ref.listCollections()) {
      for (const doc of await collection.listDocuments()) {
        if ((await doc.get()).exists) total += 1;
        await walk(doc);
      }
    }
  };
  await walk(db.doc(`users/${uid}`));
  return total;
}

async function cli(...args: string[]) {
  const lines: string[] = [];
  const code = await runAccountDeletionCli(['--project', PROJECT_ID, ...args], process.env, {
    adminFor: () => ({ db, auth, close: async () => undefined }),
    print: (line) => lines.push(line),
  });
  return { code, report: lines.length > 0 && lines[0].startsWith('{') ? JSON.parse(lines[0]) : null };
}

const authExists = async (uid: string) => {
  try {
    await auth.getUser(uid);
    return true;
  } catch {
    return false;
  }
};

describe('account deletion tool (emulators)', () => {
  test('dry run counts everything and deletes nothing', async () => {
    await seedUser('alice', 'alice@example.com');
    await fileRequest('alice');
    const { code, report } = await cli();
    expect(code).toBe(0);
    expect(report.processed).toEqual([
      expect.objectContaining({ outcome: 'would_delete', userDocuments: 11, tokenOwnerships: 1, authAccount: 'present' }),
    ]);
    expect(await treeSize('alice')).toBe(11);
    expect(await authExists('alice')).toBe(true);
  });

  test('apply removes the whole tree, ownership records, Auth and the request; others are untouched', async () => {
    await seedUser('alice', 'alice@example.com');
    await seedUser('bob', 'bob@example.com');
    await fileRequest('alice');
    const { code, report } = await cli('--apply');
    expect(code).toBe(0);
    expect(report.processed).toEqual([expect.objectContaining({ outcome: 'deleted', authAccount: 'deleted' })]);
    expect(await treeSize('alice')).toBe(0); // including the nested notes level
    expect((await db.doc('fcmTokenOwners/owner-alice').get()).exists).toBe(false);
    expect(await authExists('alice')).toBe(false);
    expect((await db.doc(`${DELETION_REQUESTS_COLLECTION}/alice`).get()).exists).toBe(false);
    // Cross-account isolation.
    expect(await treeSize('bob')).toBe(11);
    expect((await db.doc('fcmTokenOwners/owner-bob').get()).exists).toBe(true);
    expect(await authExists('bob')).toBe(true);
    // Idempotent: nothing left to do.
    expect((await cli('--apply')).report.processed).toEqual([]);
  });

  test('an interrupted run (data half gone, still processing) is completed by the next run', async () => {
    await seedUser('alice', 'alice@example.com');
    await db.doc(`${DELETION_REQUESTS_COLLECTION}/alice`).set({
      uid: 'alice',
      status: 'processing',
      requestedAt: Timestamp.fromMillis(1),
    });
    await db.recursiveDelete(db.collection('users/alice/exercise_sets')); // partial earlier run
    const { report } = await cli('--apply', '--uid', 'alice');
    expect(report.processed).toEqual([expect.objectContaining({ outcome: 'deleted' })]);
    expect(await treeSize('alice')).toBe(0);
    expect(await authExists('alice')).toBe(false);
  });

  test('without a request nothing is deleted, even when targeted', async () => {
    await seedUser('bob', 'bob@example.com');
    const { code, report } = await cli('--apply', '--uid', 'bob');
    expect(code).toBe(3);
    expect(report.refused).toBe(true);
    expect(await treeSize('bob')).toBe(11);
    expect(await authExists('bob')).toBe(true);
  });

  test('the same email can sign up again as a new, empty account', async () => {
    await seedUser('alice', 'alice@example.com');
    await fileRequest('alice');
    await cli('--apply');
    const again = await auth.createUser({ email: 'alice@example.com', password: 'another-secret-pass' });
    expect(again.uid).not.toBe('alice');
    expect(await treeSize(again.uid)).toBe(0);
    expect(await treeSize('alice')).toBe(0);
  });
});
