import { defaultReminderPolicy as policy } from '../../../src/inactivity/domain/reminderPolicy';
import {
  effectiveTimeZone,
  firstDeliverableAt,
  isWithinDeliveryWindow,
  reminderDueAt,
  waitBeforeReminder,
} from '../../../src/inactivity/domain/reminderSchedule';
import { wallClockAt } from '../../../src/shared/domain/timeZone';
import { DAY, HOUR } from '../../support/inactivityFakes';

const CAIRO = 'Africa/Cairo';
/** Saturday 2026-11-07 18:00 in Cairo (UTC+2). */
const SATURDAY_18_CAIRO = Date.UTC(2026, 10, 7, 16, 0);

describe('reminder cadence', () => {
  test('reminder 1 waits 48 h, reminders 2–5 wait 72 h, 6+ wait 7 days', () => {
    expect(waitBeforeReminder(1, policy)).toBe(48 * HOUR);
    for (const n of [2, 3, 4, 5]) expect(waitBeforeReminder(n, policy)).toBe(72 * HOUR);
    for (const n of [6, 7, 12, 50]) expect(waitBeforeReminder(n, policy)).toBe(7 * DAY);
    expect(() => waitBeforeReminder(0, policy)).toThrow(RangeError);
  });

  test('47:59 is not due; 48:00 is due (at or after the threshold)', () => {
    const due = reminderDueAt({ reminderNumber: 1, lastActivityAtMs: 0, lastReminderSentAtMs: null, policy });
    expect(due).toBe(48 * HOUR);
    expect(47 * HOUR + 59 * 60_000 >= due).toBe(false);
    expect(48 * HOUR >= due).toBe(true);
  });

  test('later reminders are measured from the previous successful send', () => {
    const lastSend = 1_000 * DAY + 17 * 60_000; // a late send (e.g. postponed)
    expect(
      reminderDueAt({ reminderNumber: 3, lastActivityAtMs: 0, lastReminderSentAtMs: lastSend, policy }),
    ).toBe(lastSend + 72 * HOUR);
  });

  test('the approved example from Saturday 18:00', () => {
    const expected = [
      ['Mon', 18], ['Thu', 18], ['Sun', 18], ['Wed', 18], ['Sat', 18], ['Sat', 18], ['Sat', 18],
    ] as const;
    const weekday = (ms: number) =>
      new Intl.DateTimeFormat('en-US', { timeZone: CAIRO, weekday: 'short' }).format(new Date(ms));
    let lastSent: number | null = null;
    const sends: number[] = [];
    for (let n = 1; n <= expected.length; n += 1) {
      const due = reminderDueAt({ reminderNumber: n, lastActivityAtMs: SATURDAY_18_CAIRO, lastReminderSentAtMs: lastSent, policy });
      const sendAt = firstDeliverableAt(due, CAIRO, policy);
      sends.push(sendAt);
      lastSent = sendAt;
    }
    expect(sends.map((ms) => [weekday(ms), wallClockAt(ms, CAIRO).hour])).toEqual(expected);
    expect(sends[5] - sends[4]).toBe(7 * DAY);
    expect(sends[6] - sends[5]).toBe(7 * DAY);
  });
});

describe('quiet hours (10:00–21:00 local)', () => {
  const at = (h: number, mi = 0) => Date.UTC(2026, 10, 9, h - 2, mi); // Cairo wall time on Mon 9 Nov

  test('inside the window is unchanged; 20:59 inside, 21:00 outside', () => {
    expect(firstDeliverableAt(at(10), CAIRO, policy)).toBe(at(10));
    expect(isWithinDeliveryWindow(at(20, 59), CAIRO, policy)).toBe(true);
    expect(isWithinDeliveryWindow(at(21), CAIRO, policy)).toBe(false);
  });

  test('before 10:00 waits until 10:00 the same day; after 21:00 until 10:00 next day', () => {
    expect(firstDeliverableAt(at(3), CAIRO, policy)).toBe(at(10));
    expect(firstDeliverableAt(at(9, 59), CAIRO, policy)).toBe(at(10));
    expect(firstDeliverableAt(at(22), CAIRO, policy)).toBe(at(10) + DAY);
  });

  test('time zones differ: the same instant can be deliverable in one and not another', () => {
    const instant = Date.UTC(2026, 10, 9, 5, 0); // 07:00 Cairo, 00:00 New York, 08:00 Riyadh
    expect(isWithinDeliveryWindow(instant, CAIRO, policy)).toBe(false);
    expect(isWithinDeliveryWindow(instant, 'America/New_York', policy)).toBe(false);
    expect(firstDeliverableAt(instant, 'Asia/Riyadh', policy)).toBe(Date.UTC(2026, 10, 9, 7, 0));
    expect(isWithinDeliveryWindow(Date.UTC(2026, 10, 9, 12, 0), 'Etc/UTC', policy)).toBe(true);
  });

  test('DST: postponing across the spring-forward night lands on 10:00 local', () => {
    // 22:00 EST Saturday 2026-03-07; clocks jump at 02:00 Sunday.
    const lateSaturday = Date.UTC(2026, 2, 8, 3, 0);
    const next = firstDeliverableAt(lateSaturday, 'America/New_York', policy);
    expect(next).toBe(Date.UTC(2026, 2, 8, 14, 0)); // 10:00 EDT (UTC-4)
  });

  test('DST: 72 h are absolute, so local time shifts by the DST change', () => {
    const fridayEst = Date.UTC(2026, 2, 6, 23, 0); // Fri 18:00 EST
    const due = reminderDueAt({ reminderNumber: 2, lastActivityAtMs: 0, lastReminderSentAtMs: fridayEst, policy });
    expect(wallClockAt(due, 'America/New_York')).toMatchObject({ day: 9, hour: 19 }); // Mon 19:00 EDT
  });

  test('invalid or missing time zones fall back to the default', () => {
    expect(effectiveTimeZone('Not/AZone', policy)).toBe(CAIRO);
    expect(effectiveTimeZone(undefined, policy)).toBe(CAIRO);
    expect(effectiveTimeZone('Europe/Paris', policy)).toBe('Europe/Paris');
  });
});
