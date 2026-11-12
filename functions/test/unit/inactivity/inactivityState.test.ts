import {
  applyActivity,
  applyPreferences,
  beginSending,
  completeAttempt,
  decideClaim,
  type DeliveryCounts,
  type InactivityState,
  type ReminderClaim,
} from '../../../src/inactivity/domain/inactivityState';
import { defaultReminderPolicy as policy } from '../../../src/inactivity/domain/reminderPolicy';
import { resolveReminderPreferences } from '../../../src/inactivity/domain/reminderPreferences';
import { firstDeliverableAt } from '../../../src/inactivity/domain/reminderSchedule';
import { DAY, HOUR } from '../../support/inactivityFakes';
import { dartLocalIso, SATURDAY_18_CAIRO as ACT } from '../../support/inactivityHarness';

const MIN = 60_000;
const defaults = resolveReminderPreferences(null, policy);
const ACCEPTED: DeliveryCounts = { acceptedDevices: 1, invalidDevices: 0, failedDevices: 0, unknownDevices: 0 };
const NO_DEVICE: DeliveryCounts = { acceptedDevices: 0, invalidDevices: 0, failedDevices: 0, unknownDevices: 0 };
const FAILED: DeliveryCounts = { acceptedDevices: 0, invalidDevices: 0, failedDevices: 2, unknownDevices: 0 };
const UNKNOWN: DeliveryCounts = { acceptedDevices: 0, invalidDevices: 0, failedDevices: 1, unknownDevices: 1 };

/**
 * A user whose app has written its preferences (Stage 3+ build), before any
 * activity; `record(null, ...)` starts from it. Old-build users are covered
 * in "per-user rollout gate" below.
 */
const appReady = (): InactivityState =>
  applyPreferences({ fromAppDocument: true, state: null, preferences: defaults, nowMs: 0, policy });

function record(state: InactivityState | null, atMs: number, source: 'session' | 'set' = 'set', receivedAtMs = atMs) {
  return applyActivity({
    state: state ?? appReady(),
    source,
    occurredAtRaw: dartLocalIso(atMs),
    receivedAtMs,
    defaultPreferences: defaults,
    nowMs: receivedAtMs,
    policy,
  });
}

function claimAt(state: InactivityState, nowMs: number, leaseId = 'lease-a') {
  const decision = decideClaim({ uid: 'u', state, nowMs, leaseId, policy });
  if (decision.kind !== 'claim') throw new Error(`expected claim, got ${decision.kind}`);
  return decision;
}

/** Claims, sends and completes one reminder at [nowMs]. */
function deliverAt(state: InactivityState, nowMs: number, counts: DeliveryCounts = ACCEPTED): InactivityState {
  const { state: claimed, claim } = claimAt(state, nowMs);
  const begun = beginSending({ state: claimed, claim, nowMs });
  if (!begun.ok) throw new Error(begun.reason);
  const done = completeAttempt({ state: begun.state, claim, counts, nowMs, policy });
  if (!done.ok) throw new Error(done.reason);
  return done.state;
}

