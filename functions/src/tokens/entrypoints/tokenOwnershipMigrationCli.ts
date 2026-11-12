import { deleteApp, initializeApp } from 'firebase-admin/app';
import { type Firestore, getFirestore } from 'firebase-admin/firestore';
import { cloudLogger, pseudonymForLogs } from '../../shared/infrastructure/runtimeAdapters';
import { MigrateTokenOwnership, type MigrationMode } from '../application/migrateTokenOwnership';
import { FirestoreTokenInventory, FirestoreTokenOwnershipRegistry } from '../infrastructure/firestoreTokenStores';

/**
 * Operator tool (not a deployed function) for the one-time backfill of
 * `fcmTokenOwners`. Dry run by default.
 *
 *   node lib/tokens/entrypoints/tokenOwnershipMigrationCli.js --project <id> [--apply]
 *
 * Against the emulator (FIRESTORE_EMULATOR_HOST set) nothing else is needed.
 * Against a real project it refuses unless `--allow-live` is given, and an
 * apply additionally needs `--confirm-project <id>` repeating the project.
 */

export interface MigrationCliOptions {
  readonly projectId: string;
  readonly mode: MigrationMode;
  readonly live: boolean;
}

const USAGE =
  'usage: --project <id> [--apply] [--allow-live] [--confirm-project <id>]  (dry run unless --apply)';

export function parseMigrationCliArgs(
  argv: readonly string[],
  env: Readonly<Record<string, string | undefined>>,
): { readonly ok: true; readonly options: MigrationCliOptions } | { readonly ok: false; readonly error: string } {
  let projectId: string | null = null;
  let confirmProject: string | null = null;
  let apply = false;
  let allowLive = false;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--apply') apply = true;
    else if (arg === '--allow-live') allowLive = true;
    else if (arg === '--project' || arg === '--confirm-project') {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--') || value.length === 0) {
        return { ok: false, error: `${arg} needs a value. ${USAGE}` };
      }
      if (arg === '--project') projectId = value;
      else confirmProject = value;
      i += 1;
    } else {
      return { ok: false, error: `unknown argument ${arg}. ${USAGE}` };
    }
  }
  if (projectId === null) return { ok: false, error: `--project is required. ${USAGE}` };

  const emulatorHost = env.FIRESTORE_EMULATOR_HOST;
  const live = emulatorHost === undefined || emulatorHost.length === 0;
  if (live && !allowLive) {
    return { ok: false, error: 'FIRESTORE_EMULATOR_HOST is not set: refusing a live project without --allow-live.' };
  }
  if (live && apply && confirmProject !== projectId) {
    return { ok: false, error: 'a live --apply needs --confirm-project repeating the project id.' };
  }
  return { ok: true, options: { projectId, mode: apply ? 'apply' : 'dry_run', live } };
}

/** Runs the migration and prints its report; returns the exit code. */
export async function runTokenOwnershipMigrationCli(
  argv: readonly string[],
  env: Readonly<Record<string, string | undefined>>,
  deps: {
    readonly firestoreFor: (projectId: string) => { readonly db: Firestore; readonly close: () => Promise<void> };
    readonly print: (line: string) => void;
  },
): Promise<number> {
  const parsed = parseMigrationCliArgs(argv, env);
  if (!parsed.ok) {
    deps.print(parsed.error);
    return 2;
  }
  const { db, close } = deps.firestoreFor(parsed.options.projectId);
  try {
    const report = await new MigrateTokenOwnership({
      inventory: new FirestoreTokenInventory(db),
      registry: new FirestoreTokenOwnershipRegistry(db),
      logger: cloudLogger,
      pseudonym: pseudonymForLogs,
      pageSize: 300,
      maxCopies: 200_000,
    }).execute(parsed.options.mode);
    deps.print(JSON.stringify({ ...report, live: parsed.options.live }, null, 2));
    return 0;
  } finally {
    await close();
  }
}

if (require.main === module) {
  runTokenOwnershipMigrationCli(process.argv.slice(2), process.env, {
    firestoreFor: (projectId) => {
      const app = initializeApp({ projectId }, 'token-owner-migration');
      return { db: getFirestore(app), close: () => deleteApp(app) };
    },
    print: (line) => process.stdout.write(`${line}\n`),
  })
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error: unknown) => {
      process.stderr.write(`migration failed: ${error instanceof Error ? error.message : 'unknown error'}\n`);
      process.exitCode = 1;
    });
}
