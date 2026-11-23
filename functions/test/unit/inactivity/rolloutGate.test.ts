import {
  CLOSED_DELIVERY_GATE,
  DEFAULT_MAX_SENDS_PER_PASS,
  MAX_ALLOWLIST_UIDS,
  parseDeliveryGate,
} from '../../../src/inactivity/domain/deliveryGate';
import { applyActivity, applyPreferences, decideClaim } from '../../../src/inactivity/domain/inactivityState';
import { defaultReminderPolicy as policy } from '../../../src/inactivity/domain/reminderPolicy';
import { resolveReminderPreferences } from '../../../src/inactivity/domain/reminderPreferences';
import { DAY, HOUR, token } from '../../support/inactivityFakes';
import { dartLocalIso, inactivityHarness, SATURDAY_18_CAIRO as ACT } from '../../support/inactivityHarness';

const defaults = resolveReminderPreferences(null, policy);
const DUE = ACT + 48 * HOUR;

describe('delivery gate (operator switch)', () => {
  test('missing, malformed or unknown configuration is OFF', () => {
    for (const raw of [null, undefined, 'all', 42, {}, { deliveryMode: 'ALL' }, { deliveryMode: 'on' }, { enabled: true }]) {
      expect(parseDeliveryGate(raw)).toEqual(CLOSED_DELIVERY_GATE);
    }
  });

  test('all and allowlist must be spelled out exactly', () => {
    expect(parseDeliveryGate({ deliveryMode: 'all' })).toEqual({ mode: 'all', maxSendsPerPass: DEFAULT_MAX_SENDS_PER_PASS });
    expect(parseDeliveryGate({ deliveryMode: 'allowlist', allowlistUids: ['b', 'a', 'b'] })).toEqual({
      mode: 'allowlist',
      uids: ['a', 'b'],
      maxSendsPerPass: DEFAULT_MAX_SENDS_PER_PASS,
    });
    expect(parseDeliveryGate({ deliveryMode: 'all', maxSendsPerPass: 750 })).toEqual({ mode: 'all', maxSendsPerPass: 750 });
  });

  test('an unusable allowlist closes the gate instead of widening it', () => {
    for (const allowlistUids of [undefined, [], ['ok', ''], ['ok', 7], ['users/x'], ['x'.repeat(129)]]) {
      expect(parseDeliveryGate({ deliveryMode: 'allowlist', allowlistUids })).toEqual(CLOSED_DELIVERY_GATE);
    }
    const tooMany = Array.from({ length: MAX_ALLOWLIST_UIDS + 1 }, (_, i) => `u${i}`);
    expect(parseDeliveryGate({ deliveryMode: 'allowlist', allowlistUids: tooMany })).toEqual(CLOSED_DELIVERY_GATE);
  });

  test('an invalid send budget closes the gate instead of guessing', () => {
    for (const maxSendsPerPass of [0, -1, 1.5, 5001, '100', null, Number.NaN]) {
      expect(parseDeliveryGate({ deliveryMode: 'all', maxSendsPerPass })).toEqual(CLOSED_DELIVERY_GATE);
    }
  });
});

describe('per-user gate: the app must confirm it handles server reminders', () => {
  const oldBuildUser = () =>
    applyActivity({
      state: null,
      source: 'set',
      occurredAtRaw: dartLocalIso(ACT),
      receivedAtMs: ACT,
      defaultPreferences: defaults,
      nowMs: ACT,
      policy,
    }).state;

  test('activity of a user without an app preference document schedules nothing', () => {
    const state = oldBuildUser();
    expect(state).toMatchObject({
      lastActivityAtMs: ACT,
      appSupportsServerReminders: false,
      nextReminderDueAtMs: DUE, // tracked, never queried
      nextReminderAtMs: null,
    });
    expect(decideClaim({ uid: 'u', state, nowMs: DUE + 10 * DAY, leaseId: 'x', policy })).toEqual({
      kind: 'skip',
      reason: 'app_not_ready',
    });
    // Defaults applied server-side (no document) do not confirm the app.
    const stillOld = applyPreferences({ state, preferences: defaults, fromAppDocument: false, nowMs: ACT, policy });
    expect(stillOld.nextReminderAtMs).toBeNull();
  });

  test('the first app-written preferences start the normal cadence; confirmation is sticky', () => {
    const confirmed = applyPreferences({
      state: oldBuildUser(),
      preferences: defaults,
      fromAppDocument: true,
      nowMs: ACT + HOUR,
      policy,
    });
    expect(confirmed).toMatchObject({ appSupportsServerReminders: true, nextReminderAtMs: DUE });
    expect(decideClaim({ uid: 'u', state: confirmed, nowMs: DUE, leaseId: 'x', policy }).kind).toBe('claim');
    const later = applyPreferences({ state: confirmed, preferences: defaults, fromAppDocument: false, nowMs: DUE, policy });
    expect(later.appSupportsServerReminders).toBe(true);
  });

  test('a user who turned reminders off in the app stays off when confirming', () => {
    const confirmedOff = applyPreferences({
      state: oldBuildUser(),
      preferences: { ...defaults, enabled: false },
      fromAppDocument: true,
      nowMs: ACT,
      policy,
    });
    expect(confirmedOff).toMatchObject({ appSupportsServerReminders: true, enabled: false, nextReminderAtMs: null });
  });
});

