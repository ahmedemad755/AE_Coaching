import type { Clock, StructuredLogger } from '../../shared/application/runtimePorts';
import { CLOSED_DELIVERY_GATE, type DeliveryGate } from '../domain/deliveryGate';
import type { DeliveryResult } from './deliverDueReminder';
import type { DeliveryGateReader, DueReminderFinder } from './ports';

export interface ReminderPassLimits {
  /** Due states fetched per query page. */
  readonly pageSize: number;
  /** Users processed in parallel within a page. */
  readonly concurrency: number;
  /** Hard cap per run; the rest waits for the next hourly run. */
  readonly maxUsersPerRun: number;
  /** Stop starting new work after this long (below the function timeout). */
  readonly timeBudgetMs: number;
}

export const defaultReminderPassLimits: ReminderPassLimits = {
  pageSize: 200,
  concurrency: 10,
  maxUsersPerRun: 5000,
  timeBudgetMs: 7 * 60_000,
};

export type ReminderPassSummary = Readonly<Record<DeliveryResult | 'error', number>> & {
  readonly gate: DeliveryGate['mode'];
  readonly examined: number;
  readonly stoppedEarly: boolean;
};

/**
 * One scheduled pass, behind the operator's delivery gate:
 * - `off`: returns at once (no queries, no sends);
 * - `allowlist`: delivers to the listed accounts only (each still checked
 *   for being due), without scanning everyone else;
 * - `all`: pages through ONLY the due reminder states (indexed query on
 *   `nextReminderAt`), re-reading the gate before every page so switching
 *   it off stops delivery within the running pass.
 * Sends are capped exactly at the gate's `maxSendsPerPass` (each delivery
 * sends at most one reminder, and a batch never exceeds the remaining
 * budget); everything else waits for the next pass, oldest first.
 * Bounded concurrency, time and size budgets. A failure for one user never
 * stops the pass; that user's claim expires and is retried by a later run.
 */
export class RunReminderPass {
  constructor(
    private readonly deps: {
      readonly finder: DueReminderFinder;
      readonly deliver: { execute(uid: string): Promise<DeliveryResult> };
      readonly gate: DeliveryGateReader;
      readonly clock: Clock;
      readonly logger: StructuredLogger;
      readonly limits: ReminderPassLimits;
    },
  ) {}

  async execute(): Promise<ReminderPassSummary> {
    const gate = await this.readGate();
    const run = new PassRun(this.deps, gate.mode === 'off' ? 0 : gate.maxSendsPerPass);
    if (gate.mode === 'allowlist') {
      await run.deliver(gate.uids);
    } else if (gate.mode === 'all') {
      let cursor: unknown | null = null;
      for (let first = true; first || cursor !== null; first = false) {
        if (!first && (await this.readGate()).mode !== 'all') {
          run.stoppedEarly = true;
          break;
        }
        const page = await this.deps.finder.findDue(run.startedAtMs, this.deps.limits.pageSize, cursor);
        if (!(await run.deliver(page.uids))) break;
        cursor = page.cursor;
      }
    }
    const summary: ReminderPassSummary = { ...run.counts, gate: gate.mode, examined: run.examined, stoppedEarly: run.stoppedEarly };
    this.deps.logger.info('inactivity_reminder_pass', summary);
    return summary;
  }

  /** Fails closed: an unreadable gate means no delivery. */
  private async readGate(): Promise<DeliveryGate> {
    try {
      return await this.deps.gate.read();
    } catch {
      this.deps.logger.warn('inactivity_delivery_gate_unreadable');
      return CLOSED_DELIVERY_GATE;
    }
  }
}

/** Counters and budgets of one pass. */
class PassRun {
  readonly startedAtMs: number;
  readonly counts: Record<DeliveryResult | 'error', number> = {
    sent: 0,
    outcome_unknown: 0,
    postponed: 0,
    backlog_deferred: 0,
    recovered_unknown_outcome: 0,
    no_deliverable_device: 0,
    retry_scheduled: 0,
    superseded: 0,
    cancelled: 0,
    lease_lost: 0,
    skipped: 0,
    error: 0,
  };
  examined = 0;
  stoppedEarly = false;

  constructor(
    private readonly deps: {
      readonly deliver: { execute(uid: string): Promise<DeliveryResult> };
      readonly clock: Clock;
      readonly limits: ReminderPassLimits;
    },
    private readonly maxSends: number,
  ) {
    this.startedAtMs = deps.clock.nowMs();
  }

  /** Attempts that may have reached FCM (what the send budget limits). */
  private get sends(): number {
    return this.counts.sent + this.counts.outcome_unknown;
  }

  /** Delivers to [uids] in bounded chunks; false once a budget is spent. */
  async deliver(uids: readonly string[]): Promise<boolean> {
    const { deliver, clock, limits } = this.deps;
    let offset = 0;
    while (offset < uids.length) {
      const remainingSends = this.maxSends - this.sends;
      if (
        remainingSends <= 0 ||
        this.examined >= limits.maxUsersPerRun ||
        clock.nowMs() - this.startedAtMs >= limits.timeBudgetMs
      ) {
        this.stoppedEarly = true;
        return false;
      }
      const size = Math.min(limits.concurrency, limits.maxUsersPerRun - this.examined, remainingSends);
      const chunk = uids.slice(offset, offset + size);
      const results = await Promise.all(chunk.map((uid) => deliver.execute(uid).catch((): 'error' => 'error')));
      this.examined += chunk.length;
      offset += chunk.length;
      for (const result of results) this.counts[result] += 1;
    }
    return true;
  }
}
