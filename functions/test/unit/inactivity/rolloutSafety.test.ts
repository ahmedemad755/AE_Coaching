import { DeliverDueReminder } from '../../../src/inactivity/application/deliverDueReminder';
import { CLOSED_DELIVERY_GATE } from '../../../src/inactivity/domain/deliveryGate';
import { applyActivity, applyPreferences, decideClaim } from '../../../src/inactivity/domain/inactivityState';
import { defaultReminderPolicy as policy } from '../../../src/inactivity/domain/reminderPolicy';
import { resolveReminderPreferences } from '../../../src/inactivity/domain/reminderPreferences';
import { backlogSlotAt, isWithinDeliveryWindow } from '../../../src/inactivity/domain/reminderSchedule';
import { pseudonymForLogs } from '../../../src/shared/infrastructure/runtimeAdapters';
import { wallClockAt } from '../../../src/shared/domain/timeZone';
import { DeliverableTokenDirectory } from '../../../src/tokens/application/deliverableTokenDirectory';
import { ReconcileTokenOwnership } from '../../../src/tokens/application/reconcileTokenOwnership';
import { DAY, HOUR, RecordingLogger, token } from '../../support/inactivityFakes';
import { dartLocalIso, inactivityHarness, SATURDAY_18_CAIRO as ACT } from '../../support/inactivityHarness';
import { InMemoryTokenRegistry, InMemoryUserTokens } from '../../support/tokenFakes';

const CAIRO = 'Africa/Cairo';
const DUE = ACT + 48 * HOUR; // Monday 18:00 Cairo
const defaults = resolveReminderPreferences(null, policy);
const localDay = (ms: number) => {
  const w = wallClockAt(ms, CAIRO);
  return `${w.year}-${w.month}-${w.day}`;
};

describe('per-device readiness (mixed app versions on one account)', () => {
  async function accountWithDevices() {
    const h = inactivityHarness(ACT);
    const registry = new InMemoryTokenRegistry();
    const userTokens = new InMemoryUserTokens();
    const reconcile = new ReconcileTokenOwnership({ registry, userTokens, logger: new RecordingLogger(), pseudonym: pseudonymForLogs });
    const deliver = new DeliverDueReminder({
      store: h.store,
      tokens: new DeliverableTokenDirectory({ registry, userTokens }),
      sender: h.sender,
      clock: h.clock,
      ids: h.ids,
      logger: h.logger,
      policy: h.policy,
      pseudonym: pseudonymForLogs,
    });
    const device = async (raw: string, ready: boolean, updatedAtMs = 100, readyAtMs?: number) => {
      const id = userTokens.register('A', raw, updatedAtMs, 'android', ready);
      if (readyAtMs !== undefined) {
        userTokens.putRaw('A', id, { token: raw, platform: 'android', updatedAtMs, serverRemindersReadyAtMs: readyAtMs }, updatedAtMs);
      }
      await reconcile.onRegistered({ uid: 'A', tokenId: id, registeredAtMs: updatedAtMs });
      return id;
    };
    await h.activity('A', 'set');
    h.clock.set(DUE);
    return { h, deliver, userTokens, device };
  }

  test('only devices whose latest registration confirmed readiness receive the reminder', async () => {
    const { h, deliver, userTokens, device } = await accountWithDevices();
    const phone = await device('new-build-phone', true);
    const tablet = await device('old-build-tablet', false); // still schedules its local reminder
    const downgraded = await device('downgraded', false, 900, 100); // older build registered last
    await expect(deliver.execute('A')).resolves.toBe('sent');
    expect(h.sender.sends.map((s) => s.tokens.map((t) => t.id))).toEqual([[phone]]);
    // Not-ready devices are kept (owned, just not eligible), never deleted.
    expect(userTokens.ids('A').sort()).toEqual([phone, tablet, downgraded].sort());
  });

  test('an account whose devices are all on older builds gets nothing', async () => {
    const { h, deliver, userTokens, device } = await accountWithDevices();
    const tablet = await device('old-build-tablet', false);
    await expect(deliver.execute('A')).resolves.toBe('no_deliverable_device');
    expect(h.sender.sends).toHaveLength(0);
    expect(h.store.get('A')?.remindersSentInCycle).toBe(0);
    expect(userTokens.ids('A')).toEqual([tablet]);
  });
});