describe('activity', () => {
  test('first activity creates the state and schedules reminder 1 at +48 h', () => {
    const { state, outcome } = record(null, ACT, 'session');
    expect(outcome).toBe('started_cycle');
    expect(state).toMatchObject({
      lastActivityAtMs: ACT,
      lastActivitySource: 'session',
      lastActivityOccurredAtMs: ACT,
      lastActivityReceivedAtMs: ACT,
      lastActivityTimeQuality: 'client',
      cycleId: `c${ACT}`,
      remindersSentInCycle: 0,
      nextReminderDueAtMs: ACT + 48 * HOUR,
      nextReminderAtMs: ACT + 48 * HOUR,
      enabled: true,
      language: 'ar',
      timeZone: 'Africa/Cairo',
    });
  });

  test('no throttling: sets 2 and 5 minutes apart each move the clock forward', () => {
    let state = record(null, ACT).state;
    for (const at of [ACT + 2 * MIN, ACT + 7 * MIN]) {
      const next = record(state, at);
      expect(next.outcome).toBe('started_cycle');
      state = next.state;
    }
    expect(state.lastActivityAtMs).toBe(ACT + 7 * MIN);
    expect(state.nextReminderDueAtMs).toBe(ACT + 7 * MIN + 48 * HOUR);
  });

  test('a session started shortly after a set is the latest activity', () => {
    const afterSet = record(null, ACT, 'set').state;
    const { state } = record(afterSet, ACT + 30_000, 'session');
    expect(state).toMatchObject({ lastActivitySource: 'session', lastActivityAtMs: ACT + 30_000 });
  });

  test('duplicate and out-of-order deliveries never roll the clock back', () => {
    const latest = record(null, ACT + HOUR).state;
    expect(record(latest, ACT + HOUR)).toEqual({ state: latest, outcome: 'not_newer' });
    // An older set uploaded late (arrives after the newer one).
    expect(record(latest, ACT, 'set', ACT + 2 * HOUR)).toEqual({ state: latest, outcome: 'not_newer' });
  });

  test('activity just before a reminder is due resets the cycle', () => {
    let state = record(null, ACT).state;
    state = deliverAt(state, ACT + 48 * HOUR);
    expect(state.remindersSentInCycle).toBe(1);
    const justBefore = ACT + 48 * HOUR + 72 * HOUR - MIN;
    state = record(state, justBefore).state;
    expect(state).toMatchObject({
      cycleId: `c${justBefore}`,
      remindersSentInCycle: 0,
      nextReminderDueAtMs: justBefore + 48 * HOUR,
    });
    // The reminder that was 1 minute away is no longer claimable.
    expect(decideClaim({ uid: 'u', state, nowMs: justBefore + MIN, leaseId: 'x', policy })).toEqual({
      kind: 'skip',
      reason: 'not_due',
    });
  });

  test('a future-dated client time cannot postpone reminders', () => {
    const { state } = applyActivity({
      state: null,
      source: 'set',
      occurredAtRaw: dartLocalIso(ACT + 30 * DAY),
      receivedAtMs: ACT,
      defaultPreferences: defaults,
      nowMs: ACT,
      policy,
    });
    expect(state).toMatchObject({ lastActivityAtMs: ACT, lastActivityTimeQuality: 'future' });
  });

  test('activity of a disabled user is recorded without scheduling anything', () => {
    const disabled = applyPreferences({ fromAppDocument: true,
      state: null,
      preferences: { ...defaults, enabled: false },
      nowMs: ACT,
      policy,
    });
    const { state } = record(disabled, ACT);
    expect(state).toMatchObject({ lastActivityAtMs: ACT, nextReminderDueAtMs: ACT + 48 * HOUR, nextReminderAtMs: null });
  });
});

describe('preferences', () => {
  test('preferences alone (no workout history) never schedule a reminder', () => {
    const state = applyPreferences({ fromAppDocument: true, state: null, preferences: defaults, nowMs: ACT, policy });
    expect(state).toMatchObject({ lastActivityAtMs: null, nextReminderAtMs: null });
    expect(decideClaim({ uid: 'u', state, nowMs: ACT + 30 * DAY, leaseId: 'x', policy })).toEqual({
      kind: 'skip',
      reason: 'no_history',
    });
  });

  test('disable clears the next send; re-enable recalculates without resetting history', () => {
    let state = record(null, ACT).state;
    state = deliverAt(state, ACT + 48 * HOUR);
    state = deliverAt(state, ACT + 48 * HOUR + 72 * HOUR);
    const lastSent = ACT + 120 * HOUR;

    const off = applyPreferences({ fromAppDocument: true, state, preferences: { ...defaults, enabled: false }, nowMs: lastSent + HOUR, policy });
    expect(off).toMatchObject({ enabled: false, nextReminderAtMs: null, remindersSentInCycle: 2, lastActivityAtMs: ACT });
    expect(decideClaim({ uid: 'u', state: off, nowMs: lastSent + 10 * DAY, leaseId: 'x', policy })).toEqual({
      kind: 'skip',
      reason: 'disabled',
    });

    const on = applyPreferences({ fromAppDocument: true, state: off, preferences: defaults, nowMs: lastSent + 2 * HOUR, policy });
    expect(on).toMatchObject({
      enabled: true,
      remindersSentInCycle: 2,
      lastReminderSentAtMs: lastSent,
      nextReminderDueAtMs: lastSent + 72 * HOUR,
      nextReminderAtMs: lastSent + 72 * HOUR,
    });
  });

  test('language and time zone changes apply to the next reminder', () => {
    const state = record(null, ACT).state;
    const changed = applyPreferences({ fromAppDocument: true,
      state,
      preferences: { enabled: true, language: 'en', timeZone: 'America/New_York' },
      nowMs: ACT,
      policy,
    });
    // Due Mon 16:00 UTC = 11:00 New York: deliverable unchanged.
    expect(changed).toMatchObject({ language: 'en', nextReminderAtMs: ACT + 48 * HOUR });
    expect(claimAt(changed, ACT + 48 * HOUR).claim.language).toBe('en');
    const tokyo = applyPreferences({ fromAppDocument: true,
      state,
      preferences: { enabled: true, language: 'en', timeZone: 'Asia/Tokyo' },
      nowMs: ACT,
      policy,
    });
    // 01:00 Tuesday in Tokyo: postponed to 10:00 Tokyo (01:00 UTC).
    expect(tokyo.nextReminderAtMs).toBe(Date.UTC(2026, 10, 10, 1, 0));
  });
});

