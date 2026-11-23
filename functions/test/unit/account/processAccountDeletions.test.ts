import type { AuthAccounts, DeletionRequestStore, UserDataStore } from '../../../src/account/application/ports';
import { ProcessAccountDeletions } from '../../../src/account/application/processAccountDeletions';
import { type AccountDeletionRequest, parseDeletionRequest } from '../../../src/account/domain/accountDeletionRequest';
import { parseDeletionCliArgs } from '../../../src/account/entrypoints/accountDeletionCli';
import { pseudonymForLogs } from '../../../src/shared/infrastructure/runtimeAdapters';
import { FakeClock, RecordingLogger } from '../../support/inactivityFakes';

/** One in-memory Firebase project: requests, user trees, token owners, Auth. */
class World implements DeletionRequestStore, UserDataStore, AuthAccounts {
  readonly requests = new Map<string, AccountDeletionRequest>();
  readonly invalid = new Set<string>();
  readonly userDocs = new Map<string, number>(); // uid -> documents under users/{uid}
  readonly owners = new Map<string, string>(); // tokenId -> uid
  readonly authUsers = new Set<string>();
  readonly calls: string[] = [];
  failAt: string | null = null;

  private step(name: string) {
    this.calls.push(name);
    if (this.failAt === name) {
      this.failAt = null; // fails once, like a transient outage
      throw new Error('boom');
    }
  }

  async list(limit: number) {
    const requests = [...this.requests.values()].sort((a, b) => a.requestedAtMs - b.requestedAtMs).slice(0, limit);
    return { requests, invalidIds: [...this.invalid] };
  }
  async get(uid: string) {
    return this.requests.get(uid) ?? null;
  }
  async markProcessing(uid: string) {
    this.step(`mark:${uid}`);
    const request = this.requests.get(uid);
    if (request === undefined) throw new Error('gone');
    this.requests.set(uid, { ...request, status: 'processing' });
  }
  async remove(uid: string) {
    this.step(`remove:${uid}`);
    this.requests.delete(uid);
  }
  async countUserTree(uid: string) {
    return this.userDocs.get(uid) ?? 0;
  }
  async deleteUserTree(uid: string) {
    this.step(`tree:${uid}`);
    this.userDocs.delete(uid);
  }
  async countTokenOwnerships(uid: string) {
    return [...this.owners.values()].filter((owner) => owner === uid).length;
  }
  async deleteTokenOwnerships(uid: string) {
    this.step(`owners:${uid}`);
    let deleted = 0;
    for (const [token, owner] of [...this.owners]) {
      if (owner === uid) {
        this.owners.delete(token);
        deleted += 1;
      }
    }
    return deleted;
  }
  async exists(uid: string) {
    return this.authUsers.has(uid);
  }
  async delete(uid: string): Promise<'deleted' | 'absent'> {
    this.step(`auth:${uid}`);
    return this.authUsers.delete(uid) ? 'deleted' : 'absent';
  }

  addUser(uid: string, documents: number, tokens: string[], requested = false) {
    this.userDocs.set(uid, documents);
    this.authUsers.add(uid);
    for (const token of tokens) this.owners.set(token, uid);
    if (requested) this.requests.set(uid, { uid, status: 'pending', requestedAtMs: this.requests.size + 1 });
  }
}

function setup() {
  const world = new World();
  const logger = new RecordingLogger();
  const process = new ProcessAccountDeletions({
    requests: world,
    data: world,
    auth: world,
    clock: new FakeClock(1_000),
    logger,
    pseudonym: pseudonymForLogs,
    maxRequestsPerRun: 50,
  });
  world.addUser('alice', 42, ['t-a1', 't-a2'], true);
  world.addUser('bob', 17, ['t-b1']); // no request: must never be touched
  return { world, logger, process };
}

