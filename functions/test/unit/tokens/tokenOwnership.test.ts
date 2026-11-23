import { DeliverDueReminder } from '../../../src/inactivity/application/deliverDueReminder';
import { pseudonymForLogs } from '../../../src/shared/infrastructure/runtimeAdapters';
import { DeliverableTokenDirectory } from '../../../src/tokens/application/deliverableTokenDirectory';
import { ReconcileTokenOwnership } from '../../../src/tokens/application/reconcileTokenOwnership';
import { fcmTokenDocumentId, isServerRemindersReady, parseStoredFcmToken } from '../../../src/tokens/domain/fcmToken';
import { decideOwnership, type TokenOwner } from '../../../src/tokens/domain/tokenOwnership';
import { HOUR, RecordingLogger } from '../../support/inactivityFakes';
import { inactivityHarness, SATURDAY_18_CAIRO as ACT } from '../../support/inactivityHarness';
import { InMemoryTokenRegistry, InMemoryUserTokens } from '../../support/tokenFakes';

const RAW = 'fcm-device-token:APA91b-shared-phone';

describe('stored token validation', () => {
  const id = fcmTokenDocumentId(RAW);

  test('accepts what the app stores: sha256 id, android/iOS/macOS', () => {
    expect(id).toMatch(/^[0-9a-f]{64}$/);
    for (const platform of ['android', 'iOS', 'macOS']) {
      expect(parseStoredFcmToken(id, { token: RAW, platform })).toEqual({
        id,
        token: RAW,
        platform,
        serverRemindersReady: false, // no readiness marker: an older build
      });
    }
  });

  test('readiness: only when the latest registration confirmed it', () => {
    const ready = (updatedAtMs: number | null | undefined, serverRemindersReadyAtMs: number | null | undefined) =>
      parseStoredFcmToken(id, { token: RAW, platform: 'android', updatedAtMs, serverRemindersReadyAtMs })
        ?.serverRemindersReady;
    expect(ready(5000, 5000)).toBe(true); // current build: same server time
    expect(ready(5000, undefined)).toBe(false); // older build, never confirmed
    expect(ready(9000, 5000)).toBe(false); // re-registered later by an older build
    expect(ready(null, null)).toBe(false);
    expect(ready(undefined, 5000)).toBe(false);
    expect(isServerRemindersReady({ updatedAtMs: 1, serverRemindersReadyAtMs: 1 })).toBe(true);
  });

  test('rejects malformed documents', () => {
    expect(parseStoredFcmToken(id, { token: RAW, platform: 'web' })).toBeNull();
    expect(parseStoredFcmToken(id, { token: RAW })).toBeNull();
    expect(parseStoredFcmToken(id, { token: '', platform: 'android' })).toBeNull();
    expect(parseStoredFcmToken(id, { token: ` ${RAW}`, platform: 'android' })).toBeNull();
    expect(parseStoredFcmToken(id, { token: 42, platform: 'android' })).toBeNull();
    expect(parseStoredFcmToken('not-the-hash', { token: RAW, platform: 'android' })).toBeNull();
    const huge = 'x'.repeat(4097);
    expect(parseStoredFcmToken(fcmTokenDocumentId(huge), { token: huge, platform: 'android' })).toBeNull();
  });
});

describe('ownership decision', () => {
  const a1: TokenOwner = { uid: 'A', registeredAtMs: 100 };
  const b2: TokenOwner = { uid: 'B', registeredAtMs: 200 };

  test('first, repeated, transferred and stale registrations', () => {
    expect(decideOwnership(null, a1)).toEqual({ action: 'owned', next: a1 });
    expect(decideOwnership(a1, { uid: 'A', registeredAtMs: 50 })).toEqual({ action: 'owned', next: a1 });
    expect(decideOwnership(a1, b2)).toEqual({ action: 'transferred', next: b2, previousOwnerUid: 'A' });
    expect(decideOwnership(b2, a1)).toEqual({ action: 'rejected_stale', next: b2 });
    // Same server time: the incoming registration wins (never rejected).
    expect(decideOwnership(a1, { uid: 'B', registeredAtMs: 100 })).toMatchObject({ action: 'transferred' });
  });

  test('any delivery order converges on the latest registration', () => {
    const events: TokenOwner[] = [a1, b2, { uid: 'C', registeredAtMs: 300 }, { uid: 'A', registeredAtMs: 250 }];
    const permutations = (xs: TokenOwner[]): TokenOwner[][] =>
      xs.length <= 1 ? [xs] : xs.flatMap((x, i) => permutations([...xs.slice(0, i), ...xs.slice(i + 1)]).map((p) => [x, ...p]));
    for (const order of permutations(events)) {
      let owner: TokenOwner | null = null;
      for (const event of [...order, ...order]) owner = decideOwnership(owner, event).next; // replayed too
      expect(owner).toEqual({ uid: 'C', registeredAtMs: 300 });
    }
  });
});

