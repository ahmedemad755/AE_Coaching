import type { Clock, IdGenerator, StructuredLogger } from '../../shared/application/runtimePorts';
import {
  beginSending,
  type ClaimDecision,
  completeAttempt,
  decideClaim,
  type DeliveryCounts,
  type ReminderClaim,
} from '../domain/inactivityState';
import { selectReminderMessage } from '../domain/reminderMessages';
import type { ReminderPolicy } from '../domain/reminderPolicy';
import type { InactivityStateStore, ReminderPushSender, ReminderRecipientTokens } from './ports';

export type DeliveryResult =
  | 'sent'
  | 'outcome_unknown'
  | 'postponed'
  | 'backlog_deferred'
  | 'recovered_unknown_outcome'
  | 'no_deliverable_device'
  | 'retry_scheduled'
  | 'superseded'
  | 'cancelled'
  | 'lease_lost'
  | 'skipped';

/**
 * Delivers (at most) one due reminder to one user:
 *   1. claim it in a transaction (eligibility re-checked there);
 *   2. resolve deliverable devices;
 *   3. mark it `sending` in a transaction (aborts on new activity, disabled
 *      reminders or a lost lease);
 *   4. hand it to the push provider;
 *   5. record the per-device result and the next schedule in a transaction.
 *
 * A crash between 4 and 5 leaves the attempt `sending`; the next run after
 * the lease expires resolves it as `outcome_unknown` without re-sending
 * (see decideClaim). Per-device transport failures with no answer are also
 * `outcome_unknown`. If the provider call itself is rejected, nothing was
 * handed over and the attempt is retried. Exactly-once delivery is not
 * claimed: FCM acceptance is not device delivery, and devices may be offline.
 */
export class DeliverDueReminder {
  constructor(
    private readonly deps: {
      readonly store: InactivityStateStore;
      readonly tokens: ReminderRecipientTokens;
      readonly sender: ReminderPushSender;
      readonly clock: Clock;
      readonly ids: IdGenerator;
      readonly logger: StructuredLogger;
      readonly policy: ReminderPolicy;
      readonly pseudonym: (value: string) => string;
    },
  ) {}

  async execute(uid: string): Promise<DeliveryResult> {
    const { store, policy, clock } = this.deps;
    const leaseId = this.deps.ids.newId();
    const claimedAtMs = clock.nowMs();
    const decision = await store.update<ClaimDecision>(uid, (current) => {
      const decided = decideClaim({ uid, state: current, nowMs: claimedAtMs, leaseId, policy });
      return { next: decided.kind === 'skip' ? null : decided.state, result: decided };
    });
    if (decision.kind === 'skip') return 'skipped';
    if (decision.kind === 'postpone') {
      return this.log(uid, decision.reason === 'backlog' ? 'backlog_deferred' : 'postponed');
    }
    if (decision.kind === 'recovered_unknown_outcome') return this.log(uid, 'recovered_unknown_outcome');

    const { claim } = decision;
    let devices: Awaited<ReturnType<ReminderRecipientTokens['listDeliverableTokens']>>;
    try {
      devices = await this.deps.tokens.listDeliverableTokens(uid);
    } catch {
      // Nothing was sent: retry with backoff instead of holding the lease.
      return this.complete(uid, claim, { acceptedDevices: 0, invalidDevices: 0, failedDevices: 1, unknownDevices: 0 });
    }
    await this.removeQuietly(uid, devices.discard);
    if (devices.deliverable.length === 0) {
      return this.complete(uid, claim, {
        acceptedDevices: 0,
        invalidDevices: devices.discard.length,
        failedDevices: 0,
        unknownDevices: 0,
      });
    }

    const started = await store.update(uid, (current) => {
      const begun = beginSending({ state: current, claim, nowMs: clock.nowMs() });
      return { next: begun.state, result: begun };
    });
    if (!started.ok) return this.log(uid, started.reason === 'disabled' ? 'cancelled' : started.reason);

    let outcomes: Awaited<ReturnType<ReminderPushSender['send']>>;
    try {
      outcomes = await this.deps.sender.send({
        tokens: devices.deliverable,
        message: selectReminderMessage(claim.language, claim.reminderNumber),
        attemptId: claim.attemptId,
      });
    } catch {
      // The provider rejected the whole call before handing anything over
      // (firebase-admin validates and resolves the project first; per-device
      // transport failures come back as per-device results instead).
      outcomes = devices.deliverable.map((token) => ({ tokenId: token.id, outcome: 'retryable' as const }));
    }
    const invalid = outcomes.filter((o) => o.outcome === 'invalid_token').map((o) => o.tokenId);
    await this.removeQuietly(uid, invalid);
    return this.complete(uid, claim, {
      acceptedDevices: outcomes.filter((o) => o.outcome === 'accepted').length,
      invalidDevices: invalid.length,
      failedDevices: outcomes.filter((o) => o.outcome === 'retryable' || o.outcome === 'failed').length,
      unknownDevices: outcomes.filter((o) => o.outcome === 'unknown').length,
    });
  }

  private async complete(uid: string, claim: ReminderClaim, counts: DeliveryCounts): Promise<DeliveryResult> {
    const { store, policy, clock } = this.deps;
    const done = await store.update(uid, (current) => {
      const completed = completeAttempt({ state: current, claim, counts, nowMs: clock.nowMs(), policy });
      return { next: completed.ok ? completed.state : null, result: completed };
    });
    if (!done.ok) return this.log(uid, 'lease_lost', counts);
    const status = done.state.lastAttempt?.status;
    const result: DeliveryResult =
      status === 'accepted'
        ? 'sent'
        : status === 'outcome_unknown'
          ? 'outcome_unknown'
          : status === 'superseded'
          ? 'superseded'
          : status === 'no_deliverable_device'
            ? 'no_deliverable_device'
            : 'retry_scheduled';
    return this.log(uid, result, counts, claim);
  }

  private async removeQuietly(uid: string, tokenIds: readonly string[]): Promise<void> {
    if (tokenIds.length === 0) return;
    try {
      await this.deps.tokens.removeTokens(uid, tokenIds);
    } catch {
      this.deps.logger.warn('inactivity_token_cleanup_failed', {
        user: this.deps.pseudonym(uid),
        tokens: tokenIds.length,
      });
    }
  }

  private log(uid: string, result: DeliveryResult, counts?: DeliveryCounts, claim?: ReminderClaim): DeliveryResult {
    this.deps.logger.info('inactivity_reminder_delivery', {
      user: this.deps.pseudonym(uid),
      result,
      reminder: claim?.reminderNumber ?? null,
      attempt: claim === undefined ? null : this.deps.pseudonym(claim.attemptId),
      acceptedDevices: counts?.acceptedDevices ?? null,
      invalidDevices: counts?.invalidDevices ?? null,
      failedDevices: counts?.failedDevices ?? null,
      unknownDevices: counts?.unknownDevices ?? null,
    });
    return result;
  }
}