describe('ProcessAccountDeletions', () => {
  test('a dry run reports what would be deleted and changes nothing', async () => {
    const { world, process } = setup();
    const report = await process.execute({ mode: 'dry_run' });
    expect(report.processed).toEqual([
      {
        account: pseudonymForLogs('alice'),
        outcome: 'would_delete',
        userDocuments: 42,
        tokenOwnerships: 2,
        authAccount: 'present',
        failedStep: null,
      },
    ]);
    expect(world.calls).toEqual([]);
    expect(world.requests.get('alice')?.status).toBe('pending');
  });

  test('apply deletes data, ownership records, then Auth LAST, then the request', async () => {
    const { world, process } = setup();
    const report = await process.execute({ mode: 'apply' });
    expect(world.calls).toEqual(['mark:alice', 'tree:alice', 'owners:alice', 'auth:alice', 'remove:alice']);
    expect(report.processed[0]).toMatchObject({ outcome: 'deleted', userDocuments: 42, tokenOwnerships: 2, authAccount: 'deleted' });
    expect(world.userDocs.has('alice')).toBe(false);
    expect(world.authUsers.has('alice')).toBe(false);
    expect(world.requests.has('alice')).toBe(false);
    // Cross-account isolation: bob is untouched.
    expect(world.userDocs.get('bob')).toBe(17);
    expect(world.authUsers.has('bob')).toBe(true);
    expect([...world.owners.values()]).toEqual(['bob']);
  });

  for (const failingStep of ['mark:alice', 'tree:alice', 'owners:alice', 'auth:alice', 'remove:alice']) {
    test(`interrupted at ${failingStep}: Auth survives until data is gone, and a rerun completes`, async () => {
      const { world, process } = setup();
      world.failAt = failingStep;
      const first = await process.execute({ mode: 'apply' });
      expect(first.processed[0]).toMatchObject({ outcome: 'failed' });
      expect(world.requests.has('alice')).toBe(true); // durable record kept
      if (world.userDocs.has('alice') || [...world.owners.values()].includes('alice')) {
        expect(world.authUsers.has('alice')).toBe(true); // never Auth before cleanup
      }
      const second = await process.execute({ mode: 'apply' });
      expect(second.processed[0]).toMatchObject({ outcome: 'deleted' });
      expect(world.requests.size).toBe(0);
      expect(world.authUsers.has('alice')).toBe(false);
      expect(world.userDocs.has('alice')).toBe(false);
      expect(world.userDocs.get('bob')).toBe(17);
    });
  }

  test('rerunning after completion is a no-op; an already-deleted Auth account is fine', async () => {
    const { world, process } = setup();
    await process.execute({ mode: 'apply' });
    expect((await process.execute({ mode: 'apply' })).processed).toEqual([]);
    // A request whose Auth account was removed by an earlier interrupted run.
    world.addUser('carol', 3, [], true);
    world.authUsers.delete('carol');
    expect((await process.execute({ mode: 'apply' })).processed[0]).toMatchObject({ outcome: 'deleted', authAccount: 'absent' });
  });

  test('a specific uid without a request is refused and nothing is touched', async () => {
    const { world, process } = setup();
    const report = await process.execute({ mode: 'apply', uid: 'bob' });
    expect(report).toMatchObject({ refused: true, processed: [] });
    expect(world.calls).toEqual([]);
    expect((await process.execute({ mode: 'apply', uid: 'alice' })).processed).toHaveLength(1);
  });

  test('malformed requests are counted and left alone; logs carry no uid', async () => {
    const { world, logger, process } = setup();
    world.invalid.add('mallory');
    const report = await process.execute({ mode: 'apply' });
    expect(report.invalidRequests).toBe(1);
    expect(logger.text()).not.toContain('alice');
    expect(JSON.stringify(report)).not.toContain('alice');
  });
});

describe('deletion request validation', () => {
  test('the stored uid must match the document id', () => {
    expect(parseDeletionRequest('alice', { uid: 'alice', status: 'pending', requestedAtMs: 5 })).toEqual({
      uid: 'alice',
      status: 'pending',
      requestedAtMs: 5,
    });
    expect(parseDeletionRequest('alice', { uid: 'bob', status: 'pending', requestedAtMs: 5 })).toBeNull();
    expect(parseDeletionRequest('alice', { uid: 'alice', status: 'done', requestedAtMs: 5 })).toBeNull();
    expect(parseDeletionRequest('alice', { uid: 'alice', status: 'pending' })).toBeNull();
  });
});

describe('operator CLI guards', () => {
  const emulators = { FIRESTORE_EMULATOR_HOST: 'localhost:8080', FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099' };

  test('dry run by default; apply only when asked', () => {
    expect(parseDeletionCliArgs(['--project', 'demo-x'], emulators)).toMatchObject({ ok: true, options: { mode: 'dry_run', live: false } });
    expect(parseDeletionCliArgs(['--project', 'demo-x', '--apply', '--uid', 'u1'], emulators)).toMatchObject({
      ok: true,
      options: { mode: 'apply', uid: 'u1' },
    });
  });

  test('a live project needs --allow-live, and a live apply the project twice', () => {
    expect(parseDeletionCliArgs(['--project', 'p'], {})).toMatchObject({ ok: false });
    expect(parseDeletionCliArgs(['--project', 'p'], { FIRESTORE_EMULATOR_HOST: 'x' })).toMatchObject({ ok: false }); // Auth would be live
    expect(parseDeletionCliArgs(['--project', 'p', '--allow-live'], {})).toMatchObject({ ok: true, options: { live: true } });
    expect(parseDeletionCliArgs(['--project', 'p', '--allow-live', '--apply'], {})).toMatchObject({ ok: false });
    expect(
      parseDeletionCliArgs(['--project', 'p', '--allow-live', '--apply', '--confirm-project', 'p'], {}),
    ).toMatchObject({ ok: true, options: { mode: 'apply' } });
    expect(parseDeletionCliArgs(['--project', 'p', '--uid', 'a/b'], emulators)).toMatchObject({ ok: false });
  });
});