describe('backlog spreading', () => {
  test('slots are deterministic, inside 10:00–21:00 local, on the next 1–3 days', () => {
    const now = Date.UTC(2026, 10, 17, 10, 0); // Tue 12:00 Cairo
    const days = new Set<string>();
    for (let i = 0; i < 300; i += 1) {
      const slot = backlogSlotAt({ key: `c${i}:r1`, nowMs: now, timeZone: CAIRO, policy });
      expect(backlogSlotAt({ key: `c${i}:r1`, nowMs: now, timeZone: CAIRO, policy })).toBe(slot);
      expect(isWithinDeliveryWindow(slot, CAIRO, policy)).toBe(true);
      // The hourly run that picks it up (≤ 1 h later) is still in the window.
      expect(isWithinDeliveryWindow(slot + HOUR - 1, CAIRO, policy)).toBe(true);
      expect(slot).toBeGreaterThan(Date.UTC(2026, 10, 17, 22, 0)); // after today (midnight Cairo)
      expect(slot).toBeLessThan(Date.UTC(2026, 10, 20, 19, 0)); // before Fri 21:00 Cairo
      days.add(localDay(slot));
    }
    expect([...days].sort()).toEqual(['2026-11-18', '2026-11-19', '2026-11-20']);
  });

  const stateDueAt = (activityAtMs: number) =>
    applyActivity({
      state: applyPreferences({ fromAppDocument: true, state: null, preferences: defaults, nowMs: 0, policy }),
      source: 'set',
      occurredAtRaw: dartLocalIso(activityAtMs),
      receivedAtMs: activityAtMs,
      defaultPreferences: defaults,
      nowMs: activityAtMs,
      policy,
    }).state;

  test('up to 6 h late is normal; later than that is backlog', () => {
    const state = stateDueAt(ACT - 8 * HOUR); // due Mon 10:00 Cairo
    const scheduled = state.nextReminderAtMs ?? Number.NaN;
    expect(decideClaim({ uid: 'u', state, nowMs: scheduled + 6 * HOUR, leaseId: 'x', policy }).kind).toBe('claim');
    const late = decideClaim({ uid: 'u', state, nowMs: scheduled + 6 * HOUR + 1, leaseId: 'x', policy });
    expect(late).toMatchObject({ kind: 'postpone', reason: 'backlog' });
    if (late.kind !== 'postpone') return;
    // Only the send time moved: the reminder number and anchors are kept.
    expect(late.state).toMatchObject({
      remindersSentInCycle: 0,
      lastActivityAtMs: state.lastActivityAtMs,
      nextReminderDueAtMs: state.nextReminderDueAtMs,
    });
    expect(isWithinDeliveryWindow(late.state.nextReminderAtMs ?? 0, CAIRO, policy)).toBe(true);
  });

  test('users with the same activity time (same attempt id) get different slots', () => {
    const state = stateDueAt(ACT - 8 * HOUR);
    const late = (state.nextReminderAtMs ?? 0) + 7 * HOUR;
    const slots = Array.from({ length: 50 }, (_, i) => {
      const decision = decideClaim({ uid: `user-${i}`, state, nowMs: late, leaseId: 'x', policy });
      return decision.kind === 'postpone' ? decision.state.nextReminderAtMs : null;
    });
    expect(slots.every((slot) => slot !== null)).toBe(true);
    expect(new Set(slots).size).toBeGreaterThan(40);
    expect(new Set(slots.map((slot) => localDay(slot ?? 0))).size).toBe(3);
  });

  test('normal lateness that lands in quiet hours is still a quiet-hours postponement', () => {
    const state = stateDueAt(ACT + 2 * HOUR + 30 * 60_000); // due Mon 20:30 Cairo
    const scheduled = state.nextReminderAtMs ?? Number.NaN;
    expect(decideClaim({ uid: 'u', state, nowMs: scheduled + HOUR, leaseId: 'x', policy })).toMatchObject({
      kind: 'postpone',
      reason: 'quiet_hours',
    });
  });
});

