import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { defaultReminderPassLimits } from '../../../src/inactivity/application/runReminderPass';
import { defaultReminderPolicy as policy } from '../../../src/inactivity/domain/reminderPolicy';
import { REMINDER_PASS_TIMEOUT_SECONDS } from '../../../src/inactivity/entrypoints/reminderScheduler';
import { NOTIFICATION_STATE_COLLECTION } from '../../../src/inactivity/infrastructure/firestoreInactivityStateStore';

const repo = join(__dirname, '..', '..', '..', '..');
const json = (file: string) => JSON.parse(readFileSync(join(repo, file), 'utf8'));

describe('Firebase configuration', () => {
  const firebase = json('firebase.json');

  test('functions target builds from functions/ and gates deploys on typecheck, unit tests and build', () => {
    expect(firebase.functions).toHaveLength(1);
    const [target] = firebase.functions;
    expect(target).toMatchObject({ source: 'functions', codebase: 'default' });
    expect(target.predeploy).toEqual([
      'npm --prefix "$RESOURCE_DIR" run typecheck',
      'npm --prefix "$RESOURCE_DIR" run test:unit',
      'npm --prefix "$RESOURCE_DIR" run build',
    ]);
    expect(target.ignore).toEqual(expect.arrayContaining(['node_modules', 'test', '*.log']));
    const pkg = json('functions/package.json');
    expect(pkg.main).toBe('lib/index.js');
    expect(pkg.engines.node).toBe('22');
  });

  test('rules and indexes are wired; existing emulators are kept', () => {
    expect(firebase.firestore).toEqual({ rules: 'firestore.rules', indexes: 'firestore.indexes.json' });
    expect(firebase.emulators).toMatchObject({
      auth: { port: 9099 },
      firestore: { port: 8080 },
      functions: { port: 5001 },
      singleProject: true,
    });
  });

  test('the due-reminder query has its collection-group index; default indexes are preserved', () => {
    const { indexes, fieldOverrides } = json('firestore.indexes.json');
    expect(indexes).toEqual([]);
    expect(fieldOverrides).toEqual([
      {
        collectionGroup: NOTIFICATION_STATE_COLLECTION,
        fieldPath: 'nextReminderAt',
        indexes: [
          { order: 'ASCENDING', queryScope: 'COLLECTION' },
          { order: 'DESCENDING', queryScope: 'COLLECTION' },
          { order: 'ASCENDING', queryScope: 'COLLECTION_GROUP' },
        ],
      },
    ]);
  });
});

describe('delivery timing invariants', () => {
  test('pass time budget < function timeout < claim lease', () => {
    const timeoutMs = REMINDER_PASS_TIMEOUT_SECONDS * 1000;
    expect(defaultReminderPassLimits.timeBudgetMs).toBeLessThan(timeoutMs);
    // A live sender is killed before its lease can expire, so a second
    // sender can never take over an attempt that is still being sent.
    expect(timeoutMs).toBeLessThan(policy.delivery.leaseMs);
  });
});
