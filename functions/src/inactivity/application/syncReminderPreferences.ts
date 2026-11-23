import type { Clock, StructuredLogger } from '../../shared/application/runtimePorts';
import { applyPreferences } from '../domain/inactivityState';
import type { ReminderPolicy } from '../domain/reminderPolicy';
import { resolveReminderPreferences } from '../domain/reminderPreferences';
import type { InactivityStateStore, ReminderPreferencesReader } from './ports';

/**
 * Mirrors the user's notification preferences into the reminder state.
 *
 * It reads the CURRENT preference document instead of trusting the event
 * payload, so delayed or reordered trigger deliveries (off, on, delivered
 * as on, off) always converge on what the user last chose.
 */
export class SyncReminderPreferences {
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

  async execute(uid: string): Promise<void> {
    const { policy } = this.deps;
    const stored = await this.deps.preferences.read(uid);
    const preferences = resolveReminderPreferences(stored, policy);
    const nowMs = this.deps.clock.nowMs();
    await this.deps.store.update(uid, (current) => ({
      next: applyPreferences({ state: current, preferences, fromAppDocument: stored !== null, nowMs, policy }),
      result: undefined,
    }));
    this.deps.logger.info('inactivity_preferences_synced', {
      user: this.deps.pseudonym(uid),
      enabled: preferences.enabled,
      language: preferences.language,
    });
  }
}
