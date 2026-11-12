import { parseClientInstant, resolveActivityTime } from '../../../src/inactivity/domain/activityTime';
import { defaultReminderPolicy as policy } from '../../../src/inactivity/domain/reminderPolicy';
import { HOUR } from '../../support/inactivityFakes';

const CAIRO = 'Africa/Cairo';
const RECEIVED = Date.UTC(2026, 10, 7, 16, 0); // Sat 18:00 Cairo

const resolve = (occurredAtRaw: unknown, receivedAtMs = RECEIVED) =>
  resolveActivityTime({ occurredAtRaw, receivedAtMs, timeZone: CAIRO, policy });

describe('client activity timestamps', () => {
  test("the app's offset-less Dart local time is read in the user's time zone", () => {
    expect(parseClientInstant('2026-11-07T18:00:00.000', CAIRO)).toBe(RECEIVED);
    expect(parseClientInstant('2026-11-07T18:00:00.123456', CAIRO)).toBe(RECEIVED + 123);
    expect(parseClientInstant('2026-11-07T13:00:00.000', 'America/New_York')).toBe(Date.UTC(2026, 10, 7, 18));
  });

  test('UTC/offset strings and epoch numbers are absolute', () => {
    expect(parseClientInstant('2026-11-07T16:00:00.000Z', CAIRO)).toBe(RECEIVED);
    expect(parseClientInstant('2026-11-07T18:00:00+02:00', CAIRO)).toBe(RECEIVED);
    expect(parseClientInstant(RECEIVED, CAIRO)).toBe(RECEIVED);
  });

  test('missing and invalid values are recognized', () => {
    expect(parseClientInstant(undefined, CAIRO)).toBeNull();
    expect(parseClientInstant(null, CAIRO)).toBeNull();
    expect(parseClientInstant('', CAIRO)).toBeNull();
    for (const bad of ['tomorrow', '2026-13-01T10:00:00', '2026-02-30T10:00:00', {}, true, Number.NaN]) {
      expect(parseClientInstant(bad, CAIRO)).toBe('invalid');
    }
  });

  test('an accurate client time is used, capped at arrival', () => {
    const occurred = RECEIVED - 2 * HOUR; // offline for two hours
    expect(resolve(new Date(occurred).toISOString())).toEqual({
      effectiveAtMs: occurred,
      occurredAtMs: occurred,
      receivedAtMs: RECEIVED,
      quality: 'client',
    });
    // Slightly ahead (within skew): never later than arrival.
    expect(resolve(new Date(RECEIVED + 2 * 60_000).toISOString()).effectiveAtMs).toBe(RECEIVED);
  });

  test('future-dated client time cannot postpone reminders', () => {
    const result = resolve(new Date(RECEIVED + 30 * 24 * HOUR).toISOString());
    expect(result).toMatchObject({ effectiveAtMs: RECEIVED, quality: 'future' });
  });

  test('missing or invalid client time falls back to arrival', () => {
    expect(resolve(undefined)).toMatchObject({ effectiveAtMs: RECEIVED, occurredAtMs: null, quality: 'missing' });
    expect(resolve('garbage')).toMatchObject({ effectiveAtMs: RECEIVED, quality: 'invalid' });
  });

  test('bounded late uploads: within 72 h trusted, older treated as arrival', () => {
    const late = RECEIVED - 70 * HOUR;
    expect(resolve(new Date(late).toISOString())).toMatchObject({ effectiveAtMs: late, quality: 'client' });
    const tooOld = RECEIVED - 80 * HOUR;
    expect(resolve(new Date(tooOld).toISOString())).toMatchObject({
      effectiveAtMs: RECEIVED,
      occurredAtMs: tooOld,
      quality: 'too_old',
    });
  });
});
