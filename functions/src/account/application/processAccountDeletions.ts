import type { Clock, StructuredLogger } from '../../shared/application/runtimePorts';
import type { AccountDeletionRequest } from '../domain/accountDeletionRequest';
import type { AuthAccounts, DeletionRequestStore, UserDataStore } from './ports';

export type DeletionMode = 'dry_run' | 'apply';

export type DeletionOutcome =
  /** Dry run: what an apply would delete. */
  | 'would_delete'
  | 'deleted'
  /** A step failed; the request stays `processing` and a rerun resumes. */
  | 'failed';

export interface DeletionReportEntry {
  /** Pseudonymous reference (never the uid or email). */
  readonly account: string;
  readonly outcome: DeletionOutcome;
  readonly userDocuments: number;
  readonly tokenOwnerships: number;
  readonly authAccount: 'present' | 'absent' | 'deleted';
  /** Stable step name of the failure, never a raw error message. */
  readonly failedStep: string | null;
}

export interface AccountDeletionReport {
  readonly mode: DeletionMode;
  readonly processed: readonly DeletionReportEntry[];
  /** Request documents that are malformed (left untouched; investigate). */
  readonly invalidRequests: number;
  /** A specific uid was asked for but has no valid request: nothing done. */
  readonly refused: boolean;
}

/**
 * Completes filed account-deletion requests with Admin privileges.
 *
 * Per request, in this order (each step idempotent, so an interrupted run is
 * resumed by running again):
 *   1. mark the request `processing` (it stays as the durable record);
 *   2. recursively delete `users/{uid}` (profile, workouts, programs,
 *      measurements, sessions, device tokens, preferences, reminder state);
 *   3. delete the account's `fcmTokenOwners` records (outside users/{uid});
 *   4. delete the Firebase Auth account (LAST: until then the user can still
 *      sign in, and the request record survives);
 *   5. remove the request document (deletion complete).
 *
 * Only accounts with a valid request are ever touched. A dry run reads only.
 */
export class ProcessAccountDeletions {
  constructor(
    private readonly deps: {
      readonly requests: DeletionRequestStore;
      readonly data: UserDataStore;
      readonly auth: AuthAccounts;
      readonly clock: Clock;
      readonly logger: StructuredLogger;
      readonly pseudonym: (value: string) => string;
      readonly maxRequestsPerRun: number;
    },
  ) {}

  async execute(params: { readonly mode: DeletionMode; readonly uid?: string }): Promise<AccountDeletionReport> {
    const { requests } = this.deps;
    let targets: readonly AccountDeletionRequest[];
    let invalidRequests = 0;
    if (params.uid !== undefined) {
      const request = await requests.get(params.uid);
      if (request === null) return { mode: params.mode, processed: [], invalidRequests: 0, refused: true };
      targets = [request];
    } else {
      const listed = await requests.list(this.deps.maxRequestsPerRun);
      targets = listed.requests;
      invalidRequests = listed.invalidIds.length;
    }

    const processed: DeletionReportEntry[] = [];
    for (const request of targets) {
      processed.push(params.mode === 'dry_run' ? await this.describe(request) : await this.complete(request));
    }
    const report: AccountDeletionReport = { mode: params.mode, processed, invalidRequests, refused: false };
    this.deps.logger.info('account_deletion_run', {
      mode: params.mode,
      requests: processed.length,
      deleted: processed.filter((entry) => entry.outcome === 'deleted').length,
      failed: processed.filter((entry) => entry.outcome === 'failed').length,
      invalidRequests,
    });
    return report;
  }

  private async describe(request: AccountDeletionRequest): Promise<DeletionReportEntry> {
    const { data, auth } = this.deps;
    return {
      account: this.deps.pseudonym(request.uid),
      outcome: 'would_delete',
      userDocuments: await data.countUserTree(request.uid),
      tokenOwnerships: await data.countTokenOwnerships(request.uid),
      authAccount: (await auth.exists(request.uid)) ? 'present' : 'absent',
      failedStep: null,
    };
  }

  private async complete(request: AccountDeletionRequest): Promise<DeletionReportEntry> {
    const { requests, data, auth } = this.deps;
    const uid = request.uid;
    let step = 'mark_processing';
    let userDocuments = 0;
    let tokenOwnerships = 0;
    let authAccount: DeletionReportEntry['authAccount'] = 'present';
    try {
      await requests.markProcessing(uid, this.deps.clock.nowMs());
      step = 'delete_user_data';
      userDocuments = await data.countUserTree(uid);
      await data.deleteUserTree(uid);
      step = 'delete_token_ownerships';
      tokenOwnerships = await data.deleteTokenOwnerships(uid);
      step = 'delete_auth_account';
      authAccount = (await auth.delete(uid)) === 'deleted' ? 'deleted' : 'absent';
      step = 'remove_request';
      await requests.remove(uid);
      return { account: this.deps.pseudonym(uid), outcome: 'deleted', userDocuments, tokenOwnerships, authAccount, failedStep: null };
    } catch {
      this.deps.logger.warn('account_deletion_step_failed', { account: this.deps.pseudonym(uid), step });
      return { account: this.deps.pseudonym(uid), outcome: 'failed', userDocuments, tokenOwnerships, authAccount, failedStep: step };
    }
  }
}
