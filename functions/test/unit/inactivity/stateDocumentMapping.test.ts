import { Timestamp } from 'firebase-admin/firestore';
import { applyActivity, applyPreferences, decideClaim } from '../../../src/inactivity/domain/inactivityState';
import { defaultReminderPolicy as policy } from '../../../src/inactivity/domain/reminderPolicy';
import { resolveReminderPreferences } from '../../../src/inactivity/domain/reminderPreferences';
import {
  inactivityStateFromData,
  inactivityStateToData,
} from '../../../src/inactivity/infrastructure/firestoreInactivityStateStore';
import { HOUR } from '../../support/inactivityFakes';
import { dartLocalIso, SATURDAY_18_CAIRO as ACT } from '../../support/inactivityHarness';

function claimedState() {
  const { state } = applyActivity({
    state: applyPreferences({
      fromAppDocument: true,
      state: null,
      preferences: resolveReminderPreferences(null, policy),
      nowMs: 0,
      policy,
    }),
    source: 'session',
    occurredAtRaw: dartLocalIso(ACT),
    receivedAtMs: ACT + 1,
    defaultPreferences: resolveReminderPreferences(null, policy),
    nowMs: ACT + 1,
    policy,
  });
  const decision = decideClaim({ uid: 'u', state, nowMs: ACT + 48 * HOUR, leaseId: 'lease-1', policy });
  if (decision.kind !== 'claim') throw new Error(decision.kind);
  return decision.state;
}

describe('state document mapping', () => {
  test('round-trips every field; instants are stored as Timestamps', () => {
    const state = claimedState();
    const data = inactivityStateToData(state);
    expect(data).toMatchObject({
      schemaVersion: 1,
      lastActivityAt: Timestamp.fromMillis(ACT),
      lastActivityReceivedAt: Timestamp.fromMillis(ACT + 1),
      nextReminderAt: Timestamp.fromMillis(ACT + 48 * HOUR),
      leaseExpiresAt: Timestamp.fromMillis(ACT + 48 * HOUR + policy.delivery.leaseMs),
      lastAttempt: { status: 'claimed', claimedAt: Timestamp.fromMillis(ACT + 48 * HOUR) },
    });
    expect(inactivityStateFromData(data, policy)).toEqual(state);

    const withGrace = { ...state, reactivationGraceUntilMs: ACT + 99 * HOUR };
    const graceData = inactivityStateToData(withGrace);
    expect(graceData.reactivationGraceUntil).toEqual(Timestamp.fromMillis(ACT + 99 * HOUR));
    expect(inactivityStateFromData(graceData, policy)).toEqual(withGrace);
    expect(graceData.lastAttempt).toMatchObject({ unknownDevices: 0 });
  });

  test('stores no token, uid, message text or device identifiers', () => {
    const keys = Object.keys(inactivityStateToData(claimedState())).sort();
    expect(keys).toEqual(
      [
        'appSupportsServerReminders', 'consecutiveFailures', 'cycleId', 'enabled', 'language', 'lastActivityAt', 'lastActivityOccurredAt',
        'lastActivityReceivedAt', 'lastActivitySource', 'lastActivityTimeQuality', 'lastAttempt', 'lastReminderSentAt',
        'leaseExpiresAt', 'leaseId', 'nextReminderAt', 'nextReminderDueAt', 'reactivationGraceUntil',
        'remindersSentInCycle', 'schemaVersion', 'timeZone', 'updatedAt',
      ].sort(),
    );
  });

  test('corrupt fields fall back to safe defaults instead of failing', () => {
    const state = inactivityStateFromData(
      {
        lastActivityAt: '2026-11-07',
        nextReminderAt: 12345,
        enabled: 'yes',
        language: 'fr',
        timeZone: 'Nowhere/Land',
        leaseId: '',
        leaseExpiresAt: null,
        remindersSentInCycle: -3,
        consecutiveFailures: 1.5,
        lastActivitySource: 'app_open',
        lastAttempt: { id: 'x', status: 'exploded' },
      },
      policy,
    );
    expect(state).toMatchObject({
      lastActivityAtMs: null,
      nextReminderAtMs: null, // never selected by the due query
      enabled: true,
      language: 'ar',
      timeZone: 'Africa/Cairo',
      leaseId: null,
      remindersSentInCycle: 0,
      consecutiveFailures: 0,
      lastActivitySource: null,
      lastAttempt: null,
      appSupportsServerReminders: false, // missing: fails closed
    });
    // Never claimable: unconfirmed app (checked first) and no history.
    expect(decideClaim({ uid: 'u', state, nowMs: ACT, leaseId: 'x', policy })).toEqual({ kind: 'skip', reason: 'app_not_ready' });
    expect(decideClaim({ uid: 'u', state: { ...state, appSupportsServerReminders: true }, nowMs: ACT, leaseId: 'x', policy }))
      .toEqual({ kind: 'skip', reason: 'no_history' });
  });
});
