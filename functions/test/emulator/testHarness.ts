/**
 * EMULATOR-TEST TIER harness. Every test in test/emulator/ runs against
 * the REAL Firebase Auth Emulator + Firestore Emulator (via
 * `firebase emulators:exec`), never against live Firebase and never
 * using mocks — this is the only tier in this repo that can honestly
 * verify "no Firebase Auth user was created" against real Admin SDK
 * behavior.
 */
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT ?? 'ae-coaching-test';
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? 'localhost:9099';

import { App, getApps, initializeApp } from 'firebase-admin/app';
import { Auth, getAuth } from 'firebase-admin/auth';
import { Firestore, getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = process.env.GCLOUD_PROJECT as string;

let app: App;

export function getTestApp(): App {
  if (!app) {
    app = getApps().length > 0 ? getApps()[0] : initializeApp({ projectId: PROJECT_ID });
  }
  return app;
}

export function getTestAuth(): Auth {
  return getAuth(getTestApp());
}

export function getTestDb(): Firestore {
  return getFirestore(getTestApp());
}

/** Wipes all Auth Emulator user accounts for this project. Real REST
 * call to the emulator's own admin endpoint — not a mock. */
export async function clearAuthEmulator(): Promise<void> {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  await fetch(`http://${host}/emulator/v1/projects/${PROJECT_ID}/accounts`, {
    method: 'DELETE',
  });
}

/** Wipes all Firestore Emulator documents for this project. */
export async function clearFirestoreEmulator(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(
    `http://${host}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' }
  );
}

export async function resetEmulators(): Promise<void> {
  await Promise.all([clearAuthEmulator(), clearFirestoreEmulator()]);
}

/** Returns the current count of Firebase Auth users in the emulator —
 * used to assert "no new user was created" before/after a scenario. */
export async function countAuthUsers(): Promise<number> {
  const auth = getTestAuth();
  let count = 0;
  let pageToken: string | undefined;
  do {
    const page = await auth.listUsers(1000, pageToken);
    count += page.users.length;
    pageToken = page.pageToken;
  } while (pageToken);
  return count;
}

/** Creates a real test user directly via the Admin SDK against the Auth
 * Emulator — used to set up "Phase 3-like" / "Phase 4-migrated-like" /
 * "legacy password-only" fixtures. This IS a legitimate use of
 * createUser: it's test fixture setup against an emulator, not
 * something the password-reset backend itself ever calls. */
export async function createFixtureUser(params: {
  uid: string;
  phoneNumber?: string;
  email?: string;
  password?: string;
}): Promise<void> {
  const auth = getTestAuth();
  await auth.createUser({
    uid: params.uid,
    phoneNumber: params.phoneNumber,
    email: params.email,
    password: params.password,
    emailVerified: false,
  });
}

/** Genuine end-to-end verification via the Auth Emulator's own
 * identitytoolkit REST sign-in endpoint — proves a password actually
 * works (or was actually rejected), rather than just trusting that our
 * own code "said" success. Returns the signed-in uid on success, or
 * null on any sign-in failure (wrong password, no such account, etc).
 */
export async function signInWithEmailPassword(
  email: string,
  password: string
): Promise<string | null> {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const response = await fetch(
    `http://${host}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    }
  );
  if (!response.ok) return null;
  const json = (await response.json()) as { localId?: string };
  return json.localId ?? null;
}
