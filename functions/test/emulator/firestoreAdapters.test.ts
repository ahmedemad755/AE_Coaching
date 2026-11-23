/**
 * Firestore adapters against the local emulator (never a real project).
 * Run with `npm run test:emulator:exec`, which starts the Firestore emulator
 * for the `demo-ae-coaching` project and sets FIRESTORE_EMULATOR_HOST.
 */
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { type Firestore, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { DeliverDueReminder } from '../../src/inactivity/application/deliverDueReminder';
import type { InactivityStateStore } from '../../src/inactivity/application/ports';
import { RecordWorkoutActivity } from '../../src/inactivity/application/recordWorkoutActivity';
import { RunReminderPass } from '../../src/inactivity/application/runReminderPass';
import { SyncReminderPreferences } from '../../src/inactivity/application/syncReminderPreferences';
import { defaultReminderPolicy as policy } from '../../src/inactivity/domain/reminderPolicy';
import {
  FirestoreDueReminderFinder,
  FirestoreInactivityStateStore,
} from '../../src/inactivity/infrastructure/firestoreInactivityStateStore';
import { FirestoreDeliveryGateReader } from '../../src/inactivity/infrastructure/firestoreDeliveryGateReader';
import { FirestoreReminderPreferencesReader } from '../../src/inactivity/infrastructure/firestoreReminderPreferencesReader';
import { pseudonymForLogs } from '../../src/shared/infrastructure/runtimeAdapters';
import { DeliverableTokenDirectory } from '../../src/tokens/application/deliverableTokenDirectory';
import { ReconcileTokenOwnership } from '../../src/tokens/application/reconcileTokenOwnership';
import { fcmTokenDocumentId } from '../../src/tokens/domain/fcmToken';
import {
  FirestoreTokenOwnershipRegistry,
  FirestoreUserTokenStore,
  TOKEN_OWNERS_COLLECTION,
} from '../../src/tokens/infrastructure/firestoreTokenStores';
import { FakeClock, FakeSender, FakeTokens, HOUR, RecordingLogger, SequentialIds, token } from '../support/inactivityFakes';
import { dartLocalIso, SATURDAY_18_CAIRO as ACT } from '../support/inactivityHarness';

const PROJECT_ID = 'demo-ae-coaching';
const DUE = ACT + 48 * HOUR;
let app: App;
let db: Firestore;

beforeAll(() => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (host === undefined || host.length === 0) {
    throw new Error('FIRESTORE_EMULATOR_HOST is not set: refusing to run outside the emulator.');
  }
  app = initializeApp({ projectId: PROJECT_ID }, 'emulator-tests');
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

function inactivityWorld(nowMs = ACT) {
  const clock = new FakeClock(nowMs);
  const logger = new RecordingLogger();
  const store = new FirestoreInactivityStateStore(db, policy);
  const preferences = new FirestoreReminderPreferencesReader(db);
  const tokens = new FakeTokens();
  const sender = new FakeSender();
  const runtime = { clock, logger, pseudonym: pseudonymForLogs };
  const record = new RecordWorkoutActivity({ ...runtime, store, preferences, policy });
  const deliverWith = (s: InactivityStateStore) =>
    new DeliverDueReminder({ ...runtime, store: s, tokens, sender, ids: new SequentialIds(), policy });
  const activity = (uid: string, atMs: number) =>
    record.execute({ uid, source: 'set', occurredAtRaw: dartLocalIso(atMs), receivedAtMs: atMs });
  const sync = new SyncReminderPreferences({ ...runtime, store, preferences, policy });
  return { clock, logger, store, tokens, sender, record, sync, deliverWith, activity };
}

/** What a Stage 3+ app writes (older builds never write this document). */
const appPreferences = (uid: string) =>
  db.doc(`users/${uid}/settings/notifications`).set({
    inactivityRemindersEnabled: true,
    language: 'ar',
    timeZone: 'Africa/Cairo',
    updatedAt: Timestamp.now(),
  });

const deliveryGateDoc = () => db.doc('serverConfig/inactivityReminders');

const stateDoc = (uid: string) => db.doc(`users/${uid}/notificationState/inactivity`);

describe('FirestoreInactivityStateStore', () => {
  test('records activity with server-owned fields and Timestamps; reads stored preferences', async () => {
    const w = inactivityWorld();
    await db.doc('users/u1/settings/notifications').set({ inactivityRemindersEnabled: true, language: 'en', timeZone: 'Asia/Riyadh' });
    await expect(w.activity('u1', ACT)).resolves.toBe('started_cycle');
    await expect(w.activity('u1', ACT)).resolves.toBe('not_newer');

    const data = (await stateDoc('u1').get()).data() ?? {};
    expect(data).toMatchObject({
      schemaVersion: 1,
      lastActivityAt: Timestamp.fromMillis(ACT),
      lastActivitySource: 'set',
      cycleId: `c${ACT}`,
      remindersSentInCycle: 0,
      nextReminderAt: Timestamp.fromMillis(DUE),
      language: 'en',
      timeZone: 'Asia/Riyadh',
      leaseId: null,
    });
  });

  test('parallel senders with real transactions: exactly one send', async () => {
    const w = inactivityWorld();
    w.tokens.byUid.set('u1', [token('phone')]);
    await appPreferences('u1');
    await w.activity('u1', ACT);
    w.clock.set(DUE);
    const deliver = w.deliverWith(w.store);
    const results = await Promise.all(Array.from({ length: 8 }, () => deliver.execute('u1')));
    expect(results.filter((r) => r === 'sent')).toHaveLength(1);
    expect(w.sender.sends).toHaveLength(1);
    expect((await stateDoc('u1').get()).get('lastAttempt')).toMatchObject({ status: 'accepted', acceptedDevices: 1 });
  });

  test('crash after FCM acceptance is recovered without a second send', async () => {
    const w = inactivityWorld();
    w.tokens.byUid.set('u1', [token('phone')]);
    await appPreferences('u1');
    await w.activity('u1', ACT);
    w.clock.set(DUE);
    let updates = 0;
    const crashing: InactivityStateStore = {
      update: (uid, mutate) => {
        updates += 1;
        if (updates === 3) return Promise.reject(new Error('process died')); // completion never committed
        return w.store.update(uid, mutate);
      },
    };
    await expect(w.deliverWith(crashing).execute('u1')).rejects.toThrow('process died');
    expect((await stateDoc('u1').get()).get('lastAttempt.status')).toBe('sending');

    w.clock.set(DUE + policy.delivery.leaseMs);
    await expect(w.deliverWith(w.store).execute('u1')).resolves.toBe('recovered_unknown_outcome');
    expect(w.sender.sends).toHaveLength(1);
    expect((await stateDoc('u1').get()).data()).toMatchObject({
      remindersSentInCycle: 1,
      nextReminderAt: Timestamp.fromMillis(DUE + 72 * HOUR),
      lastAttempt: { status: 'outcome_unknown' },
    });
  });
});

describe('FirestoreDueReminderFinder', () => {
  test('returns only due states, oldest first, across pages while they change', async () => {
    const at = (uid: string, ms: number | null) =>
      stateDoc(uid).set({ nextReminderAt: ms === null ? null : Timestamp.fromMillis(ms) });
    const dueUids = Array.from({ length: 23 }, (_, i) => `due-${String(i).padStart(2, '0')}`);
    await Promise.all(dueUids.map((uid, i) => at(uid, DUE - (i % 5) * HOUR)));
    await at('future', DUE + 1);
    await at('disabled', null);
    await db.doc('users/u9/notificationState/other').set({ nextReminderAt: Timestamp.fromMillis(DUE - HOUR) });
    await db.doc('somewhere/x/notificationState/inactivity').set({ nextReminderAt: Timestamp.fromMillis(DUE - HOUR) });

    const finder = new FirestoreDueReminderFinder(db);
    const seen: string[] = [];
    let cursor: unknown | null = null;
    let pages = 0;
    do {
      const page = await finder.findDue(DUE, 10, cursor);
      pages += 1;
      seen.push(...page.uids);
      // Processing moves every returned user out of the due range.
      await Promise.all(page.uids.map((uid) => at(uid, DUE + 72 * HOUR)));
      cursor = page.cursor;
    } while (cursor !== null && pages < 10);

    expect([...seen].sort()).toEqual(dueUids);
    expect(new Set(seen).size).toBe(seen.length);
  });

  test('a full pass over the emulator delivers to every due user, only once the gate is open', async () => {
    const w = inactivityWorld();
    const uids = ['a', 'b', 'c', 'd', 'e'];
    for (const uid of uids) {
      w.tokens.byUid.set(uid, [token(uid)]);
      await appPreferences(uid);
      await w.activity(uid, ACT);
    }
    // A user still on an old build: activity tracked, never due.
    w.tokens.byUid.set('old-build', [token('old-build')]);
    await w.activity('old-build', ACT);
    expect((await stateDoc('old-build').get()).data()).toMatchObject({
      appSupportsServerReminders: false,
      nextReminderAt: null,
    });

    w.clock.set(DUE);
    const pass = new RunReminderPass({
      finder: new FirestoreDueReminderFinder(db),
      deliver: w.deliverWith(w.store),
      gate: new FirestoreDeliveryGateReader(db),
      clock: w.clock,
      logger: w.logger,
      limits: { pageSize: 2, concurrency: 2, maxUsersPerRun: 100, timeBudgetMs: 60_000 },
    });
    // No gate document: delivery is off.
    expect(await pass.execute()).toMatchObject({ gate: 'off', examined: 0, sent: 0 });
    await deliveryGateDoc().set({ deliveryMode: 'all' });
    expect(await pass.execute()).toMatchObject({ gate: 'all', examined: 5, sent: 5 });
    expect(await pass.execute()).toMatchObject({ examined: 0 });
    expect(w.sender.sends.flatMap((s) => s.tokens.map((t) => t.id))).not.toContain('old-build');

    // The old-build user upgrades: the app writes its preferences.
    await appPreferences('old-build');
    await w.sync.execute('old-build');
    expect(await pass.execute()).toMatchObject({ examined: 1, sent: 1 });
  });
});

describe('FirestoreDeliveryGateReader', () => {
  test('missing or malformed configuration reads as off', async () => {
    const reader = new FirestoreDeliveryGateReader(db);
    expect(await reader.read()).toEqual({ mode: 'off' });
    await deliveryGateDoc().set({ deliveryMode: true });
    expect(await reader.read()).toEqual({ mode: 'off' });
    await deliveryGateDoc().set({ deliveryMode: 'allowlist', allowlistUids: ['b', 'a'] });
    expect(await reader.read()).toEqual({ mode: 'allowlist', uids: ['a', 'b'], maxSendsPerPass: 100 });
    await deliveryGateDoc().set({ deliveryMode: 'all' });
    expect(await reader.read()).toEqual({ mode: 'all', maxSendsPerPass: 100 });
    await deliveryGateDoc().set({ deliveryMode: 'all', maxSendsPerPass: 0 });
    expect(await reader.read()).toEqual({ mode: 'off' });
  });
});

describe('token stores', () => {
  const RAW = 'emulator-shared-device-token';
  const id = fcmTokenDocumentId(RAW);
  /** A registration as the app writes it; `updatedAt` is the event's time. */
  const tokenDoc = (uid: string, registeredAtMs: number) =>
    db.doc(`users/${uid}/fcmTokens/${id}`).set({
      token: RAW,
      platform: 'android',
      createdAt: Timestamp.fromMillis(registeredAtMs),
      updatedAt: Timestamp.fromMillis(registeredAtMs),
    });

  function world() {
    const registry = new FirestoreTokenOwnershipRegistry(db);
    const userTokens = new FirestoreUserTokenStore(db);
    const logger = new RecordingLogger();
    return {
      registry,
      userTokens,
      reconcile: new ReconcileTokenOwnership({ registry, userTokens, logger, pseudonym: pseudonymForLogs }),
      directory: new DeliverableTokenDirectory({ registry, userTokens }),
    };
  }

  test('transfer between accounts, stale replay and release', async () => {
    const w = world();
    await tokenDoc('A', 100);
    await w.reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: 100 });
    await tokenDoc('B', 200);
    await expect(w.reconcile.onRegistered({ uid: 'B', tokenId: id, registeredAtMs: 200 })).resolves.toBe('transferred');
    expect((await db.doc(`users/A/fcmTokens/${id}`).get()).exists).toBe(false);
    expect((await db.doc(`${TOKEN_OWNERS_COLLECTION}/${id}`).get()).data()).toEqual({
      uid: 'B',
      registeredAt: Timestamp.fromMillis(200),
    });
    // The registry stores no raw token.
    expect(JSON.stringify((await db.doc(`${TOKEN_OWNERS_COLLECTION}/${id}`).get()).data())).not.toContain(RAW);

    await expect(w.reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: 100 })).resolves.toBe('rejected_stale');
    await w.reconcile.onRemoved({ uid: 'A', tokenId: id });
    expect((await db.doc(`${TOKEN_OWNERS_COLLECTION}/${id}`).get()).exists).toBe(true);
    await w.reconcile.onRemoved({ uid: 'B', tokenId: id });
    expect((await db.doc(`${TOKEN_OWNERS_COLLECTION}/${id}`).get()).exists).toBe(false);
  });

  test('readiness comes from real server timestamps: new build yes, old build and downgrade no', async () => {
    const w = world();
    const reg = async (raw: string, fields: Record<string, unknown>) => {
      const tokenId = fcmTokenDocumentId(raw);
      await db.doc(`users/A/fcmTokens/${tokenId}`).set({ token: raw, platform: 'android', ...fields });
      await w.registry.record(tokenId, () => ({ action: 'owned', next: { uid: 'A', registeredAtMs: 1 } }));
      return tokenId;
    };
    const t1 = Timestamp.fromMillis(1_000);
    const t2 = Timestamp.fromMillis(2_000);
    const newBuild = await reg('new-build', { createdAt: t1, updatedAt: t2, serverRemindersReadyAt: t2 });
    await reg('old-build', { createdAt: t1, updatedAt: t2 });
    await reg('downgraded', { createdAt: t1, updatedAt: t2, serverRemindersReadyAt: t1 });
    const listed = await w.directory.listDeliverableTokens('A');
    expect(listed.deliverable.map((t) => t.id)).toEqual([newBuild]);
    expect(listed.discard).toEqual([]); // owned but not ready: kept, not deleted
  });

  test('ownersOf reads in bounded chunks; directory filters foreign tokens', async () => {
    const w = world();
    const ids = Array.from({ length: 150 }, (_, i) => fcmTokenDocumentId(`t${i}`));
    const batch = db.batch();
    ids.forEach((tokenId, i) =>
      batch.set(db.doc(`${TOKEN_OWNERS_COLLECTION}/${tokenId}`), { uid: i % 2 === 0 ? 'A' : 'B', registeredAt: Timestamp.fromMillis(i) }),
    );
    await batch.commit();
    const owners = await w.registry.ownersOf([...ids, fcmTokenDocumentId('unregistered')]);
    expect(owners.size).toBe(150);
    expect(owners.get(ids[1])).toBe('B');

    const at = Timestamp.fromMillis(7000);
    await db.doc(`users/A/fcmTokens/${ids[0]}`).set({ token: 't0', platform: 'android', updatedAt: at, serverRemindersReadyAt: at });
    await db.doc(`users/A/fcmTokens/${ids[1]}`).set({ token: 't1', platform: 'iOS', updatedAt: at, serverRemindersReadyAt: at });
    await db.doc('users/A/fcmTokens/garbage').set({ token: 'zzz', platform: 'android' });
    const listed = await w.directory.listDeliverableTokens('A');
    expect(listed.deliverable.map((t) => t.id)).toEqual([ids[0]]);
    expect([...listed.discard].sort()).toEqual(['garbage', ids[1]].sort());
    await w.directory.removeTokens('A', listed.discard);
    expect((await db.collection('users/A/fcmTokens').get()).docs.map((d) => d.id)).toEqual([ids[0]]);
  });
});
