/**
 * IANA time-zone arithmetic on UTC instants (epoch milliseconds), built on
 * the standard `Intl` API only (no Firebase, no third-party libraries).
 *
 * Instants are always UTC milliseconds. "Wall-clock" values are the local
 * calendar fields a person in that zone would read on a clock.
 */

export interface WallClock {
  readonly year: number;
  /** 1–12 */
  readonly month: number;
  readonly day: number;
  readonly hour: number;
  readonly minute: number;
  readonly second: number;
  readonly millisecond: number;
}

/** Whether [timeZone] is an IANA zone this runtime can evaluate. */
export function isValidTimeZone(timeZone: unknown): timeZone is string {
  if (typeof timeZone !== 'string' || timeZone.length === 0 || timeZone.length > 64) {
    return false;
  }
  try {
    new Intl.DateTimeFormat('en-US', { timeZone });
    return true;
  } catch {
    return false;
  }
}

function formatterFor(timeZone: string): Intl.DateTimeFormat {
  return new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

/** The local wall clock in [timeZone] at [instantMs]. */
export function wallClockAt(instantMs: number, timeZone: string): WallClock {
  const parts = formatterFor(timeZone).formatToParts(new Date(instantMs));
  const field = (type: Intl.DateTimeFormatPartTypes): number => {
    const part = parts.find((p) => p.type === type);
    if (part === undefined) throw new RangeError(`Missing ${type} for ${timeZone}`);
    return Number(part.value);
  };
  return {
    year: field('year'),
    month: field('month'),
    day: field('day'),
    hour: field('hour'),
    minute: field('minute'),
    second: field('second'),
    millisecond: ((instantMs % 1000) + 1000) % 1000,
  };
}

function wallAsUtcMs(wall: WallClock): number {
  return Date.UTC(
    wall.year,
    wall.month - 1,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
  );
}

/** UTC offset of [timeZone] at [instantMs], in milliseconds (east positive). */
export function utcOffsetAt(instantMs: number, timeZone: string): number {
  const wall = wallClockAt(instantMs, timeZone);
  return wallAsUtcMs({ ...wall, millisecond: 0 }) - (instantMs - wall.millisecond);
}

/**
 * The UTC instant at which [timeZone]'s clocks show [wall].
 *
 * Daylight-saving transitions are resolved deterministically:
 * - a wall time that occurs twice (clocks go back) maps to the EARLIER
 *   instant;
 * - a wall time that never occurs (clocks go forward) maps to the instant
 *   the same distance after the transition, i.e. it moves forward by the
 *   size of the gap (02:30 in a 02:00→03:00 gap becomes 03:30).
 */
export function instantOfWallClock(wall: WallClock, timeZone: string): number {
  const asUtc = wallAsUtcMs(wall);
  // Offsets in effect just before and after the candidate region; at most two
  // distinct offsets exist around any single transition.
  const offsetBefore = utcOffsetAt(asUtc - 36 * 3600_000, timeZone);
  const offsetAfter = utcOffsetAt(asUtc + 36 * 3600_000, timeZone);
  const candidates = [asUtc - Math.max(offsetBefore, offsetAfter), asUtc - Math.min(offsetBefore, offsetAfter)];
  const matching = candidates.filter((instant) => wallAsUtcMs(wallClockAt(instant, timeZone)) === asUtc);
  if (matching.length > 0) return Math.min(...matching);
  // Non-existent local time: shift forward by the gap.
  return asUtc - offsetBefore;
}

/** [wall] moved by whole calendar days, normalising month/year rollover. */
export function addCalendarDays(wall: WallClock, days: number): WallClock {
  const date = new Date(Date.UTC(wall.year, wall.month - 1, wall.day + days));
  return {
    ...wall,
    year: date.getUTCFullYear(),
    month: date.getUTCMonth() + 1,
    day: date.getUTCDate(),
  };
}