describe('claiming', () => {
  const active = record(null, ACT).state;
  const due = ACT + 48 * HOUR;

  test('nothing is claimable before the due time; at the due time it is claimed', () => {
    expect(decideClaim({ uid: 'u', state: active, nowMs: due - 1, leaseId: 'x', policy })).toEqual({ kind: 'skip', reason: 'not_due' });
    expect(decideClaim({ uid: 'u', state: null, nowMs: due, leaseId: 'x', policy })).toEqual({ kind: 'skip', reason: 'missing' });

    const { state, claim } = claimAt(active, due);
    expect(claim).toEqual({ cycleId: `c${ACT}`, reminderNumber: 1, attemptId: `c${ACT}:r1`, leaseId: 'lease-a', language: 'ar' });
    expect(state).toMatchObject({ leaseId: 'lease-a', leaseExpiresAtMs: due + policy.delivery.leaseMs });
    expect(state.lastAttempt).toMatchObject({ id: `c${ACT}:r1`, status: 'claimed', claimedAtMs: due });
  });

  test('an active lease blocks every other sender', () => {
    const { state } = claimAt(active, due);
    expect(decideClaim({ uid: 'u', state, nowMs: due + 14 * MIN, leaseId: 'lease-b', policy })).toEqual({
      kind: 'skip',
      reason: 'leased',
    });
  });

  test('due but outside 10:00–21:00 (scheduler outage) is postponed, not sent', () => {
    const lateNight = due + 4 * HOUR; // Mon 22:00 Cairo
    const decision = decideClaim({ uid: 'u', state: active, nowMs: lateNight, leaseId: 'x', policy });
    expect(decision).toMatchObject({ kind: 'postpone' });
    if (decision.kind !== 'postpone') return;
    expect(decision.state.nextReminderAtMs).toBe(Date.UTC(2026, 10, 10, 8, 0)); // Tue 10:00 Cairo
    expect(decision.state.leaseId).toBeNull();
  });

  test('crash before sending: the expired claim is retried with the same attempt id', () => {
    const first = claimAt(active, due, 'lease-a');
    const retried = claimAt(first.state, due + policy.delivery.leaseMs, 'lease-b');
    expect(retried.claim.attemptId).toBe(first.claim.attemptId);
    expect(retried.state).toMatchObject({ leaseId: 'lease-b', remindersSentInCycle: 0 });
  });

  test('crash after handing to FCM: resolved as outcome_unknown, never re-sent', () => {
    const { state: claimed, claim } = claimAt(active, due);
    const begun = beginSending({ state: claimed, claim, nowMs: due + MIN });
    if (!begun.ok) throw new Error(begun.reason);
    // Process dies here; FCM may have accepted the message.
    const decision = decideClaim({ uid: 'u', state: begun.state, nowMs: due + 20 * MIN, leaseId: 'lease-b', policy });
    expect(decision.kind).toBe('recovered_unknown_outcome');
    if (decision.kind !== 'recovered_unknown_outcome') return;
    expect(decision.state).toMatchObject({
      remindersSentInCycle: 1,
      lastReminderSentAtMs: due + MIN,
      nextReminderDueAtMs: due + MIN + 72 * HOUR,
      leaseId: null,
    });
    expect(decision.state.lastAttempt).toMatchObject({ id: claim.attemptId, status: 'outcome_unknown' });
    // The next run claims reminder 2, not reminder 1 again.
    expect(claimAt(decision.state, due + MIN + 72 * HOUR).claim.reminderNumber).toBe(2);
  });

  test('an expired claim from an older cycle is superseded, the new cycle proceeds', () => {
    const { state: claimed } = claimAt(active, due);
    const newer = record(claimed, due + MIN).state; // keeps the stale lease
    expect(newer.leaseId).toBe('lease-a');
    const decision = decideClaim({ uid: 'u', state: newer, nowMs: due + 20 * MIN, leaseId: 'lease-b', policy });
    expect(decision).toEqual({ kind: 'skip', reason: 'not_due' });
    const later = claimAt(newer, due + MIN + 48 * HOUR, 'lease-c');
    expect(later.claim.attemptId).toBe(`c${due + MIN}:r1`);
  });
});

