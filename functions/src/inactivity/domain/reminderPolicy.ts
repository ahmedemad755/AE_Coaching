/**
 * Every business rule of workout inactivity reminders, as data. Changing the
 * cadence, quiet hours or retry policy means changing this object, not the
 * scheduling, sending or storage code.
 */

export type ReminderLanguage = 'ar' | 'en';

const HOUR_MS = 3600_000;
const DAY_MS = 24 * HOUR_MS;

/** Wait before reminder N, measured from the previous anchor. */
export interface CadenceStep {
  /** Applies to reminders up to and including this number (1-based). */
  readonly throughReminder: number;
  readonly waitMs: number;
}

export interface ReminderPolicy {
  readonly cadence: {
    /**
     * Ordered steps. Reminder 1 waits from the latest activity; later
     * reminders wait from the previous successful send.
     */
    readonly steps: readonly CadenceStep[];
    /** Wait for every reminder after the last step. */
    readonly thereafterWaitMs: number;
    /**
     * After a user turns reminders back on, nothing is sent for this long,
     * even when the cadence is already due. Activity and the reminder
     * sequence are not reset.
     */
    readonly reactivationGraceMs: number;
  };
  /** Local delivery window [startHour, endHour) in the user's time zone. */
  readonly quietHours: { readonly startHour: number; readonly endHour: number };
  /** Used when a user has no valid preference. */
  readonly defaults: {
    readonly enabled: boolean;
    readonly language: ReminderLanguage;
    readonly timeZone: string;
  };
  /** Bounds for client-reported activity times (see activityTime.ts). */
  readonly activityClock: {
    /** Client times later than arrival + this are treated as untrusted. */
    readonly maxFutureSkewMs: number;
    /** Client times earlier than arrival - this are treated as untrusted. */
    readonly maxUploadDelayMs: number;
  };
  readonly delivery: {
    /** How long a claim blocks other senders; longer than one function run. */
    readonly leaseMs: number;
    /** Re-check a user with no deliverable device after this long. */
    readonly noDeviceRetryMs: number;
    /** Backoff after consecutive retryable failures (last value repeats). */
    readonly retryBackoffMs: readonly number[];
    /**
     * A reminder more than [overdueAfterMs] past its scheduled send time
     * (delivery gate closed, scheduler outage, or an upgrade confirming a
     * long-overdue user) is not sent at once: it moves to a stable slot in
     * the delivery windows of the next [spreadDays] local days. Normal
     * lateness (hourly runs, quiet-hours postponement) stays well below it.
     */
    readonly backlog: { readonly overdueAfterMs: number; readonly spreadDays: number };
  };
}

/** Approved product rules (Stage 1; re-enable grace period: Stage 2). */
export const defaultReminderPolicy: ReminderPolicy = {
  cadence: {
    steps: [
      { throughReminder: 1, waitMs: 48 * HOUR_MS },
      { throughReminder: 5, waitMs: 72 * HOUR_MS },
    ],
    thereafterWaitMs: 7 * DAY_MS,
    reactivationGraceMs: 48 * HOUR_MS,
  },
  quietHours: { startHour: 10, endHour: 21 },
  // The app defaults reminders ON (InactivityReminderService) and Arabic
  // (LocaleCubit); its users are primarily in Egypt.
  defaults: { enabled: true, language: 'ar', timeZone: 'Africa/Cairo' },
  activityClock: { maxFutureSkewMs: 5 * 60_000, maxUploadDelayMs: 72 * HOUR_MS },
  delivery: {
    leaseMs: 15 * 60_000,
    noDeviceRetryMs: DAY_MS,
    retryBackoffMs: [HOUR_MS, 2 * HOUR_MS, 4 * HOUR_MS, 8 * HOUR_MS, DAY_MS],
    backlog: { overdueAfterMs: 6 * HOUR_MS, spreadDays: 3 },
  },
};
