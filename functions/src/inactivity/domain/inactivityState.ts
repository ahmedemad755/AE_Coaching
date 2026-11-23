import { type ActivitySource, type ActivityTimeQuality, resolveActivityTime } from './activityTime';
import type { ReminderLanguage, ReminderPolicy } from './reminderPolicy';
import type { ReminderPreferences } from './reminderPreferences';
import { backlogSlotAt, firstDeliverableAt, isWithinDeliveryWindow, reminderDueAt } from './reminderSchedule';

/**
 * Server-owned inactivity reminder state of one user, and every allowed
 * transition as a pure function. Persistence adapters run each transition
 * inside a transaction; nothing here knows about Firestore or FCM.
 *
 * Lifecycle of one reminder attempt:
 *   claimed ──► sending ──► accepted | outcome_unknown | no_deliverable_device | retryable_failure
 *      │           │
 *      │           └─(lease expires: crash after FCM may have accepted)─► outcome_unknown
 *      └─(lease expires: crash before sending)─► reclaimed with the same attempt id
 *   claimed ──(new activity changed the cycle)──► superseded
 *   sending ──(new activity changed the cycle)──► superseded (completed) | outcome_unknown (crashed)
 *   claimed ──(reminders disabled)──► cancelled
 *
 * Counting rule: a reminder advances the sequence only once it may have
 * reached FCM: `accepted` (FCM accepted it for at least one device) or
 * `outcome_unknown` (FCM may have accepted it). A claim alone never counts,
 * and an attempt that may have reached FCM is never re-sent.
 */

export type AttemptStatus =
  | 'claimed'
  | 'sending'
  | 'accepted'
  | 'no_deliverable_device'
  | 'retryable_failure'
  | 'outcome_unknown'
  | 'superseded'
  | 'cancelled';

export interface ReminderAttempt {
  /** Deterministic: `${cycleId}:r${reminderNumber}`. */
  readonly id: string;
  readonly cycleId: string;
  readonly reminderNumber: number;
  readonly status: AttemptStatus;
  readonly claimedAtMs: number;
  readonly sendingAtMs: number | null;
  readonly completedAtMs: number | null;
  /** Devices FCM accepted the message for (acceptance, not delivery). */
  readonly acceptedDevices: number;
  /** Devices removed as invalid/unregistered. */
  readonly invalidDevices: number;
  /** Devices that failed for any other reason (FCM did not accept it). */
  readonly failedDevices: number;
  /** Devices whose outcome is unknown (transport failure after sending). */
  readonly unknownDevices: number;
}

export interface InactivityState {
  /** Effective time of the latest qualifying activity (see activityTime.ts). */
  readonly lastActivityAtMs: number | null;
  readonly lastActivitySource: ActivitySource | null;
  /** Client-reported occurrence of that activity (untrusted, diagnostic). */
  readonly lastActivityOccurredAtMs: number | null;
  /** Server-observed arrival of that activity. */
  readonly lastActivityReceivedAtMs: number | null;
  readonly lastActivityTimeQuality: ActivityTimeQuality | null;
  /** Changes with every newer activity; deterministic per effective time. */
  readonly cycleId: string | null;
  readonly remindersSentInCycle: number;
  readonly lastReminderSentAtMs: number | null;
  /**
   * Due time of the next reminder: the cadence, held back by any re-enable
   * grace period (before quiet hours).
   */
  readonly nextReminderDueAtMs: number | null;
  /** When the next send may happen; `null` means nothing to send. Queried. */
  readonly nextReminderAtMs: number | null;
  readonly enabled: boolean;
  /**
   * The user's app has written its notification preferences at least once.
   * Only builds that receive server reminders (and no longer schedule the
   * retired on-device reminder) do that, so until then nothing is sent:
   * a user still on an older build would otherwise get both reminders.
   * Sticky once true.
   */
  readonly appSupportsServerReminders: boolean;
  readonly language: ReminderLanguage;
  readonly timeZone: string;
  /** Set when reminders are turned back on; nothing is due before it. */
  readonly reactivationGraceUntilMs: number | null;
  readonly leaseId: string | null;
  readonly leaseExpiresAtMs: number | null;
  readonly consecutiveFailures: number;
  readonly lastAttempt: ReminderAttempt | null;
  readonly updatedAtMs: number;
}