describe('bounded sending', () => {
  test('a pass sends exactly up to the budget; skipped users do not consume it', async () => {
    const h = inactivityHarness(ACT - 6 * HOUR, { concurrency: 10 }); // due Mon 12:00 Cairo
    const due = ACT - 6 * HOUR + 48 * HOUR;
    for (let i = 0; i < 25; i += 1) {
      const uid = `u${String(i).padStart(2, '0')}`;
      h.tokens.byUid.set(uid, [token(uid)]);
      await h.activity(uid, 'set');
    }
    h.gate.gate = { mode: 'allowlist', uids: ['nobody-due', 'u00', 'u01', 'u02', 'u03', 'u04', 'u05', 'u06', 'u07'], maxSendsPerPass: 7 };
    h.clock.set(due);
    expect(await h.pass.execute()).toMatchObject({ sent: 7, skipped: 1, stoppedEarly: true });

    h.gate.gate = { mode: 'all', maxSendsPerPass: 7 };
    h.clock.set(due + HOUR);
    expect(await h.pass.execute()).toMatchObject({ sent: 7, stoppedEarly: true });
    h.clock.set(due + 2 * HOUR);
    expect(await h.pass.execute()).toMatchObject({ sent: 7 });
    h.clock.set(due + 3 * HOUR);
    expect(await h.pass.execute()).toMatchObject({ sent: 4, stoppedEarly: false });
    expect(h.sender.sends).toHaveLength(25);
  });
});

describe('opening the gate after a long closure', () => {
  test('the backlog is spread over the next 3 days within budget; fresh reminders go out normally', async () => {
    const h = inactivityHarness(ACT);
    const sentAt = new Map<string, number[]>();
    h.sender.duringSend = async () => {
      const uid = h.sender.sends.at(-1)?.tokens[0].id ?? '';
      sentAt.set(uid, [...(sentAt.get(uid) ?? []), h.clock.nowMs()]);
    };
    h.gate.gate = CLOSED_DELIVERY_GATE;
    const backlogUsers = Array.from({ length: 60 }, (_, i) => `b${String(i).padStart(2, '0')}`);
    for (const uid of backlogUsers) {
      h.tokens.byUid.set(uid, [token(uid)]);
      await h.activity(uid, 'set'); // due Monday; the gate stays closed for days
    }
    const openedAt = Date.UTC(2026, 10, 17, 10, 0); // Tue 12:00 Cairo
    h.clock.set(openedAt - 48 * HOUR);
    h.tokens.byUid.set('fresh', [token('fresh')]);
    await h.activity('fresh', 'set'); // due exactly when the gate opens

    h.gate.gate = { mode: 'all', maxSendsPerPass: 25 };
    const passes = [];
    for (let at = openedAt; at <= openedAt + 5 * DAY; at += HOUR) {
      h.clock.set(at);
      passes.push(await h.pass.execute());
    }
    expect(passes[0]).toMatchObject({ sent: 1, backlog_deferred: 60 }); // only the fresh one
    expect(sentAt.get('fresh')?.[0]).toBe(openedAt); // not deferred
    expect(Math.max(...passes.map((p) => p.sent + p.outcome_unknown))).toBeLessThanOrEqual(25);

    const firstSends = backlogUsers.map((uid) => sentAt.get(uid)?.[0] ?? Number.NaN);
    expect(firstSends.every((ms) => isWithinDeliveryWindow(ms, CAIRO, policy))).toBe(true);
    expect(new Set(firstSends.map(localDay))).toEqual(new Set(['2026-11-18', '2026-11-19', '2026-11-20']));
    // Each got reminder 1 once; the cadence continues from the actual send.
    for (const uid of backlogUsers) {
      const sends = sentAt.get(uid) ?? [];
      expect(sends.length).toBeGreaterThanOrEqual(1);
      if (sends.length > 1) expect(sends[1] - sends[0]).toBeGreaterThanOrEqual(72 * HOUR);
      expect(h.store.get(uid)?.lastActivityAtMs).toBe(ACT); // history untouched
    }
  });
});
