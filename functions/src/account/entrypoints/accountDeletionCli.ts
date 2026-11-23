import { deleteApp, initializeApp } from 'firebase-admin/app';
import { type Auth, getAuth } from 'firebase-admin/auth';
import { type Firestore, getFirestore } from 'firebase-admin/firestore';
import { cloudLogger, pseudonymForLogs, systemClock } from '../../shared/infrastructure/runtimeAdapters';
import { type DeletionMode, ProcessAccountDeletions } from '../application/processAccountDeletions';
import {
  FirebaseAuthAccounts,
  FirestoreDeletionRequestStore,
  FirestoreUserDataStore,
} from '../infrastructure/firebaseAccountStores';

/**
 * Operator tool (never deployed; runs only on a trusted machine with Admin
 * credentials, e.g. `gcloud auth application-default login`). Completes the
 * account-deletion requests users filed in the app. Dry run by default.
 *
 *   node lib/account/entrypoints/accountDeletionCli.js --project <id> [--uid <uid>] [--apply]
 *
 * Against the emulators (FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST
 * set) nothing else is needed. Against a real project it refuses unless
 * `--allow-live` is given, and an apply additionally needs
 * `--confirm-project <id>` repeating the project.
 */

export interface DeletionCliOptions {
  readonly projectId: string;
  readonly mode: DeletionMode;
  readonly uid?: string;
  readonly live: boolean;
}

const USAGE =
  'usage: --project <id> [--uid <uid>] [--apply] [--allow-live] [--confirm-project <id>]  (dry run unless --apply)';

export function parseDeletionCliArgs(
  argv: readonly string[],
  env: Readonly<Record<string, string | undefined>>,
): { readonly ok: true; readonly options: DeletionCliOptions } | { readonly ok: false; readonly error: string } {
  const values = new Map<string, string>();
  let apply = false;
  let allowLive = false;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--apply') apply = true;
    else if (arg === '--allow-live') allowLive = true;
    else if (arg === '--project' || arg === '--confirm-project' || arg === '--uid') {
      const value = argv[i + 1];
      if (value === undefined || value.length === 0 || value.startsWith('--')) {
        return { ok: false, error: `${arg} needs a value. ${USAGE}` };
      }
      values.set(arg, value);
      i += 1;
    } else {
      return { ok: false, error: `unknown argument ${arg}. ${USAGE}` };
    }
  }
  const projectId = values.get('--project');
  if (projectId === undefined) return { ok: false, error: `--project is required. ${USAGE}` };
  const uid = values.get('--uid');
  if (uid !== undefined && (uid.includes('/') || uid.length > 128)) return { ok: false, error: 'invalid --uid.' };

  const firestoreEmulator = env.FIRESTORE_EMULATOR_HOST ?? '';
  const authEmulator = env.FIREBASE_AUTH_EMULATOR_HOST ?? '';
  const live = firestoreEmulator.length === 0 || authEmulator.length === 0;
  if (live && !allowLive) {
    return {
      ok: false,
      error: 'Firestore and Auth emulators are not both set: refusing a live project without --allow-live.',
    };
  }
  if (live && apply && values.get('--confirm-project') !== projectId) {
    return { ok: false, error: 'a live --apply needs --confirm-project repeating the project id.' };
  }
  return { ok: true, options: { projectId, mode: apply ? 'apply' : 'dry_run', uid, live } };
}

export async function runAccountDeletionCli(
  argv: readonly string[],
  env: Readonly<Record<string, string | undefined>>,
  deps: {
    readonly adminFor: (projectId: string) => { readonly db: Firestore; readonly auth: Auth; readonly close: () => Promise<void> };
    readonly print: (line: string) => void;
  },
): Promise<number> {
  const parsed = parseDeletionCliArgs(argv, env);
  if (!parsed.ok) {
    deps.print(parsed.error);
    return 2;
  }
  const { options } = parsed;
  const { db, auth, close } = deps.adminFor(options.projectId);
  try {
    const report = await new ProcessAccountDeletions({
      requests: new FirestoreDeletionRequestStore(db),
      data: new FirestoreUserDataStore(db),
      auth: new FirebaseAuthAccounts(auth),
      clock: systemClock,
      logger: cloudLogger,
      pseudonym: pseudonymForLogs,
      maxRequestsPerRun: 50,
    }).execute({ mode: options.mode, uid: options.uid });
    deps.print(JSON.stringify({ ...report, live: options.live }, null, 2));
    if (report.refused) return 3;
    return report.processed.some((entry) => entry.outcome === 'failed') ? 1 : 0;
  } finally {
    await close();
  }
}

if (require.main === module) {
  runAccountDeletionCli(process.argv.slice(2), process.env, {
    adminFor: (projectId) => {
      const app = initializeApp({ projectId }, 'account-deletion');
      return { db: getFirestore(app), auth: getAuth(app), close: () => deleteApp(app) };
    },
    print: (line) => process.stdout.write(`${line}\n`),
  })
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error: unknown) => {
      process.stderr.write(`account deletion failed: ${error instanceof Error ? error.message : 'unknown error'}\n`);
      process.exitCode = 1;
    });
}