function tokenWorld() {
  const registry = new InMemoryTokenRegistry();
  const userTokens = new InMemoryUserTokens();
  const logger = new RecordingLogger();
  const reconcile = new ReconcileTokenOwnership({ registry, userTokens, logger, pseudonym: pseudonymForLogs });
  const directory = new DeliverableTokenDirectory({ registry, userTokens });
  return { registry, userTokens, logger, reconcile, directory };
}

describe('ReconcileTokenOwnership', () => {
  test('account switch on a shared device moves the token and removes the old copy', async () => {
    const w = tokenWorld();
    const id = w.userTokens.register('A', RAW, 100);
    await expect(w.reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: 100 })).resolves.toBe('owned');
    // A logged out offline (its token document was never deleted); B signs in.
    w.userTokens.register('B', RAW, 200);
    await expect(w.reconcile.onRegistered({ uid: 'B', tokenId: id, registeredAtMs: 200 })).resolves.toBe('transferred');
    expect(w.userTokens.ids('A')).toEqual([]);
    expect(w.userTokens.ids('B')).toEqual([id]);
    expect(w.registry.owners.get(id)).toEqual({ uid: 'B', registeredAtMs: 200 });
  });

  test('retried and late events are harmless', async () => {
    const w = tokenWorld();
    const id = w.userTokens.register('B', RAW, 200);
    await w.reconcile.onRegistered({ uid: 'B', tokenId: id, registeredAtMs: 200 });
    await expect(w.reconcile.onRegistered({ uid: 'B', tokenId: id, registeredAtMs: 200 })).resolves.toBe('owned');
    // A's older registration event arrives late: its (unchanged) copy is removed.
    w.userTokens.register('A', RAW, 100);
    await expect(w.reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: 100 })).resolves.toBe('rejected_stale');
    expect(w.userTokens.ids('A')).toEqual([]);
    expect(w.userTokens.ids('B')).toEqual([id]);
  });

  test('removal releases ownership only for the current owner', async () => {
    const w = tokenWorld();
    const id = w.userTokens.register('A', RAW, 100);
    await w.reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: 100 });
    w.userTokens.register('B', RAW, 200);
    await w.reconcile.onRegistered({ uid: 'B', tokenId: id, registeredAtMs: 200 });
    await w.reconcile.onRemoved({ uid: 'A', tokenId: id }); // A's copy deleted by the transfer
    expect(w.registry.owners.get(id)?.uid).toBe('B');
    await w.reconcile.onRemoved({ uid: 'B', tokenId: id }); // B logs out
    expect(w.registry.owners.has(id)).toBe(false);
  });

  test('logs never contain the raw token, token id or uid', async () => {
    const w = tokenWorld();
    const id = w.userTokens.register('user-private-A', RAW);
    await w.reconcile.onRegistered({ uid: 'user-private-A', tokenId: id, registeredAtMs: 1 });
    for (const secret of [RAW, id, 'user-private-A']) expect(w.logger.text()).not.toContain(secret);
  });

  test('a transfer never deletes a copy its account registered again afterwards', async () => {
    const w = tokenWorld();
    const id = w.userTokens.register('A', RAW, 100);
    await w.reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: 100 });
    w.userTokens.register('B', RAW, 200);
    w.userTokens.register('A', RAW, 300); // A signs back in before B's event is processed
    await expect(w.reconcile.onRegistered({ uid: 'B', tokenId: id, registeredAtMs: 200 })).resolves.toBe('transferred');
    expect(w.userTokens.ids('A')).toEqual([id]); // fresh registration kept
    await expect(w.reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: 300 })).resolves.toBe('transferred');
    expect(w.registry.owners.get(id)).toEqual({ uid: 'A', registeredAtMs: 300 });
    expect(w.userTokens.ids('A')).toEqual([id]);
    expect(w.userTokens.ids('B')).toEqual([]);
  });

  test('a late stale event never deletes a copy that was registered again since', async () => {
    const w = tokenWorld();
    const id = w.userTokens.register('B', RAW, 200);
    await w.reconcile.onRegistered({ uid: 'B', tokenId: id, registeredAtMs: 200 });
    w.userTokens.register('A', RAW, 300); // the doc now holds A's newer registration
    await expect(w.reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: 100 })).resolves.toBe('rejected_stale');
    expect(w.userTokens.ids('A')).toEqual([id]);
    await w.reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: 300 }); // its own event
    expect(w.registry.owners.get(id)?.uid).toBe('A');
    expect(w.userTokens.ids('B')).toEqual([]);
  });
});

