/**
 * Token ownership migration and its safety rules against the local
 * Firestore emulator (`npm run test:emulator:exec`; demo project only).
 */
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { type Firestore, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { DeliverDueReminder } from '../../src/inactivity/application/deliverDueReminder';
import { defaultReminderPolicy as policy } from '../../src/inactivity/domain/reminderPolicy';
import { FirestoreInactivityStateStore } from '../../src/inactivity/infrastructure/firestoreInactivityStateStore';
import { RecordWorkoutActivity } from '../../src/inactivity/application/recordWorkoutActivity';
import { FirestoreReminderPreferencesReader } from '../../src/inactivity/infrastructure/firestoreReminderPreferencesReader';
import { pseudonymForLogs } from '../../src/shared/infrastructure/runtimeAdapters';
import { DeliverableTokenDirectory } from '../../src/tokens/application/deliverableTokenDirectory';
import { MigrateTokenOwnership } from '../../src/tokens/application/migrateTokenOwnership';
import { ReconcileTokenOwnership } from '../../src/tokens/application/reconcileTokenOwnership';
import { fcmTokenDocumentId } from '../../src/tokens/domain/fcmToken';
import { decideOwnership } from '../../src/tokens/domain/tokenOwnership';
import { runTokenOwnershipMigrationCli } from '../../src/tokens/entrypoints/tokenOwnershipMigrationCli';
import {
  FirestoreTokenInventory,
  FirestoreTokenOwnershipRegistry,
  FirestoreUserTokenStore,
  MIGRATION_SOURCE,
  TOKEN_OWNERS_COLLECTION,
} from '../../src/tokens/infrastructure/firestoreTokenStores';
import { FakeClock, FakeSender, HOUR, RecordingLogger, SequentialIds } from '../support/inactivityFakes';
import { dartLocalIso, SATURDAY_18_CAIRO as ACT } from '../support/inactivityHarness';

const PROJECT_ID = 'demo-ae-coaching';
let app: App;
let db: Firestore;

beforeAll(() => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (host === undefined || host.length === 0) {
    throw new Error('FIRESTORE_EMULATOR_HOST is not set: refusing to run outside the emulator.');
  }
  app = initializeApp({ projectId: PROJECT_ID }, 'migration-emulator-tests');
  db = getFirestore(app);
});

