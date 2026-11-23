import { RunReminderPass } from '../../../src/inactivity/application/runReminderPass';
import { wallClockAt } from '../../../src/shared/domain/timeZone';
import { DAY, HOUR, token } from '../../support/inactivityFakes';
import { inactivityHarness, SATURDAY_18_CAIRO as ACT } from '../../support/inactivityHarness';

const MIN = 60_000;

async function usersWithWorkoutAt(h: ReturnType<typeof inactivityHarness>, count: number, at = ACT) {
  const uids = Array.from({ length: count }, (_, i) => `u${String(i).padStart(3, '0')}`);
  h.clock.set(at);
  for (const uid of uids) {
    h.tokens.byUid.set(uid, [token(`t-${uid}`)]);
    await h.activity(uid, 'set');
  }
  return uids;
}

/** Runs the scheduler at the top of every hour in [fromMs, toMs]. */
async function runHourly(h: ReturnType<typeof inactivityHarness>, fromMs: number, toMs: number) {
  for (let at = Math.ceil(fromMs / HOUR) * HOUR; at <= toMs; at += HOUR) {
    h.clock.set(at);
    await h.pass.execute();
  }
}

describe('RunReminderPass', () => {
  test('pages through every due user once; users not due are never touched', async () => {
    const h = inactivityHarness(ACT, { pageSize: 10, concurrency: 3 });
    const due = await usersWithWorkoutAt(h, 25);
    await usersWithWorkoutAt(h, 0);
    h.clock.set(ACT + 47 * HOUR);
    h.tokens.byUid.set('later', [token('t-later')]);
    await h.activity('later', 'set');

    h.clock.set(ACT + 48 * HOUR);
    const summary = await h.pass.execute();
    expect(summary).toMatchObject({ examined: 25, sent: 25, stoppedEarly: false });
    expect(h.finder.queries).toBe(3);
    const recipients = h.sender.sends.map((s) => s.tokens[0].id).sort();
    expect(recipients).toEqual(due.map((uid) => `t-${uid}`));
  });

  test('overlapping scheduler runs never send a user two reminders', async () => {
    const h = inactivityHarness(ACT, { pageSize: 7, concurrency: 4 });
    await usersWithWorkoutAt(h, 30);
    h.clock.set(ACT + 48 * HOUR);
    const [a, b] = await Promise.all([h.pass.execute(), h.pass.execute()]);
    expect(a.sent + b.sent).toBe(30);
    expect(h.sender.sends).toHaveLength(30);
    expect(new Set(h.sender.sends.map((s) => s.attemptId + s.tokens[0].id)).size).toBe(30);
  });

  test('a per-run cap leaves the rest for the next run', async () => {
    const h = inactivityHarness(ACT, { pageSize: 5, concurrency: 2, maxUsersPerRun: 7 });
    await usersWithWorkoutAt(h, 12);
    h.clock.set(ACT + 48 * HOUR);
    expect(await h.pass.execute()).toMatchObject({ examined: 7, sent: 7, stoppedEarly: true });
    h.clock.advance(HOUR);
    expect(await h.pass.execute()).toMatchObject({ examined: 5, sent: 5, stoppedEarly: false });
  });

  test('stops starting work when the time budget is spent', async () => {
    const h = inactivityHarness(ACT);
    await usersWithWorkoutAt(h, 6);
    h.clock.set(ACT + 48 * HOUR);
    const slow = {
      execute: async (uid: string) => {
        h.clock.advance(3 * MIN); // each user "takes" three minutes
        return h.deliver.execute(uid);
      },
    };
    const pass = new RunReminderPass({
      finder: h.finder,
      deliver: slow,
      gate: h.gate,
      clock: h.clock,
      logger: h.logger,
      limits: { pageSize: 10, concurrency: 1, maxUsersPerRun: 100, timeBudgetMs: 7 * MIN },
    });
    expect(await pass.execute()).toMatchObject({ examined: 3, stoppedEarly: true });
  });

  test('one failing user does not stop the pass', async () => {
    const h = inactivityHarness(ACT);
    const uids = await usersWithWorkoutAt(h, 4);
    h.clock.set(ACT + 48 * HOUR);
    const flaky = {
      execute: (uid: string) => (uid === uids[1] ? Promise.reject(new Error('boom')) : h.deliver.execute(uid)),
    };
    const pass = new RunReminderPass({
      finder: h.finder,
      deliver: flaky,
      gate: h.gate,
      clock: h.clock,
      logger: h.logger,
      limits: { pageSize: 10, concurrency: 2, maxUsersPerRun: 100, timeBudgetMs: 7 * MIN },
    });
    expect(await pass.execute()).toMatchObject({ examined: 4, sent: 3, error: 1 });
  });

  test('hourly runs reproduce the approved cadence, and a workout resets it', async () => {
    const h = inactivityHarness(ACT);
    const sentAt: number[] = [];
    h.sender.duringSend = async () => {
      sentAt.push(h.clock.nowMs());
    };
    await usersWithWorkoutAt(h, 1); // Saturday 18:00
    await runHourly(h, ACT, ACT + 34 * DAY);

    const weekday = (ms: number) =>
      new Intl.DateTimeFormat('en-US', { timeZone: 'Africa/Cairo', weekday: 'short' }).format(new Date(ms));
    expect(sentAt.map((ms) => `${weekday(ms)} ${wallClockAt(ms, 'Africa/Cairo').hour}:00`)).toEqual([
      'Mon 18:00', 'Thu 18:00', 'Sun 18:00', 'Wed 18:00', 'Sat 18:00', 'Sat 18:00', 'Sat 18:00',
    ]);
    expect(sentAt.map((ms) => (ms - ACT) / DAY)).toEqual([2, 5, 8, 11, 14, 21, 28]);
    expect(h.sender.sends.map((s) => s.attemptId)).toEqual(Array.from({ length: 7 }, (_, i) => `c${ACT}:r${i + 1}`));

    // A workout on Monday 09:30 starts over: +48 h lands at 09:30 Wednesday,
    // inside quiet hours, so the 10:00 run sends it; the next follows 72 h later.
    const monday = Date.UTC(2026, 11, 14, 7, 30);
    h.clock.set(monday);
    await h.activity('u000', 'session');
    sentAt.length = 0;
    await runHourly(h, monday, monday + 6 * DAY);
    const firstAfterReset = monday + 48 * HOUR + 30 * MIN;
    expect(sentAt).toEqual([firstAfterReset, firstAfterReset + 72 * HOUR]);
    expect(h.sender.sends.at(-1)?.attemptId).toBe(`c${monday}:r2`);
  });
});
