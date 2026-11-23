import type { Clock, StructuredLogger } from '../../shared/application/runtimePorts';
import type { ActivitySource } from '../domain/activityTime';
import { type ActivityOutcome, applyActivity, applyPreferences } from '../domain/inactivityState';
import type { ReminderPolicy } from '../domain/reminderPolicy';
import { resolveReminderPreferences } from '../domain/reminderPreferences';
import type { InactivityStateStore, ReminderPreferencesReader } from './ports';

export interface WorkoutActivityInput {
  readonly uid: string;
  readonly source: ActivitySource;
  /** Client-reported occurrence time, exactly as stored (untrusted). */
  readonly occurredAtRaw: unknown;
  /** Server creation time of the activity document (trusted). */
  readonly receivedAtMs: number;
}

/**
 * A workout session was started or a set was recorded: move the user's
 * inactivity clock forward (never backward) and reset the reminder cycle.
 * Idempotent: the same event delivered twice changes nothing the second time.
 */
export class RecordWorkoutActivity {
  constructor(
    private readonly deps: {
      readonly store: InactivityStateStore;
      readonly preferences: ReminderPreferencesReader;
      readonly clock: Clock;
      readonly logger: StructuredLogger;
      readonly policy: ReminderPolicy;
      readonly pseudonym: (value: string) => string;
    },
  ) {}

  async execute(input: WorkoutActivityInput): Promise<ActivityOutcome> {
    const { store, policy } = this.deps;
    const nowMs = this.deps.clock.nowMs();
    const defaults = resolveReminderPreferences(null, policy);
    const { outcome, created } = await store.update(input.uid, (current) => {
      const applied = applyActivity({
        state: current,
        source: input.source,
        occurredAtRaw: input.occurredAtRaw,
        receivedAtMs: input.receivedAtMs,
        defaultPreferences: defaults,
        nowMs,
        policy,
      });
      return {
        next: applied.outcome === 'started_cycle' ? applied.state : null,
        result: { outcome: applied.outcome, created: current === null },
      };
    });

    // First activity ever: adopt stored preferences now instead of waiting
    // for a preference change (the only extra read on this path).
    if (created) {
      const stored = await this.deps.preferences.read(input.uid);
      const preferences = resolveReminderPreferences(stored, policy);
      await store.update(input.uid, (current) => ({
        next: applyPreferences({ state: current, preferences, fromAppDocument: stored !== null, nowMs, policy }),
        result: undefined,
      }));
    }

    this.deps.logger.info('inactivity_activity_recorded', {
      user: this.deps.pseudonym(input.uid),
      source: input.source,
      outcome,
    });
    return outcome;
  }
}
