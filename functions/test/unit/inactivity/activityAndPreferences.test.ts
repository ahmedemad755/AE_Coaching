import { selectReminderMessage } from '../../../src/inactivity/domain/reminderMessages';
import { occurredAtOf } from '../../../src/inactivity/infrastructure/workoutActivityDocuments';
import { pseudonymForLogs } from '../../../src/shared/infrastructure/runtimeAdapters';
import { HOUR, token } from '../../support/inactivityFakes';
import { dartLocalIso, inactivityHarness, SATURDAY_18_CAIRO as ACT } from '../../support/inactivityHarness';

const MIN = 60_000;
const UID = 'user-Q7xZ-private';

function setup() {
  const h = inactivityHarness(ACT);
  h.tokens.byUid.set(UID, [token('phone')]);
  return h;
}

const version = (h: ReturnType<typeof setup>) => h.store.docs.get(UID)?.version ?? 0;

describe('RecordWorkoutActivity', () => {
  test('the first activity creates the state and adopts stored preferences once', async () => {
    const h = setup();
    h.preferences.byUid.set(UID, { inactivityRemindersEnabled: true, language: 'en', timeZone: 'Asia/Riyadh' });
    await expect(h.activity(UID, 'session')).resolves.toBe('started_cycle');
    expect(h.store.get(UID)).toMatchObject({ language: 'en', timeZone: 'Asia/Riyadh', lastActivitySource: 'session' });
    expect(h.preferences.reads).toBe(1);

    h.clock.advance(MIN);
    await h.activity(UID, 'set');
    expect(h.preferences.reads).toBe(1); // no extra read on later activity
  });

  test('a user who turned reminders off has history but nothing scheduled', async () => {
    const h = setup();
    h.preferences.byUid.set(UID, { inactivityRemindersEnabled: false });
    await h.activity(UID, 'set');
    expect(h.store.get(UID)).toMatchObject({ lastActivityAtMs: ACT, enabled: false, nextReminderAtMs: null });
  });

  test('sets 2 and 5 minutes apart each write and push the reminder back', async () => {
    const h = setup();
    await h.activity(UID, 'set');
    h.clock.advance(2 * MIN);
    await expect(h.activity(UID, 'set')).resolves.toBe('started_cycle');
    h.clock.advance(5 * MIN);
    await expect(h.activity(UID, 'set')).resolves.toBe('started_cycle');
    const last = ACT + 7 * MIN;
    expect(h.store.get(UID)).toMatchObject({ lastActivityAtMs: last, nextReminderAtMs: last + 48 * HOUR });

    h.clock.set(ACT + 48 * HOUR); // the first set's due time: nothing yet
    await h.pass.execute();
    expect(h.sender.sends).toHaveLength(0);
    h.clock.set(last + 48 * HOUR);
    await h.pass.execute();
    expect(h.sender.sends).toHaveLength(1);
  });

  test('a session created shortly after a set is recorded as the latest activity', async () => {
    const h = setup();
    await h.activity(UID, 'set');
    h.clock.advance(20_000);
    await expect(h.activity(UID, 'session')).resolves.toBe('started_cycle');
    expect(h.store.get(UID)).toMatchObject({ lastActivitySource: 'session', lastActivityAtMs: ACT + 20_000 });
  });

  test('activity just before a reminder is due prevents that reminder', async () => {
    const h = setup();
    await h.activity(UID, 'set');
    h.clock.set(ACT + 48 * HOUR - MIN);
    await h.activity(UID, 'set');
    h.clock.set(ACT + 48 * HOUR);
    const summary = await h.pass.execute();
    expect(summary.examined).toBe(0);
    expect(h.sender.sends).toHaveLength(0);
    expect(h.store.get(UID)?.nextReminderAtMs).toBe(ACT + 96 * HOUR - MIN);
  });

  test('duplicate trigger delivery writes nothing', async () => {
    const h = setup();
    const occurredAtRaw = dartLocalIso(ACT);
    await h.record.execute({ uid: UID, source: 'set', occurredAtRaw, receivedAtMs: ACT });
    const before = version(h);
    await expect(h.record.execute({ uid: UID, source: 'set', occurredAtRaw, receivedAtMs: ACT })).resolves.toBe('not_newer');
    expect(version(h)).toBe(before);
  });

  test('an older set uploaded late never rolls the clock back', async () => {
    const h = setup();
    h.clock.set(ACT + 3 * HOUR);
    await h.activity(UID, 'session');
    h.clock.set(ACT + 4 * HOUR);
    // Recorded offline at ACT, uploaded after a newer session.
    await expect(h.activity(UID, 'set', dartLocalIso(ACT))).resolves.toBe('not_newer');
    expect(h.store.get(UID)?.lastActivityAtMs).toBe(ACT + 3 * HOUR);
  });

  test('offline activity uploaded later counts from when it happened (bounded)', async () => {
    const h = setup();
    h.clock.set(ACT + 5 * HOUR); // uploaded five hours after the workout
    await h.activity(UID, 'set', dartLocalIso(ACT));
    expect(h.store.get(UID)).toMatchObject({
      lastActivityAtMs: ACT,
      lastActivityOccurredAtMs: ACT,
      lastActivityReceivedAtMs: ACT + 5 * HOUR,
      nextReminderAtMs: ACT + 48 * HOUR,
    });
  });

  test('missing or future client timestamps use the server arrival time', async () => {
    const h = setup();
    await h.activity(UID, 'set', null); // what occurredAtOf returns for a missing field
    expect(h.store.get(UID)).toMatchObject({ lastActivityAtMs: ACT, lastActivityTimeQuality: 'missing' });
    h.clock.advance(HOUR);
    await h.activity(UID, 'set', dartLocalIso(ACT + 40 * 24 * HOUR));
    expect(h.store.get(UID)).toMatchObject({ lastActivityAtMs: ACT + HOUR, lastActivityTimeQuality: 'future' });
  });

  test('logs identify users only pseudonymously', async () => {
    const h = setup();
    await h.activity(UID, 'set');
    expect(h.logger.text()).not.toContain(UID);
    expect(h.logger.text()).toContain(pseudonymForLogs(UID));
  });

  test('occurrence time comes from the documents the app already writes', () => {
    expect(occurredAtOf('session', { startedAt: 'a', date: 'b' })).toBe('a');
    expect(occurredAtOf('session', { date: 'b' })).toBe('b');
    expect(occurredAtOf('set', { date: 'c', startedAt: 'x' })).toBe('c');
    expect(occurredAtOf('set', {})).toBeNull();
  });
});