/** What a sender may do after a successful claim. */
export interface ReminderClaim {
  readonly cycleId: string;
  readonly reminderNumber: number;
  readonly attemptId: string;
  readonly leaseId: string;
  readonly language: ReminderLanguage;
}

export function initialInactivityState(prefs: ReminderPreferences, nowMs: number): InactivityState {
  return {
    lastActivityAtMs: null,
    lastActivitySource: null,
    lastActivityOccurredAtMs: null,
    lastActivityReceivedAtMs: null,
    lastActivityTimeQuality: null,
    cycleId: null,
    remindersSentInCycle: 0,
    lastReminderSentAtMs: null,
    nextReminderDueAtMs: null,
    nextReminderAtMs: null,
    enabled: prefs.enabled,
    appSupportsServerReminders: false,
    language: prefs.language,
    timeZone: prefs.timeZone,
    reactivationGraceUntilMs: null,
    leaseId: null,
    leaseExpiresAtMs: null,
    consecutiveFailures: 0,
    lastAttempt: null,
    updatedAtMs: nowMs,
  };
}

/** When the next reminder is due: the cadence, then any grace period. */
function dueAtOf(state: InactivityState, lastActivityAtMs: number, policy: ReminderPolicy): number {
  const cadenceDueAtMs = reminderDueAt({
    reminderNumber: state.remindersSentInCycle + 1,
    lastActivityAtMs,
    lastReminderSentAtMs: state.lastReminderSentAtMs,
    policy,
  });
  return Math.max(cadenceDueAtMs, state.reactivationGraceUntilMs ?? cadenceDueAtMs);
}

/** Reminders may be sent: turned on, and the user's app handles them. */
function remindersActive(state: InactivityState): boolean {
  return state.enabled && state.appSupportsServerReminders;
}

/** Recomputes the next reminder from the cadence, preferences and quiet hours. */
export function reschedule(state: InactivityState, nowMs: number, policy: ReminderPolicy): InactivityState {
  if (state.lastActivityAtMs === null) {
    return { ...state, nextReminderDueAtMs: null, nextReminderAtMs: null, updatedAtMs: nowMs };
  }
  const dueAtMs = dueAtOf(state, state.lastActivityAtMs, policy);
  return {
    ...state,
    nextReminderDueAtMs: dueAtMs,
    nextReminderAtMs: remindersActive(state) ? firstDeliverableAt(dueAtMs, state.timeZone, policy) : null,
    updatedAtMs: nowMs,
  };
}

export type ActivityOutcome = 'started_cycle' | 'not_newer';

/**
 * Records one qualifying activity. Only an activity strictly newer than the
 * stored one starts a new cycle, so duplicate trigger deliveries and late,
 * out-of-order uploads can never roll the clock back or reset a newer cycle.
 * No activity is ever ignored for being close to the previous one.
 */
export function applyActivity(params: {
  readonly state: InactivityState | null;
  readonly source: ActivitySource;
  readonly occurredAtRaw: unknown;
  readonly receivedAtMs: number;
  /** Used to create the state when none exists yet. */
  readonly defaultPreferences: ReminderPreferences;
  readonly nowMs: number;
  readonly policy: ReminderPolicy;
}): { readonly state: InactivityState; readonly outcome: ActivityOutcome } {
  const base = params.state ?? initialInactivityState(params.defaultPreferences, params.nowMs);
  const time = resolveActivityTime({
    occurredAtRaw: params.occurredAtRaw,
    receivedAtMs: params.receivedAtMs,
    timeZone: base.timeZone,
    policy: params.policy,
  });
  if (base.lastActivityAtMs !== null && time.effectiveAtMs <= base.lastActivityAtMs) {
    return { state: base, outcome: 'not_newer' };
  }
  const started: InactivityState = {
    ...base,
    lastActivityAtMs: time.effectiveAtMs,
    lastActivitySource: params.source,
    lastActivityOccurredAtMs: time.occurredAtMs,
    lastActivityReceivedAtMs: time.receivedAtMs,
    lastActivityTimeQuality: time.quality,
    cycleId: `c${time.effectiveAtMs}`,
    remindersSentInCycle: 0,
    consecutiveFailures: 0,
    // An in-flight claim keeps its lease; it is superseded when it tries to
    // continue, because its cycle no longer matches.
  };
  return { state: reschedule(started, params.nowMs, params.policy), outcome: 'started_cycle' };
}