describe('DeliverableTokenDirectory', () => {
  test('only confirmed own tokens are deliverable; foreign and malformed are discarded', async () => {
    const w = tokenWorld();
    const own = w.userTokens.register('A', 'own-token');
    const legacy = w.userTokens.register('A', 'legacy-token'); // no registry record yet
    const foreign = w.userTokens.register('A', 'now-owned-by-B');
    w.userTokens.putRaw('A', 'bad-id', { token: 'whatever', platform: 'android' });
    w.registry.owners.set(own, { uid: 'A', registeredAtMs: 1 });
    w.registry.owners.set(foreign, { uid: 'B', registeredAtMs: 2 });

    const result = await w.directory.listDeliverableTokens('A');
    expect(result.deliverable.map((t) => t.id)).toEqual([own]);
    // The unconfirmed legacy token is neither used nor deleted.
    expect([...result.discard].sort()).toEqual(['bad-id', foreign].sort());
    expect(w.userTokens.ids('A')).toContain(legacy);
  });

  test('an unconfirmed legacy token becomes deliverable once the app registers it again', async () => {
    const w = tokenWorld();
    const legacy = w.userTokens.register('A', 'legacy-token', 50);
    expect((await w.directory.listDeliverableTokens('A')).deliverable).toEqual([]);
    // Next app start: FcmDeviceService rewrites updatedAt -> write trigger.
    w.userTokens.register('A', 'legacy-token', 900);
    await w.reconcile.onRegistered({ uid: 'A', tokenId: legacy, registeredAtMs: 900 });
    expect((await w.directory.listDeliverableTokens('A')).deliverable.map((t) => t.id)).toEqual([legacy]);
  });

  test("a reminder for the previous account never reaches the new account's device", async () => {
    const w = tokenWorld();
    const h = inactivityHarness(ACT);
    const deliver = new DeliverDueReminder({
      store: h.store,
      tokens: w.directory,
      sender: h.sender,
      clock: h.clock,
      ids: h.ids,
      logger: h.logger,
      policy: h.policy,
      pseudonym: pseudonymForLogs,
    });
    const shared = w.userTokens.register('A', RAW, 1);
    const aLaptop = w.userTokens.register('A', 'a-own-laptop-token', 1, 'macOS');
    await w.reconcile.onRegistered({ uid: 'A', tokenId: shared, registeredAtMs: 1 });
    await w.reconcile.onRegistered({ uid: 'A', tokenId: aLaptop, registeredAtMs: 1 });
    await h.activity('A', 'set');
    // B registers the shared phone, but the transfer cleanup has not run yet.
    w.registry.owners.set(shared, { uid: 'B', registeredAtMs: 2 });

    h.clock.set(ACT + 48 * HOUR);
    await expect(deliver.execute('A')).resolves.toBe('sent');
    expect(h.sender.sends[0].tokens.map((t) => t.id)).toEqual([aLaptop]);
    expect(w.userTokens.ids('A')).toEqual([aLaptop]); // stale copy removed
  });
});
