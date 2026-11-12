import { addCalendarDays, instantOfWallClock, isValidTimeZone, wallClockAt } from '../../shared/domain/timeZone';
import type { ReminderPolicy } from './reminderPolicy';

/** How long reminder [reminderNumber] (1-based) waits after its anchor. */
export function waitBeforeReminder(reminderNumber: number, policy: ReminderPolicy): number {
  if (!Number.isInteger(reminderNumber) || reminderNumber < 1) {
    throw new RangeError(`Invalid reminder number: ${reminderNumber}`);
  }
  for (const step of policy.cadence.steps) {
    if (reminderNumber <= step.throughReminder) return step.waitMs;
  }
  return policy.cadence.thereafterWaitMs;
}

/**
 * When reminder [reminderNumber] becomes due (before quiet hours): the first
 * waits from the latest activity, later ones from the previous successful
 * send. Due means "at or after this instant".
 */
export function reminderDueAt(params: {
  readonly reminderNumber: number;
  readonly lastActivityAtMs: number;
  readonly lastReminderSentAtMs: number | null;
  readonly policy: ReminderPolicy;
}): number {
  const anchor =
    params.reminderNumber === 1 || params.lastReminderSentAtMs === null
      ? params.lastActivityAtMs
      : params.lastReminderSentAtMs;
  return anchor + waitBeforeReminder(params.reminderNumber, params.policy);
}

/** [timeZone] when valid, otherwise the policy default. */
export function effectiveTimeZone(timeZone: unknown, policy: ReminderPolicy): string {
  return isValidTimeZone(timeZone) ? timeZone : policy.defaults.timeZone;
}

/**
 * The earliest instant at or after [instantMs] that falls inside the local
 * delivery window [startHour, endHour) of [timeZone]. DST-safe: the window
 * start is resolved per calendar day in that zone.
 */
export function firstDeliverableAt(instantMs: number, timeZone: string, policy: ReminderPolicy): number {
  const { startHour, endHour } = policy.quietHours;
  const local = wallClockAt(instantMs, timeZone);
  if (local.hour >= startHour && local.hour < endHour) return instantMs;
  const windowDay = local.hour < startHour ? local : addCalendarDays(local, 1);
  return instantOfWallClock(
    { ...windowDay, hour: startHour, minute: 0, second: 0, millisecond: 0 },
    timeZone,
  );
}

/** Whether [instantMs] is inside the delivery window of [timeZone]. */
export function isWithinDeliveryWindow(instantMs: number, timeZone: string, policy: ReminderPolicy): boolean {
  return firstDeliverableAt(instantMs, timeZone, policy) === instantMs;
}

/** FNV-1a (32-bit): a small, stable, platform-independent string hash. */
function stableHash(text: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < text.length; i += 1) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

/**
 * Where a backlogged reminder goes: a slot inside the delivery windows of
 * the next `policy.delivery.backlog.spreadDays` local days (never today),
 * chosen from [key] so the same reminder always gets the same slot. Spreads
 * a backlog evenly instead of sending it at once. Slots stop an hour before
 * quiet hours begin, so the hourly run that picks a slot up (up to an hour
 * later) is still inside the delivery window.
 */
export function backlogSlotAt(params: {
  readonly key: string;
  readonly nowMs: number;
  readonly timeZone: string;
  readonly policy: ReminderPolicy;
}): number {
  const { key, nowMs, timeZone, policy } = params;
  const { startHour, endHour } = policy.quietHours;
  const windowMinutes = Math.max(1, endHour - startHour - 1) * 60;
  const slot = stableHash(key) % (policy.delivery.backlog.spreadDays * windowMinutes);
  const today = wallClockAt(nowMs, timeZone);
  const day = addCalendarDays({ ...today, hour: 0, minute: 0, second: 0, millisecond: 0 }, 1 + Math.floor(slot / windowMinutes));
  const minuteOfWindow = slot % windowMinutes;
  return instantOfWallClock(
    { ...day, hour: startHour + Math.floor(minuteOfWindow / 60), minute: minuteOfWindow % 60 },
    timeZone,
  );
}
