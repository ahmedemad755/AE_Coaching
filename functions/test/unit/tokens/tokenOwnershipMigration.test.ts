import { MigrateTokenOwnership } from '../../../src/tokens/application/migrateTokenOwnership';
import { fcmTokenDocumentId } from '../../../src/tokens/domain/fcmToken';
import { planOwnershipMigration, type StoredTokenCopy } from '../../../src/tokens/domain/tokenOwnershipMigration';
import { parseMigrationCliArgs } from '../../../src/tokens/entrypoints/tokenOwnershipMigrationCli';
import { pseudonymForLogs } from '../../../src/shared/infrastructure/runtimeAdapters';
import { RecordingLogger } from '../../support/inactivityFakes';
import { InMemoryTokenRegistry, InMemoryUserTokens } from '../../support/tokenFakes';

const copy = (uid: string, raw: string, registeredAtMs = 1, platform = 'android'): StoredTokenCopy => ({
  uid,
  tokenId: fcmTokenDocumentId(raw),
  raw: { token: raw, platform },
  registeredAtMs,
});

describe('planOwnershipMigration', () => {
  test('one holder is assigned; several holders are ambiguous; owned tokens are left alone', () => {
    const plan = planOwnershipMigration(
      [
        copy('A', 'only-a', 10),
        copy('A', 'shared', 20),
        copy('B', 'shared', 30),
        copy('C', 'already-owned', 40),
      ],
      new Set([fcmTokenDocumentId('already-owned')]),
    );
    expect(plan).toEqual({
      distinctTokens: 3,
      assignments: [{ tokenId: fcmTokenDocumentId('only-a'), owner: { uid: 'A', registeredAtMs: 10 } }],
      ambiguous: [{ tokenId: fcmTokenDocumentId('shared'), holderCount: 2 }],
      alreadyOwned: 1,
      malformedCopies: 0,
    });
  });

  test('ambiguity is never resolved by recency: the newest holder is not picked', () => {
    const plan = planOwnershipMigration([copy('A', 't', 1), copy('B', 't', 9_999_999)], new Set());
    expect(plan.assignments).toEqual([]);
    expect(plan.ambiguous).toHaveLength(1);
  });

  test('malformed copies are counted and never assigned', () => {
    const plan = planOwnershipMigration(
      [
        { uid: 'A', tokenId: 'not-the-hash', raw: { token: 'x', platform: 'android' }, registeredAtMs: 1 },
        copy('A', 'web-token', 1, 'web'),
        copy('B', 'valid'),
      ],
      new Set(),
    );
    expect(plan.malformedCopies).toBe(2);
    expect(plan.assignments.map((a) => a.owner.uid)).toEqual(['B']);
  });

  test('a malformed copy does not make a valid single holder ambiguous', () => {
    const tokenId = fcmTokenDocumentId('t');
    const plan = planOwnershipMigration(
      [copy('A', 't'), { uid: 'B', tokenId, raw: { token: 't', platform: 'web' }, registeredAtMs: 5 }],
      new Set(),
    );
    expect(plan.assignments).toEqual([{ tokenId, owner: { uid: 'A', registeredAtMs: 1 } }]);
  });
});