/**
 * Applies preferences. Disabling clears the next send. Re-enabling (a
 * stored state going from off to on) starts a grace period and recomputes
 * the next send from the latest activity, without touching activity
 * history or the reminder count: the next reminder is due once both the
 * cadence and the grace period allow it. Repeated or reordered deliveries
 * of the same choice do not extend the grace period.
 */
export function applyPreferences(params: {
  readonly state: InactivityState | null;
  readonly preferences: ReminderPreferences;
  /**
   * The preferences come from a document the app wrote (not defaults for a
   * missing document): the user's app handles server reminders.
   */
  readonly fromAppDocument: boolean;
  readonly nowMs: number;
  readonly policy: ReminderPolicy;
}): InactivityState {
  const base = params.state ?? initialInactivityState(params.preferences, params.nowMs);
  const reEnabled = params.state !== null && !params.state.enabled && params.preferences.enabled;
  return reschedule(
    {
      ...base,
      reactivationGraceUntilMs: reEnabled
        ? params.nowMs + params.policy.cadence.reactivationGraceMs
        : base.reactivationGraceUntilMs,
      appSupportsServerReminders: base.appSupportsServerReminders || params.fromAppDocument,
      enabled: params.preferences.enabled,
      language: params.preferences.language,
      timeZone: params.preferences.timeZone,
    },
    params.nowMs,
    params.policy,
  );
}

export type ClaimDecision =
  | {
      readonly kind: 'skip';
      readonly reason: 'missing' | 'disabled' | 'app_not_ready' | 'no_history' | 'not_due' | 'leased';
    }
  | { readonly kind: 'postpone'; readonly reason: 'quiet_hours' | 'backlog'; readonly state: InactivityState }
  | { readonly kind: 'recovered_unknown_outcome'; readonly state: InactivityState }
  | { readonly kind: 'claim'; readonly state: InactivityState; readonly claim: ReminderClaim };

function attemptIdFor(cycleId: string, reminderNumber: number): string {
  return `${cycleId}:r${reminderNumber}`;
}

function finishAttempt(
  attempt: ReminderAttempt | null,
  status: AttemptStatus,
  nowMs: number,
  counts?: DeliveryCounts,
): ReminderAttempt | null {
  if (attempt === null) return null;
  return { ...attempt, ...counts, status, completedAtMs: nowMs };
}

/**
 * Decides, inside a transaction, whether this sender may send now.
 *
 * Crash recovery (lease expired):
 * - attempt still `claimed`: nothing was handed to FCM; it is reclaimed with
 *   the same attempt id and retried;
 * - attempt `sending`: FCM may or may not have accepted it. To avoid a
 *   duplicate motivational notification, it is resolved as
 *   `outcome_unknown` and counted as sent (the schedule advances from the
 *   time sending started). The cost of this policy is that, rarely, one
 *   reminder may be lost; a duplicate is never sent by design.
 */
