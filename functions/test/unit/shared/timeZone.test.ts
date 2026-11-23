import {
  addCalendarDays,
  instantOfWallClock,
  isValidTimeZone,
  utcOffsetAt,
  wallClockAt,
} from '../../../src/shared/domain/timeZone';

const wall = (y: number, mo: number, d: number, h: number, mi = 0) => ({
  year: y,
  month: mo,
  day: d,
  hour: h,
  minute: mi,
  second: 0,
  millisecond: 0,
});

describe('time zones', () => {
  test('validates IANA names', () => {
    expect(isValidTimeZone('Africa/Cairo')).toBe(true);
    expect(isValidTimeZone('America/New_York')).toBe(true);
    expect(isValidTimeZone('Mars/Olympus')).toBe(false);
    expect(isValidTimeZone('')).toBe(false);
    expect(isValidTimeZone(42)).toBe(false);
  });

  test('wall clock and offset in Cairo (winter, UTC+2)', () => {
    const instant = Date.UTC(2026, 10, 7, 16, 0);
    expect(wallClockAt(instant, 'Africa/Cairo')).toMatchObject({ year: 2026, month: 11, day: 7, hour: 18 });
    expect(utcOffsetAt(instant, 'Africa/Cairo')).toBe(2 * 3600_000);
    expect(instantOfWallClock(wall(2026, 11, 7, 18), 'Africa/Cairo')).toBe(instant);
  });

  test('round-trips across a year in several zones', () => {
    for (const zone of ['Africa/Cairo', 'America/New_York', 'Europe/London', 'Asia/Riyadh', 'Etc/UTC']) {
      for (let day = 0; day < 365; day += 11) {
        const instant = Date.UTC(2026, 0, 1, 12, 34) + day * 86_400_000;
        const local = wallClockAt(instant, zone);
        expect(instantOfWallClock({ ...local, millisecond: 0 }, zone)).toBe(instant);
      }
    }
  });

  test('DST gap (New York, 2026-03-08 02:30 does not exist) moves forward', () => {
    const resolved = instantOfWallClock(wall(2026, 3, 8, 2, 30), 'America/New_York');
    expect(wallClockAt(resolved, 'America/New_York')).toMatchObject({ hour: 3, minute: 30 });
  });

  test('DST overlap (New York, 2026-11-01 01:30 occurs twice) picks the earlier', () => {
    const resolved = instantOfWallClock(wall(2026, 11, 1, 1, 30), 'America/New_York');
    expect(resolved).toBe(Date.UTC(2026, 10, 1, 5, 30)); // 01:30 EDT (UTC-4)
  });

  test('calendar days roll over months and years', () => {
    expect(addCalendarDays(wall(2026, 12, 31, 10), 1)).toMatchObject({ year: 2027, month: 1, day: 1, hour: 10 });
  });
});
