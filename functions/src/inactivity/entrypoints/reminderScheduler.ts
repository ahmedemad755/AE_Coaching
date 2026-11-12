import { onSchedule } from 'firebase-functions/v2/scheduler';
import { appServices } from '../../compositionRoot';

/**
 * Function timeout. Invariant (tested): the pass's time budget < this
 * timeout < the claim lease, so a live sender can never outlive its lease
 * and a second sender can never take over a claim that is still sending.
 */
export const REMINDER_PASS_TIMEOUT_SECONDS = 540;

/**
 * Hourly delivery pass. One instance at a time; no scheduler retry (the
 * pass is idempotent and the next hourly run continues where this one
 * stopped). Timeout leaves headroom above the pass's own time budget.
 */
export const sendDueInactivityReminders = onSchedule(
  {
    schedule: 'every 60 minutes',
    timeZone: 'Etc/UTC',
    retryCount: 0,
    maxInstances: 1,
    timeoutSeconds: REMINDER_PASS_TIMEOUT_SECONDS,
    memory: '256MiB',
  },
  async () => {
    await appServices().runReminderPass.execute();
  },
);