beforeEach(async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  const response = await fetch(`http://${host}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, {
    method: 'DELETE',
  });
  expect(response.ok).toBe(true);
});

afterAll(async () => {
  await deleteApp(app);
});

/**
 * A token document as FcmDeviceService writes it: the current build adds
 * the readiness marker (equal to updatedAt); [ready] false = older build.
 */
async function registerToken(uid: string, raw: string, atMs: number, platform = 'android', ready = true): Promise<string> {
  const id = fcmTokenDocumentId(raw);
  const at = Timestamp.fromMillis(atMs);
  await db.doc(`users/${uid}/fcmTokens/${id}`).set({
    token: raw,
    platform,
    createdAt: at,
    updatedAt: at,
    ...(ready ? { serverRemindersReadyAt: at } : {}),
  });
  return id;
}

async function ownerOf(tokenId: string) {
  return (await db.doc(`${TOKEN_OWNERS_COLLECTION}/${tokenId}`).get()).data() ?? null;
}

async function allDocumentPaths(): Promise<string[]> {
  const paths: string[] = [];
  for (const group of ['fcmTokens', TOKEN_OWNERS_COLLECTION]) {
    for (const doc of (await db.collectionGroup(group).get()).docs) paths.push(doc.ref.path);
  }
  return paths.sort();
}

function migrationWith(pageSize = 2) {
  const logger = new RecordingLogger();
  return new MigrateTokenOwnership({
    inventory: new FirestoreTokenInventory(db),
    registry: new FirestoreTokenOwnershipRegistry(db),
    logger,
    pseudonym: pseudonymForLogs,
    pageSize,
    maxCopies: 1000,
  });
}

/** The legacy data set: tokens stored before the registry existed. */
async function seedLegacyTokens() {
  const onlyA = await registerToken('A', 'token-only-a', 1000);
  const onlyB = await registerToken('B', 'token-only-b', 1100, 'iOS');
  const shared = await registerToken('A', 'token-shared-phone', 1200);
  await registerToken('B', 'token-shared-phone', 1300); // A's logout cleanup never ran
  const tripled = await registerToken('C', 'token-three-accounts', 1400);
  await registerToken('A', 'token-three-accounts', 1500);
  await registerToken('B', 'token-three-accounts', 1600);
  await db.doc('users/C/fcmTokens/not-a-hash').set({ token: 'x', platform: 'android', updatedAt: Timestamp.fromMillis(1) });
  // A collection named fcmTokens outside users/{uid} is not a user token.
  await db.doc('devices/d1/fcmTokens/stray').set({ token: 'stray', platform: 'android' });
  return { onlyA, onlyB, shared, tripled };
}

describe('token ownership migration (emulator)', () => {
  test('a dry run reads everything and writes nothing', async () => {
    await seedLegacyTokens();
    const before = await allDocumentPaths();
    const report = await migrationWith().execute('dry_run');
    expect(report).toMatchObject({
      mode: 'dry_run',
      scannedCopies: 8,
      distinctTokens: 4,
      malformedCopies: 1,
      alreadyOwned: 0,
      assignable: 2,
      assigned: 0,
      ambiguousTokens: 2,
    });
    expect(report.ambiguous.map((a) => a.holders).sort()).toEqual([2, 3]);
    expect(await allDocumentPaths()).toEqual(before);
  });

  test('apply assigns single holders only, never ambiguous tokens, and changes no user token', async () => {
    const ids = await seedLegacyTokens();
    const userTokensBefore = (await db.collectionGroup('fcmTokens').get()).docs.map((d) => [d.ref.path, d.data()]);
    const report = await migrationWith().execute('apply');
    expect(report).toMatchObject({ mode: 'apply', assigned: 2, ambiguousTokens: 2, skippedExisting: 0 });
    // Backfilled records are marked, so a rollback can remove exactly them.
    expect(await ownerOf(ids.onlyA)).toEqual({
      uid: 'A',
      registeredAt: Timestamp.fromMillis(1000),
      source: MIGRATION_SOURCE,
    });
    expect(await ownerOf(ids.onlyB)).toEqual({
      uid: 'B',
      registeredAt: Timestamp.fromMillis(1100),
      source: MIGRATION_SOURCE,
    });
    expect(await ownerOf(ids.shared)).toBeNull();
    expect(await ownerOf(ids.tripled)).toBeNull();
    const userTokensAfter = (await db.collectionGroup('fcmTokens').get()).docs.map((d) => [d.ref.path, d.data()]);
    expect(userTokensAfter).toEqual(userTokensBefore);

    // A later live registration owns the record: the marker is gone, so a
    // rollback would no longer touch it.
    await new FirestoreTokenOwnershipRegistry(db).record(ids.onlyA, (current) =>
      decideOwnership(current, { uid: 'A', registeredAtMs: 5000 }),
    );
    expect(await ownerOf(ids.onlyA)).toEqual({ uid: 'A', registeredAt: Timestamp.fromMillis(5000) });
  });

  test('apply is idempotent and never overwrites an owner set by the live triggers', async () => {
    const ids = await seedLegacyTokens();
    await db.doc(`${TOKEN_OWNERS_COLLECTION}/${ids.onlyA}`).set({ uid: 'Z', registeredAt: Timestamp.fromMillis(9) });
    const first = await migrationWith().execute('apply');
    expect(first).toMatchObject({ alreadyOwned: 1, assigned: 1 });
    expect(await ownerOf(ids.onlyA)).toEqual({ uid: 'Z', registeredAt: Timestamp.fromMillis(9) });
    const second = await migrationWith(50).execute('apply');
    expect(second).toMatchObject({ alreadyOwned: 2, assignable: 0, assigned: 0 });
  });

  test('the CLI runs a dry run by default and applies only with --apply', async () => {
    const ids = await seedLegacyTokens();
    const lines: string[] = [];
    const deps = { firestoreFor: () => ({ db, close: async () => undefined }), print: (l: string) => lines.push(l) };
    const env = { FIRESTORE_EMULATOR_HOST: process.env.FIRESTORE_EMULATOR_HOST };

    await expect(runTokenOwnershipMigrationCli(['--project', PROJECT_ID], env, deps)).resolves.toBe(0);
    expect(JSON.parse(lines[0])).toMatchObject({ mode: 'dry_run', assignable: 2, assigned: 0, live: false });
    expect(await ownerOf(ids.onlyA)).toBeNull();

    await expect(runTokenOwnershipMigrationCli(['--project', PROJECT_ID, '--apply'], env, deps)).resolves.toBe(0);
    expect(JSON.parse(lines[1])).toMatchObject({ mode: 'apply', assigned: 2 });
    expect(await runTokenOwnershipMigrationCli(['--project', PROJECT_ID, '--apply'], {}, deps)).toBe(2); // live refused
  });
});

describe('only confirmed owners receive reminders (emulator)', () => {
  function world() {
    const clock = new FakeClock(ACT);
    const registry = new FirestoreTokenOwnershipRegistry(db);
    const userTokens = new FirestoreUserTokenStore(db);
    const logger = new RecordingLogger();
    const store = new FirestoreInactivityStateStore(db, policy);
    const sender = new FakeSender();
    const runtime = { clock, logger, pseudonym: pseudonymForLogs };
    const record = new RecordWorkoutActivity({ ...runtime, store, preferences: new FirestoreReminderPreferencesReader(db), policy });
    const deliver = new DeliverDueReminder({
      ...runtime,
      store,
      tokens: new DeliverableTokenDirectory({ registry, userTokens }),
      sender,
      ids: new SequentialIds(),
      policy,
    });
    const reconcile = new ReconcileTokenOwnership({ registry, userTokens, logger, pseudonym: pseudonymForLogs });
    return { clock, sender, record, deliver, reconcile };
  }

  test('ambiguous and unmigrated tokens get nothing until the device registers again', async () => {
    const w = world();
    const shared = await registerToken('A', 'token-shared-phone', 1000);
    await registerToken('B', 'token-shared-phone', 2000);
    for (const uid of ['A', 'B']) {
      // Both run a Stage 3+ app (it wrote their preferences).
      await db.doc(`users/${uid}/settings/notifications`).set({
        inactivityRemindersEnabled: true,
        language: 'ar',
        timeZone: 'Africa/Cairo',
        updatedAt: Timestamp.now(),
      });
      await w.record.execute({ uid, source: 'set', occurredAtRaw: dartLocalIso(ACT), receivedAtMs: ACT });
    }
    await migrationWith().execute('apply'); // ambiguous: left unassigned

    w.clock.set(ACT + 48 * HOUR);
    await expect(w.deliver.execute('A')).resolves.toBe('no_deliverable_device');
    await expect(w.deliver.execute('B')).resolves.toBe('no_deliverable_device');
    expect(w.sender.sends).toHaveLength(0);
    // Nothing was deleted while ownership was unknown.
    expect((await db.doc(`users/A/fcmTokens/${shared}`).get()).exists).toBe(true);

    // B (the device's current account) opens the app: set(merge) rewrites
    // updatedAt, and the write trigger reconciles ownership.
    const reRegisteredAt = ACT + 48 * HOUR + 1;
    await db
      .doc(`users/B/fcmTokens/${shared}`)
      .set(
        { updatedAt: Timestamp.fromMillis(reRegisteredAt), serverRemindersReadyAt: Timestamp.fromMillis(reRegisteredAt) },
        { merge: true },
      );
    await w.reconcile.onRegistered({ uid: 'B', tokenId: shared, registeredAtMs: reRegisteredAt });
    expect(await ownerOf(shared)).toEqual({ uid: 'B', registeredAt: Timestamp.fromMillis(reRegisteredAt) });

    w.clock.set(ACT + 72 * HOUR);
    await expect(w.deliver.execute('B')).resolves.toBe('sent');
    expect(w.sender.sends.map((s) => s.tokens.map((t) => t.id))).toEqual([[shared]]);
    // A's stale copy is now foreign-owned: never used, and cleaned up.
    await expect(w.deliver.execute('A')).resolves.toBe('no_deliverable_device');
    expect((await db.doc(`users/A/fcmTokens/${shared}`).get()).exists).toBe(false);
    expect(w.sender.sends).toHaveLength(1);
  });

  test('a late transfer event never deletes a copy its account registered again', async () => {
    const w = world();
    const id = await registerToken('A', 'token-race', 100);
    await w.reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: 100 });
    await registerToken('B', 'token-race', 200);
    await registerToken('A', 'token-race', 300); // A signs back in before B's event is processed
    await expect(w.reconcile.onRegistered({ uid: 'B', tokenId: id, registeredAtMs: 200 })).resolves.toBe('transferred');
    expect((await db.doc(`users/A/fcmTokens/${id}`).get()).exists).toBe(true);
    await expect(w.reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: 300 })).resolves.toBe('transferred');
    expect(await ownerOf(id)).toEqual({ uid: 'A', registeredAt: Timestamp.fromMillis(300) });
    expect((await db.doc(`users/B/fcmTokens/${id}`).get()).exists).toBe(false);
  });
});