describe('SyncReminderPreferences', () => {
  test('disabled users are never selected or sent to', async () => {
    const h = setup();
    await h.activity(UID, 'set');
    h.preferences.byUid.set(UID, { inactivityRemindersEnabled: false });
    await h.sync.execute(UID);
    for (const days of [2, 5, 8, 30]) {
      h.clock.set(ACT + days * 24 * HOUR);
      const summary = await h.pass.execute();
      expect(summary.examined).toBe(0);
    }
    expect(h.sender.sends).toHaveLength(0);
  });

  test('re-enabling keeps activity and count, and waits 48 h before the overdue reminder', async () => {
    const h = setup();
    await h.activity(UID, 'set');
    h.clock.set(ACT + 48 * HOUR);
    await h.pass.execute(); // reminder 1 (Monday 18:00)
    h.preferences.byUid.set(UID, { inactivityRemindersEnabled: false });
    await h.sync.execute(UID);
    h.clock.set(ACT + 10 * 24 * HOUR + 2 * HOUR); // Tue 20:00, ten days later
    h.preferences.byUid.set(UID, { inactivityRemindersEnabled: true });
    await h.sync.execute(UID);
    const reEnabledAt = ACT + 10 * 24 * HOUR + 2 * HOUR;
    expect(h.store.get(UID)).toMatchObject({
      remindersSentInCycle: 1,
      lastActivityAtMs: ACT,
      nextReminderAtMs: reEnabledAt + 48 * HOUR, // Thu 20:00
    });
    await h.pass.execute();
    h.clock.set(reEnabledAt + 47 * HOUR);
    await h.pass.execute();
    expect(h.sender.sends).toHaveLength(1); // nothing during the grace period
    h.clock.set(reEnabledAt + 48 * HOUR);
    await h.pass.execute();
    expect(h.sender.sends.map((s) => s.attemptId)).toEqual([`c${ACT}:r1`, `c${ACT}:r2`]);
  });

  test('reordered or repeated trigger deliveries converge on the stored choice', async () => {
    const h = setup();
    await h.activity(UID, 'set');
    h.preferences.byUid.set(UID, { inactivityRemindersEnabled: false });
    await h.sync.execute(UID); // the "on" event delivered late still reads "off"
    await h.sync.execute(UID);
    expect(h.store.get(UID)).toMatchObject({ enabled: false, nextReminderAtMs: null });
  });

  test('preferences saved before any workout create no reminder; the first workout uses them', async () => {
    const h = setup();
    h.preferences.byUid.set(UID, { language: 'en' });
    await h.sync.execute(UID);
    expect(h.store.get(UID)).toMatchObject({ lastActivityAtMs: null, nextReminderAtMs: null, language: 'en' });
    await h.activity(UID, 'session');
    h.clock.set(ACT + 48 * HOUR);
    await h.pass.execute();
    expect(h.sender.sends[0].message).toEqual(selectReminderMessage('en', 1));
  });

  test('missing or invalid preference values fall back to the app defaults', async () => {
    const h = setup();
    await h.activity(UID, 'set');
    h.preferences.byUid.set(UID, { inactivityRemindersEnabled: 'no', language: 'fr', timeZone: 'Mars/Base' });
    await h.sync.execute(UID);
    expect(h.store.get(UID)).toMatchObject({ enabled: true, language: 'ar', timeZone: 'Africa/Cairo' });
  });
});
