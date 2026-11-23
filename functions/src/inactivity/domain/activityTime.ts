import { instantOfWallClock } from '../../shared/domain/timeZone';
import type { ReminderPolicy } from './reminderPolicy';

export type ActivitySource = 'session' | 'set';

/**
 * How far the client-reported time was trusted:
 * - `client`: within bounds, used (capped at the arrival time);
 * - `missing` / `invalid`: no usable client time, arrival time used;
 * - `future`: later than arrival + skew (wrong clock or tampering),
 *   arrival time used, so a future date can never postpone reminders;
 * - `too_old`: earlier than arrival - max upload delay (wrong clock or a very
 *   late upload), arrival time used. Deliberately conservative: a real
 *   training session is never mistaken for inactivity because of a bad clock.
 */
export type ActivityTimeQuality = 'client' | 'missing' | 'invalid' | 'future' | 'too_old';

export interface ResolvedActivityTime {
  /** Instant used for scheduling. Never later than [receivedAtMs]. */
  readonly effectiveAtMs: number;
  /** Client-reported occurrence, when it could be parsed. */
  readonly occurredAtMs: number | null;
  /** Server-observed arrival (document creation time). Trusted. */
  readonly receivedAtMs: number;
  readonly quality: ActivityTimeQuality;
}

const OFFSET_LESS_ISO =
  /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,6}))?)?$/;
const WITH_OFFSET_ISO =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,9})?)?(?:Z|[+-]\d{2}:?\d{2})$/;

/**
 * Parses a client timestamp. The app writes Dart `DateTime.toIso8601String()`
 * of a LOCAL time: no offset ("2026-11-07T10:00:00.000"). Such wall-clock
 * strings are interpreted in [timeZone] (the user's preference, or the policy
 * default). Strings with `Z`/an offset, and epoch-millisecond numbers, are
 * absolute. Anything else is invalid.
 */
export function parseClientInstant(value: unknown, timeZone: string): number | null | 'invalid' {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value === 'number') return Number.isFinite(value) ? value : 'invalid';
  if (typeof value !== 'string') return 'invalid';
  const text = value.trim();
  if (WITH_OFFSET_ISO.test(text)) {
    const parsed = Date.parse(text);
    return Number.isFinite(parsed) ? parsed : 'invalid';
  }
  const match = OFFSET_LESS_ISO.exec(text);
  if (match === null) return 'invalid';
  const [, y, mo, d, h, mi, s, frac] = match;
  const wall = {
    year: Number(y),
    month: Number(mo),
    day: Number(d),
    hour: Number(h),
    minute: Number(mi),
    second: s === undefined ? 0 : Number(s),
    millisecond: frac === undefined ? 0 : Number(frac.padEnd(3, '0').slice(0, 3)),
  };
  const probe = new Date(Date.UTC(wall.year, wall.month - 1, wall.day, wall.hour, wall.minute, wall.second));
  if (
    probe.getUTCFullYear() !== wall.year ||
    probe.getUTCMonth() !== wall.month - 1 ||
    probe.getUTCDate() !== wall.day ||
    probe.getUTCHours() !== wall.hour ||
    probe.getUTCMinutes() !== wall.minute
  ) {
    return 'invalid'; // e.g. month 13 or 31 February
  }
  return instantOfWallClock(wall, timeZone);
}

/** Applies the bounded trust policy to one observed activity. */
export function resolveActivityTime(params: {
  readonly occurredAtRaw: unknown;
  readonly receivedAtMs: number;
  readonly timeZone: string;
  readonly policy: ReminderPolicy;
}): ResolvedActivityTime {
  const { receivedAtMs, policy } = params;
  const parsed = parseClientInstant(params.occurredAtRaw, params.timeZone);
  const atArrival = (quality: ActivityTimeQuality, occurredAtMs: number | null): ResolvedActivityTime => ({
    effectiveAtMs: receivedAtMs,
    occurredAtMs,
    receivedAtMs,
    quality,
  });
  if (parsed === null) return atArrival('missing', null);
  if (parsed === 'invalid') return atArrival('invalid', null);
  if (parsed > receivedAtMs + policy.activityClock.maxFutureSkewMs) return atArrival('future', parsed);
  if (parsed < receivedAtMs - policy.activityClock.maxUploadDelayMs) return atArrival('too_old', parsed);
  return {
    effectiveAtMs: Math.min(parsed, receivedAtMs),
    occurredAtMs: parsed,
    receivedAtMs,
    quality: 'client',
  };
}