export function decideClaim(params: {
  /** Whose state this is; spreads backlog per user (never logged here). */
  readonly uid: string;
  readonly state: InactivityState | null;
  readonly nowMs: number;
  readonly leaseId: string;
  readonly policy: ReminderPolicy;
}): ClaimDecision {
  const { nowMs, policy } = params;
  let state = params.state;
  if (state === null) return { kind: 'skip', reason: 'missing' };
  if (!state.enabled) return { kind: 'skip', reason: 'disabled' };
  if (!state.appSupportsServerReminders) return { kind: 'skip', reason: 'app_not_ready' };
  if (state.lastActivityAtMs === null || state.cycleId === null) return { kind: 'skip', reason: 'no_history' };
  // Unchanged by the lease cleanup below.
  const lastActivityAtMs = state.lastActivityAtMs;
  const cycleId = state.cycleId;

  if (state.leaseId !== null && state.leaseExpiresAtMs !== null && state.leaseExpiresAtMs > nowMs) {
    return { kind: 'skip', reason: 'leased' };
  }
  if (state.leaseId !== null) {
    const stale = state.lastAttempt;
    if (stale !== null && stale.status === 'sending' && stale.cycleId === state.cycleId) {
      const sentAtMs = stale.sendingAtMs ?? stale.claimedAtMs;
      const recovered = reschedule(
        {
          ...state,
          remindersSentInCycle: stale.reminderNumber,
          lastReminderSentAtMs: sentAtMs,
          consecutiveFailures: 0,
          leaseId: null,
          leaseExpiresAtMs: null,
          lastAttempt: finishAttempt(stale, 'outcome_unknown', nowMs),
        },
        nowMs,
        policy,
      );
      return { kind: 'recovered_unknown_outcome', state: recovered };
    }
    // Expired claim that never reached FCM (retried below with the same
    // attempt id), or an attempt of an older cycle. An older-cycle attempt
    // that may have reached FCM stays explicitly unknown; it is not counted
    // because new activity already restarted the sequence.
    state = {
      ...state,
      leaseId: null,
      leaseExpiresAtMs: null,
      lastAttempt:
        stale === null || stale.cycleId === state.cycleId
          ? stale
          : finishAttempt(stale, stale.status === 'sending' ? 'outcome_unknown' : 'superseded', nowMs),
    };
  }

  if (state.nextReminderAtMs === null || state.nextReminderAtMs > nowMs) {
    return { kind: 'skip', reason: 'not_due' };
  }
  const reminderNumber = state.remindersSentInCycle + 1;
  if (dueAtOf(state, lastActivityAtMs, policy) > nowMs) return { kind: 'skip', reason: 'not_due' };
  const attemptId = attemptIdFor(cycleId, reminderNumber);

  // Backlog: spread over the coming days instead of sending in a burst.
  // The reminder number, activity and cadence anchors are unchanged.
  if (nowMs - state.nextReminderAtMs > policy.delivery.backlog.overdueAfterMs) {
    return {
      kind: 'postpone',
      reason: 'backlog',
      state: {
        ...state,
        // Per user AND per reminder: users with the same activity time
        // (same attempt id) must not share one slot.
        nextReminderAtMs: backlogSlotAt({ key: `${params.uid}|${attemptId}`, nowMs, timeZone: state.timeZone, policy }),
        updatedAtMs: nowMs,
      },
    };
  }

  if (!isWithinDeliveryWindow(nowMs, state.timeZone, policy)) {
    return {
      kind: 'postpone',
      reason: 'quiet_hours',
      state: {
        ...state,
        nextReminderAtMs: firstDeliverableAt(nowMs, state.timeZone, policy),
        updatedAtMs: nowMs,
      },
    };
  }

  const claim: ReminderClaim = {
    cycleId,
    reminderNumber,
    attemptId,
    leaseId: params.leaseId,
    language: state.language,
  };
  return {
    kind: 'claim',
    claim,
    state: {
      ...state,
      leaseId: params.leaseId,
      leaseExpiresAtMs: nowMs + policy.delivery.leaseMs,
      lastAttempt: {
        id: attemptId,
        cycleId,
        reminderNumber,
        status: 'claimed',
        claimedAtMs: nowMs,
        sendingAtMs: null,
        completedAtMs: null,
        acceptedDevices: 0,
        invalidDevices: 0,
        failedDevices: 0,
        unknownDevices: 0,
      },
      updatedAtMs: nowMs,
    },
  };
}

type Interrupted = 'lease_lost' | 'superseded' | 'disabled';

function holdsLease(state: InactivityState | null, claim: ReminderClaim, nowMs: number): state is InactivityState {
  return (
    state !== null &&
    state.leaseId === claim.leaseId &&
    state.leaseExpiresAtMs !== null &&
    state.leaseExpiresAtMs > nowMs
  );
}

function interrupt(
  state: InactivityState,
  status: 'superseded' | 'cancelled',
  nowMs: number,
): InactivityState {
  return {
    ...state,
    leaseId: null,
    leaseExpiresAtMs: null,
    lastAttempt: finishAttempt(state.lastAttempt, status, nowMs),
    updatedAtMs: nowMs,
  };
}

/**
 * Last check before handing the message to FCM. Fails when the lease was
 * lost, the claimed attempt is no longer the recorded one, new activity
 * arrived (new cycle) or reminders were disabled. On success the attempt is
 * durably `sending` BEFORE anything reaches FCM: that marker is what lets
 * crash recovery tell "may have been sent" from "never sent".
 */