describe('rollout end to end (hourly passes)', () => {
  const runHours = async (h: ReturnType<typeof inactivityHarness>, from: number, to: number) => {
    for (let at = Math.ceil(from / HOUR) * HOUR; at <= to; at += HOUR) {
      h.clock.set(at);
      await h.pass.execute();
    }
  };

  test('a user still on an old build gets nothing until their app writes preferences', async () => {
    const h = inactivityHarness(ACT);
    h.preferences.documentByDefault = false; // old build: never writes settings/notifications
    h.tokens.byUid.set('old', [token('old-phone')]);
    await h.activity('old', 'set');
    await runHours(h, ACT, ACT + 10 * DAY);
    expect(h.sender.sends).toHaveLength(0);

    // Upgraded: the new build writes the document; the sync trigger runs.
    const upgradedAt = ACT + 10 * DAY + HOUR;
    h.clock.set(upgradedAt);
    h.preferences.byUid.set('old', { inactivityRemindersEnabled: true, language: 'en', timeZone: 'Africa/Cairo' });
    await h.sync.execute('old');
    // Ten days overdue: backlog, so it is spread to one of the next days
    // rather than sent right after the upgrade; then exactly once.
    await runHours(h, upgradedAt, upgradedAt + 2 * HOUR);
    expect(h.sender.sends).toHaveLength(0);
    await runHours(h, upgradedAt + 2 * HOUR, upgradedAt + 5 * DAY);
    const attempts = h.sender.sends.map((s) => s.attemptId);
    expect(attempts[0]).toBe(`c${ACT}:r1`); // the overdue reminder, once
    expect(attempts.filter((id) => id === `c${ACT}:r1`)).toHaveLength(1);
    expect(attempts.slice(1)).toEqual(attempts.length > 1 ? [`c${ACT}:r2`] : []); // cadence continues
  });

  test('gate off: no query, no send, for anyone', async () => {
    const h = inactivityHarness(ACT);
    h.gate.gate = CLOSED_DELIVERY_GATE;
    h.tokens.byUid.set('u1', [token('t1')]);
    await h.activity('u1', 'set');
    h.clock.set(DUE);
    expect(await h.pass.execute()).toMatchObject({ gate: 'off', examined: 0, sent: 0 });
    expect(h.finder.queries).toBe(0);
    expect(h.sender.sends).toHaveLength(0);
    // Reopened later: the due reminder is still sent (state was kept).
    h.gate.gate = { mode: 'all', maxSendsPerPass: DEFAULT_MAX_SENDS_PER_PASS };
    h.clock.set(DUE + HOUR);
    expect(await h.pass.execute()).toMatchObject({ gate: 'all', sent: 1 });
  });

  test('an unreadable gate fails closed', async () => {
    const h = inactivityHarness(ACT);
    h.gate.fail = true;
    h.tokens.byUid.set('u1', [token('t1')]);
    await h.activity('u1', 'set');
    h.clock.set(DUE);
    expect(await h.pass.execute()).toMatchObject({ gate: 'off', examined: 0 });
    expect(h.sender.sends).toHaveLength(0);
    expect(h.logger.entries.some((e) => e.event === 'inactivity_delivery_gate_unreadable')).toBe(true);
  });

  test('allowlist: only listed accounts, without scanning everyone due', async () => {
    const h = inactivityHarness(ACT);
    for (const uid of ['canary', 'everyone-else', 'not-due-canary']) h.tokens.byUid.set(uid, [token(uid)]);
    await h.activity('canary', 'set');
    await h.activity('everyone-else', 'set');
    h.clock.set(ACT + 47 * HOUR);
    await h.activity('not-due-canary', 'set');
    h.gate.gate = {
      mode: 'allowlist',
      uids: ['canary', 'not-due-canary', 'unknown-user'],
      maxSendsPerPass: DEFAULT_MAX_SENDS_PER_PASS,
    };
    h.clock.set(DUE);
    expect(await h.pass.execute()).toMatchObject({ gate: 'allowlist', examined: 3, sent: 1, skipped: 2 });
    expect(h.finder.queries).toBe(0);
    expect(h.sender.sends.map((s) => s.tokens[0].id)).toEqual(['canary']);
  });

  test('switching the gate off mid-pass stops before the next page', async () => {
    const h = inactivityHarness(ACT, { pageSize: 2, concurrency: 2 });
    for (const uid of ['a', 'b', 'c', 'd', 'e']) {
      h.tokens.byUid.set(uid, [token(uid)]);
      await h.activity(uid, 'set');
    }
    h.gate.onRead = (read) => {
      if (read === 2) h.gate.gate = CLOSED_DELIVERY_GATE; // operator flips it during page 1
    };
    h.clock.set(DUE);
    expect(await h.pass.execute()).toMatchObject({ gate: 'all', sent: 2, examined: 2, stoppedEarly: true });
    expect(h.sender.sends).toHaveLength(2);
  });
});