describe('sending and completion', () => {
  const due = ACT + 48 * HOUR;
  const claimed = () => claimAt(record(null, ACT).state, due);

  test('begin sending fails without the lease, after new activity, or when disabled', () => {
    const { state, claim } = claimed();
    const stranger: ReminderClaim = { ...claim, leaseId: 'other' };
    expect(beginSending({ state, claim: stranger, nowMs: due })).toEqual({ ok: false, reason: 'lease_lost', state: null });
    expect(beginSending({ state, claim, nowMs: due + policy.delivery.leaseMs })).toMatchObject({ ok: false, reason: 'lease_lost' });

    const superseded = beginSending({ state: record(state, due).state, claim, nowMs: due });
    expect(superseded).toMatchObject({ ok: false, reason: 'superseded' });
    expect(superseded.state).toMatchObject({ leaseId: null, lastAttempt: { status: 'superseded' } });

    const off = applyPreferences({ fromAppDocument: true, state, preferences: { ...defaults, enabled: false }, nowMs: due, policy });
    const cancelled = beginSending({ state: off, claim, nowMs: due });
    expect(cancelled).toMatchObject({ ok: false, reason: 'disabled' });
    expect(cancelled.state).toMatchObject({ leaseId: null, nextReminderAtMs: null, lastAttempt: { status: 'cancelled' } });
  });

  test('accepted: counts as sent and schedules the next reminder from now', () => {
    const state = deliverAt(record(null, ACT).state, due, {
      acceptedDevices: 2,
      invalidDevices: 1,
      failedDevices: 1,
      unknownDevices: 0,
    });
    expect(state).toMatchObject({
      remindersSentInCycle: 1,
      lastReminderSentAtMs: due,
      nextReminderAtMs: due + 72 * HOUR,
      leaseId: null,
      consecutiveFailures: 0,
    });
    expect(state.lastAttempt).toMatchObject({ status: 'accepted', acceptedDevices: 2, invalidDevices: 1, failedDevices: 1 });
  });

  test('cadence after five reminders becomes weekly', () => {
    let state = record(null, ACT).state;
    const sends: number[] = [];
    for (let n = 1; n <= 7; n += 1) {
      const at = state.nextReminderAtMs ?? Number.NaN;
      sends.push(at);
      state = deliverAt(state, at);
    }
    const gaps = sends.slice(1).map((at, i) => (at - sends[i]) / HOUR);
    expect([(sends[0] - ACT) / HOUR, ...gaps]).toEqual([48, 72, 72, 72, 72, 168, 168]);
  });

  test('no deliverable device: nothing counted, checked again in 24 h', () => {
    const state = deliverAt(record(null, ACT).state, due, NO_DEVICE);
    expect(state).toMatchObject({ remindersSentInCycle: 0, lastReminderSentAtMs: null, nextReminderAtMs: due + 24 * HOUR });
    expect(state.lastAttempt?.status).toBe('no_deliverable_device');
  });

  test('retryable failures back off 1, 2, 4, 8, 24, 24 h and reset on success', () => {
    let state = record(null, ACT).state;
    let at = due;
    for (const backoffHours of [1, 2, 4, 8, 24, 24]) {
      state = deliverAt(state, at, FAILED);
      expect(state.lastAttempt?.status).toBe('retryable_failure');
      expect(state.remindersSentInCycle).toBe(0);
      // Exactly the backoff, moved out of quiet hours when it lands there
      // (18:00 +1 h = 19:00; 19:00 +2 h = 21:00 → 10:00 next day; ...).
      const expected = firstDeliverableAt(at + backoffHours * HOUR, 'Africa/Cairo', policy);
      expect(state.nextReminderAtMs).toBe(expected);
      at = expected;
    }
    expect(state.consecutiveFailures).toBe(6);
    state = deliverAt(state, at);
    expect(state).toMatchObject({ consecutiveFailures: 0, remindersSentInCycle: 1, lastReminderSentAtMs: at });
  });

  test('completion after new activity is superseded and keeps the new schedule', () => {
    const { state, claim } = claimed();
    const begun = beginSending({ state, claim, nowMs: due });
    if (!begun.ok) throw new Error(begun.reason);
    const reset = record(begun.state, due + 1).state;
    const done = completeAttempt({ state: reset, claim, counts: ACCEPTED, nowMs: due + 2, policy });
    if (!done.ok) throw new Error(done.reason);
    expect(done.state).toMatchObject({
      remindersSentInCycle: 0,
      cycleId: `c${due + 1}`,
      nextReminderAtMs: due + 1 + 48 * HOUR,
      leaseId: null,
      lastAttempt: { status: 'superseded', acceptedDevices: 1 },
    });
  });

  test('completion without the lease writes nothing', () => {
    const { state, claim } = claimed();
    expect(completeAttempt({ state, claim: { ...claim, leaseId: 'x' }, counts: ACCEPTED, nowMs: due, policy })).toEqual({
      ok: false,
      reason: 'lease_lost',
    });
  });

  test('disabled while FCM was handling it: counted, but nothing further scheduled', () => {
    const { state, claim } = claimed();
    const begun = beginSending({ state, claim, nowMs: due });
    if (!begun.ok) throw new Error(begun.reason);
    const off = applyPreferences({ fromAppDocument: true, state: begun.state, preferences: { ...defaults, enabled: false }, nowMs: due, policy });
    const done = completeAttempt({ state: off, claim, counts: ACCEPTED, nowMs: due, policy });
    expect(done).toMatchObject({ ok: true, state: { remindersSentInCycle: 1, nextReminderAtMs: null } });
  });
});