export function beginSending(params: {
  readonly state: InactivityState | null;
  readonly claim: ReminderClaim;
  readonly nowMs: number;
}):
  | { readonly ok: true; readonly state: InactivityState }
  | { readonly ok: false; readonly reason: Interrupted; readonly state: InactivityState | null } {
  const { state, claim, nowMs } = params;
  if (!holdsLease(state, claim, nowMs)) return { ok: false, reason: 'lease_lost', state: null };
  const attempt = state.lastAttempt;
  if (attempt === null || attempt.id !== claim.attemptId || attempt.status !== 'claimed') {
    return { ok: false, reason: 'lease_lost', state: null };
  }
  if (state.cycleId !== claim.cycleId) {
    return { ok: false, reason: 'superseded', state: interrupt(state, 'superseded', nowMs) };
  }
  if (!state.enabled) return { ok: false, reason: 'disabled', state: interrupt(state, 'cancelled', nowMs) };
  return {
    ok: true,
    state: {
      ...state,
      lastAttempt: { ...attempt, status: 'sending', sendingAtMs: nowMs },
      updatedAtMs: nowMs,
    },
  };
}

/** Per-device counts of one send. FCM acceptance is not device delivery. */
export interface DeliveryCounts {
  readonly acceptedDevices: number;
  readonly invalidDevices: number;
  readonly failedDevices: number;
  readonly unknownDevices: number;
}

/**
 * Send-result policy (deterministic; see the counting rule above):
 * - FCM accepted it for at least one device: `accepted`, counted, and the
 *   next reminder is scheduled from now by the cadence;
 * - otherwise, any device with an unknown outcome (FCM may have accepted
 *   it): `outcome_unknown`, counted the same way and never re-sent;
 * - otherwise, no deliverable device: nothing counted; checked again after
 *   `noDeviceRetryMs`;
 * - otherwise (every device failed): nothing counted; the SAME attempt id is
 *   retried after `retryBackoffMs[failures - 1]` (the last value repeats).
 * If new activity started a new cycle meanwhile, the attempt is superseded
 * and the schedule (already reset by that activity) is left alone.
 */
export function completeAttempt(params: {
  readonly state: InactivityState | null;
  readonly claim: ReminderClaim;
  readonly counts: DeliveryCounts;
  readonly nowMs: number;
  readonly policy: ReminderPolicy;
}): { readonly ok: true; readonly state: InactivityState } | { readonly ok: false; readonly reason: 'lease_lost' } {
  const { state, claim, counts, nowMs, policy } = params;
  if (!holdsLease(state, claim, nowMs)) return { ok: false, reason: 'lease_lost' };
  const released = { ...state, leaseId: null, leaseExpiresAtMs: null, updatedAtMs: nowMs };

  if (state.cycleId !== claim.cycleId) {
    return {
      ok: true,
      state: { ...released, lastAttempt: finishAttempt(state.lastAttempt, 'superseded', nowMs, counts) },
    };
  }
  if (counts.acceptedDevices > 0 || counts.unknownDevices > 0) {
    return {
      ok: true,
      state: reschedule(
        {
          ...released,
          remindersSentInCycle: claim.reminderNumber,
          lastReminderSentAtMs: nowMs,
          consecutiveFailures: 0,
          lastAttempt: finishAttempt(
            state.lastAttempt,
            counts.acceptedDevices > 0 ? 'accepted' : 'outcome_unknown',
            nowMs,
            counts,
          ),
        },
        nowMs,
        policy,
      ),
    };
  }
  const deliverable = counts.failedDevices > 0;
  if (!deliverable) {
    return {
      ok: true,
      state: {
        ...released,
        nextReminderAtMs: remindersActive(state)
          ? firstDeliverableAt(nowMs + policy.delivery.noDeviceRetryMs, state.timeZone, policy)
          : null,
        lastAttempt: finishAttempt(state.lastAttempt, 'no_deliverable_device', nowMs, counts),
      },
    };
  }
  const failures = state.consecutiveFailures + 1;
  const backoffs = policy.delivery.retryBackoffMs;
  const backoffMs =
    backoffs.length === 0 ? policy.delivery.noDeviceRetryMs : backoffs[Math.min(failures, backoffs.length) - 1];
  return {
    ok: true,
    state: {
      ...released,
      consecutiveFailures: failures,
      nextReminderAtMs: remindersActive(state)
        ? firstDeliverableAt(nowMs + backoffMs, state.timeZone, policy)
        : null,
      lastAttempt: finishAttempt(state.lastAttempt, 'retryable_failure', nowMs, counts),
    },
  };
}