describe('MigrateTokenOwnership', () => {
  function world() {
    const registry = new InMemoryTokenRegistry();
    const tokens = new InMemoryUserTokens();
    const logger = new RecordingLogger();
    const migration = new MigrateTokenOwnership({
      inventory: tokens,
      registry,
      logger,
      pseudonym: pseudonymForLogs,
      pageSize: 2,
      maxCopies: 100,
    });
    return { registry, tokens, logger, migration };
  }

  test('a dry run writes nothing and reports what an apply would do', async () => {
    const w = world();
    w.tokens.register('A', 'only-a', 10);
    w.tokens.register('A', 'shared', 20);
    w.tokens.register('B', 'shared', 30);
    const report = await w.migration.execute('dry_run');
    expect(report).toMatchObject({ mode: 'dry_run', scannedCopies: 3, assignable: 1, assigned: 0, ambiguousTokens: 1 });
    expect(w.registry.owners.size).toBe(0);
  });

  test('apply creates only missing owners, never touches user tokens, and is idempotent', async () => {
    const w = world();
    const onlyA = w.tokens.register('A', 'only-a', 10);
    const shared = w.tokens.register('A', 'shared', 20);
    w.tokens.register('B', 'shared', 30);
    const owned = w.tokens.register('C', 'owned', 40);
    w.registry.owners.set(owned, { uid: 'Z', registeredAtMs: 99 }); // live trigger already decided

    const first = await w.migration.execute('apply');
    expect(first).toMatchObject({ assigned: 1, alreadyOwned: 1, ambiguousTokens: 1, skippedExisting: 0 });
    expect(w.registry.owners.get(onlyA)).toEqual({ uid: 'A', registeredAtMs: 10 });
    expect(w.registry.owners.has(shared)).toBe(false);
    expect(w.registry.owners.get(owned)).toEqual({ uid: 'Z', registeredAtMs: 99 });
    expect([...w.tokens.ids('A'), ...w.tokens.ids('B'), ...w.tokens.ids('C')]).toHaveLength(4);

    const second = await w.migration.execute('apply');
    expect(second).toMatchObject({ assigned: 0, alreadyOwned: 2, ambiguousTokens: 1 });
  });

  test('an owner recorded between planning and writing is kept', async () => {
    const w = world();
    const id = w.tokens.register('A', 'raced', 10);
    const original = w.registry.ownersOf.bind(w.registry);
    w.registry.ownersOf = async (ids) => {
      const result = await original(ids);
      w.registry.owners.set(id, { uid: 'B', registeredAtMs: 20 }); // trigger wins the race
      return result;
    };
    const report = await w.migration.execute('apply');
    expect(report).toMatchObject({ assignable: 1, assigned: 0, skippedExisting: 1 });
    expect(w.registry.owners.get(id)?.uid).toBe('B');
  });

  test('the report and logs carry no uid, raw token or token id', async () => {
    const w = world();
    const id = w.tokens.register('user-private-A', 'raw-secret-token');
    w.tokens.register('user-private-B', 'raw-secret-token');
    const report = await w.migration.execute('dry_run');
    const text = JSON.stringify(report) + w.logger.text();
    for (const secret of ['user-private-A', 'user-private-B', 'raw-secret-token', id]) expect(text).not.toContain(secret);
    expect(report.ambiguous).toEqual([{ token: pseudonymForLogs(id), holders: 2 }]);
  });

  test('refuses to plan beyond the configured size', async () => {
    const w = world();
    const small = new MigrateTokenOwnership({
      inventory: w.tokens,
      registry: w.registry,
      logger: w.logger,
      pseudonym: pseudonymForLogs,
      pageSize: 2,
      maxCopies: 2,
    });
    for (const raw of ['a', 'b', 'c']) w.tokens.register('A', raw);
    await expect(small.execute('apply')).rejects.toThrow('More than 2');
    expect(w.registry.owners.size).toBe(0);
  });
});

describe('migration CLI arguments', () => {
  const emulator = { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' };

  test('dry run by default; --apply against the emulator', () => {
    expect(parseMigrationCliArgs(['--project', 'demo-x'], emulator)).toEqual({
      ok: true,
      options: { projectId: 'demo-x', mode: 'dry_run', live: false },
    });
    expect(parseMigrationCliArgs(['--project', 'demo-x', '--apply'], emulator)).toMatchObject({
      ok: true,
      options: { mode: 'apply' },
    });
  });

  test('a live project needs --allow-live, and a live apply needs the project repeated', () => {
    expect(parseMigrationCliArgs(['--project', 'prod'], {})).toMatchObject({ ok: false });
    expect(parseMigrationCliArgs(['--project', 'prod', '--allow-live'], {})).toMatchObject({
      ok: true,
      options: { mode: 'dry_run', live: true },
    });
    expect(parseMigrationCliArgs(['--project', 'prod', '--allow-live', '--apply'], {})).toMatchObject({ ok: false });
    expect(
      parseMigrationCliArgs(['--project', 'prod', '--allow-live', '--apply', '--confirm-project', 'other'], {}),
    ).toMatchObject({ ok: false });
    expect(
      parseMigrationCliArgs(['--project', 'prod', '--allow-live', '--apply', '--confirm-project', 'prod'], {}),
    ).toMatchObject({ ok: true, options: { mode: 'apply', live: true } });
  });

  test('missing or unknown arguments are rejected', () => {
    expect(parseMigrationCliArgs([], emulator)).toMatchObject({ ok: false });
    expect(parseMigrationCliArgs(['--project'], emulator)).toMatchObject({ ok: false });
    expect(parseMigrationCliArgs(['--project', '--apply'], emulator)).toMatchObject({ ok: false });
    expect(parseMigrationCliArgs(['--project', 'x', '--force'], emulator)).toMatchObject({ ok: false });
  });
});