describe('re-enable grace period (48 h)', () => {
  const off = (state: InactivityState, nowMs: number) =>
    applyPreferences({ fromAppDocument: true, state, preferences: { ...defaults, enabled: false }, nowMs, policy });
  const on = (state: InactivityState, nowMs: number, extra: Partial<typeof defaults> = {}) =>
    applyPreferences({ fromAppDocument: true, state, preferences: { ...defaults, ...extra }, nowMs, policy });

  test('an overdue reminder waits 48 h after re-enabling; history and count are kept', () => {
    let state = deliverAt(record(null, ACT).state, ACT + 48 * HOUR); // reminder 1, Mon 18:00
    state = off(state, ACT + 49 * HOUR);
    const reEnabledAt = ACT + 10 * DAY + 2 * HOUR; // Tue 20:00, cadence long overdue
    state = on(state, reEnabledAt);
    expect(state).toMatchObject({
      lastActivityAtMs: ACT,
      cycleId: `c${ACT}`,
      remindersSentInCycle: 1,
      lastReminderSentAtMs: ACT + 48 * HOUR,
      reactivationGraceUntilMs: reEnabledAt + 48 * HOUR,
      nextReminderDueAtMs: reEnabledAt + 48 * HOUR,
      nextReminderAtMs: reEnabledAt + 48 * HOUR, // Thu 20:00, inside the window
    });
    expect(decideClaim({ uid: 'u', state, nowMs: reEnabledAt + 48 * HOUR - 1, leaseId: 'x', policy })).toEqual({
      kind: 'skip',
      reason: 'not_due',
    });
    expect(claimAt(state, reEnabledAt + 48 * HOUR).claim).toMatchObject({ reminderNumber: 2, attemptId: `c${ACT}:r2` });
  });

  test('when the cadence is later than the grace period, the cadence wins', () => {
    let state = deliverAt(record(null, ACT).state, ACT + 48 * HOUR);
    state = off(state, ACT + 49 * HOUR);
    state = on(state, ACT + 50 * HOUR); // grace ends at +98 h, reminder 2 due at +120 h
    expect(state.nextReminderAtMs).toBe(ACT + 120 * HOUR);
  });

  test('the grace period is held back further by quiet hours', () => {
    let state = off(record(null, ACT).state, ACT + HOUR);
    const reEnabledAt = ACT + 5 * DAY + 4 * HOUR; // Thu 22:00 Cairo
    state = on(state, reEnabledAt);
    expect(state.nextReminderDueAtMs).toBe(reEnabledAt + 48 * HOUR); // Sat 22:00
    expect(state.nextReminderAtMs).toBe(Date.UTC(2026, 10, 15, 8, 0)); // Sun 10:00
  });

  test('only an off-to-on change starts it; repeats and other changes do not', () => {
    const active = record(null, ACT).state;
    expect(on(active, ACT + HOUR, { language: 'en' }).reactivationGraceUntilMs).toBeNull();
    expect(applyPreferences({ fromAppDocument: true, state: null, preferences: defaults, nowMs: ACT, policy }).reactivationGraceUntilMs).toBeNull();
    const reEnabled = on(off(active, ACT + HOUR), ACT + 2 * HOUR);
    // The same "on" delivered again later must not push the grace period.
    expect(on(reEnabled, ACT + 30 * HOUR).reactivationGraceUntilMs).toBe(ACT + 50 * HOUR);
    // Toggling off and on again starts a new one.
    expect(on(off(reEnabled, ACT + 31 * HOUR), ACT + 32 * HOUR).reactivationGraceUntilMs).toBe(ACT + 80 * HOUR);
  });

  test('new activity after re-enabling schedules from the activity, never earlier than the grace period', () => {
    const reEnabledAt = ACT + 10 * DAY;
    const reEnabled = on(off(record(null, ACT).state, ACT + HOUR), reEnabledAt);
    const after = record(reEnabled, reEnabledAt + HOUR).state;
    expect(after).toMatchObject({ remindersSentInCycle: 0, nextReminderDueAtMs: reEnabledAt + 49 * HOUR });
    // An offline workout from before the re-enable, uploaded now.
    const lateUpload = applyActivity({
      state: reEnabled,
      source: 'set',
      occurredAtRaw: dartLocalIso(reEnabledAt - 10 * HOUR),
      receivedAtMs: reEnabledAt + HOUR,
      defaultPreferences: defaults,
      nowMs: reEnabledAt + HOUR,
      policy,
    }).state;
    expect(lateUpload.lastActivityAtMs).toBe(reEnabledAt - 10 * HOUR);
    expect(lateUpload.nextReminderDueAtMs).toBe(reEnabledAt + 48 * HOUR);
  });
});

describe('crash recovery and unknown outcomes', () => {
  const due = ACT + 48 * HOUR;

  test('a claim alone is never counted, however often it expires', () => {
    let state = record(null, ACT).state;
    for (let i = 0; i < 3; i += 1) {
      state = claimAt(state, due + i * policy.delivery.leaseMs, `lease-${i}`).state;
      expect(state).toMatchObject({ remindersSentInCycle: 0, lastReminderSentAtMs: null });
      expect(state.lastAttempt).toMatchObject({ id: `c${ACT}:r1`, status: 'claimed' });
    }
  });

  test('an unknown per-device outcome counts as possibly sent and is never re-sent', () => {
    const state = deliverAt(record(null, ACT).state, due, UNKNOWN);
    expect(state).toMatchObject({
      remindersSentInCycle: 1,
      lastReminderSentAtMs: due,
      nextReminderAtMs: due + 72 * HOUR,
      consecutiveFailures: 0,
      lastAttempt: { status: 'outcome_unknown', unknownDevices: 1, failedDevices: 1 },
    });
    expect(claimAt(state, due + 72 * HOUR).claim.reminderNumber).toBe(2);
  });

  test('accepted wins over unknown when both happen', () => {
    const state = deliverAt(record(null, ACT).state, due, { ...UNKNOWN, acceptedDevices: 1 });
    expect(state.lastAttempt?.status).toBe('accepted');
  });

  test('an older-cycle attempt that crashed while sending stays explicitly unknown', () => {
    const { state: claimed, claim } = claimAt(record(null, ACT).state, due);
    const begun = beginSending({ state: claimed, claim, nowMs: due });
    if (!begun.ok) throw new Error(begun.reason);
    // Crash; new activity arrives before recovery.
    const reset = record(begun.state, due + 1).state;
    const decision = decideClaim({ uid: 'u', state: reset, nowMs: due + policy.delivery.leaseMs, leaseId: 'b', policy });
    expect(decision).toEqual({ kind: 'skip', reason: 'not_due' });
    const next = claimAt(reset, due + 1 + 48 * HOUR, 'c');
    expect(next.claim.attemptId).toBe(`c${due + 1}:r1`);
    // The crashed attempt belonged to the old cycle: it never advances the new one.
    expect(next.state.remindersSentInCycle).toBe(0);
  });

  test('the cleared older-cycle attempt is recorded as outcome_unknown, not superseded', () => {
    const { state: claimed, claim } = claimAt(record(null, ACT).state, due);
    const begun = beginSending({ state: claimed, claim, nowMs: due });
    if (!begun.ok) throw new Error(begun.reason);
    const reset = record(begun.state, due + 1).state;
    const decision = decideClaim({ uid: 'u', state: reset, nowMs: due + 1 + 48 * HOUR, leaseId: 'b', policy });
    if (decision.kind !== 'claim') throw new Error(decision.kind);
    // The new claim replaces lastAttempt; check the intermediate resolution
    // through a postponed decision instead (outside the delivery window).
    const late = decideClaim({ uid: 'u', state: reset, nowMs: due + 1 + 48 * HOUR + 4 * HOUR, leaseId: 'b', policy });
    if (late.kind !== 'postpone') throw new Error(late.kind);
    expect(late.state.lastAttempt).toMatchObject({ id: claim.attemptId, status: 'outcome_unknown' });
    expect(late.state.remindersSentInCycle).toBe(0);
  });

  test('an expired older-cycle claim that never reached FCM is superseded', () => {
    const { state: claimed, claim } = claimAt(record(null, ACT).state, due);
    const reset = record(claimed, due + 1).state;
    const late = decideClaim({ uid: 'u', state: reset, nowMs: due + 1 + 52 * HOUR, leaseId: 'b', policy });
    if (late.kind !== 'postpone') throw new Error(late.kind);
    expect(late.state.lastAttempt).toMatchObject({ id: claim.attemptId, status: 'superseded' });
  });

  test('sending requires the claimed attempt record to be the current one', () => {
    const { state, claim } = claimAt(record(null, ACT).state, due);
    const missing = { ...state, lastAttempt: null };
    expect(beginSending({ state: missing, claim, nowMs: due })).toEqual({ ok: false, reason: 'lease_lost', state: null });
    const other = { ...state, lastAttempt: state.lastAttempt && { ...state.lastAttempt, id: 'c0:r9' } };
    expect(beginSending({ state: other, claim, nowMs: due })).toMatchObject({ ok: false, reason: 'lease_lost' });
    const begun = beginSending({ state, claim, nowMs: due });
    if (!begun.ok) throw new Error(begun.reason);
    // Never twice: an attempt already `sending` cannot be begun again.
    expect(beginSending({ state: begun.state, claim, nowMs: due })).toMatchObject({ ok: false, reason: 'lease_lost' });
  });
});
