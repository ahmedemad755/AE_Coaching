import { selectReminderMessage } from '../../../src/inactivity/domain/reminderMessages';
import { pseudonymForLogs } from '../../../src/shared/infrastructure/runtimeAdapters';
import { HOUR, token } from '../../support/inactivityFakes';
import { inactivityHarness, SATURDAY_18_CAIRO as ACT } from '../../support/inactivityHarness';

const MIN = 60_000;
const UID = 'user-K9pL-private';
const DUE = ACT + 48 * HOUR; // Monday 18:00 Cairo
const ATTEMPT_1 = `c${ACT}:r1`;

/** A user with one recorded workout at ACT, clock moved to the first due time. */
async function dueUser(devices = ['phone']) {
  const h = inactivityHarness(ACT);
  h.tokens.byUid.set(UID, devices.map(token));
  await h.activity(UID, 'set');
  h.clock.set(DUE);
  return h;
}

describe('DeliverDueReminder', () => {
  test('sends the due reminder once, in the user language, to their devices', async () => {
    const h = await dueUser(['phone', 'tablet']);
    await expect(h.deliver.execute(UID)).resolves.toBe('sent');
    expect(h.sender.sends).toEqual([
      { tokens: [token('phone'), token('tablet')], message: selectReminderMessage('ar', 1), attemptId: ATTEMPT_1 },
    ]);
    expect(h.store.get(UID)).toMatchObject({
      remindersSentInCycle: 1,
      lastReminderSentAtMs: DUE,
      nextReminderAtMs: DUE + 72 * HOUR,
      leaseId: null,
      lastAttempt: { id: ATTEMPT_1, status: 'accepted', acceptedDevices: 2 },
    });
    // Running again (duplicate scheduler run) sends nothing.
    await expect(h.deliver.execute(UID)).resolves.toBe('skipped');
    expect(h.sender.sends).toHaveLength(1);
  });

  test('not yet due, unknown user, or no history: skipped without sending', async () => {
    const h = await dueUser();
    h.clock.set(DUE - 1);
    await expect(h.deliver.execute(UID)).resolves.toBe('skipped');
    await expect(h.deliver.execute('nobody')).resolves.toBe('skipped');
    expect(h.sender.sends).toHaveLength(0);
  });

  test('concurrent senders for the same user: exactly one sends', async () => {
    const h = await dueUser();
    const results = await Promise.all(Array.from({ length: 6 }, () => h.deliver.execute(UID)));
    expect(results.filter((r) => r === 'sent')).toHaveLength(1);
    expect(results.filter((r) => r === 'skipped')).toHaveLength(5);
    expect(h.sender.sends).toHaveLength(1);
  });

  test('due outside quiet hours (scheduler outage) is postponed to 10:00', async () => {
    const h = await dueUser();
    h.clock.set(DUE + 4 * HOUR); // 22:00
    await expect(h.deliver.execute(UID)).resolves.toBe('postponed');
    expect(h.sender.sends).toHaveLength(0);
    h.clock.set(Date.UTC(2026, 10, 10, 8, 0)); // Tue 10:00
    await expect(h.deliver.execute(UID)).resolves.toBe('sent');
  });

  describe('crash windows', () => {
    test('crash after claiming, before FCM: retried after the lease with the same attempt id', async () => {
      const h = await dueUser();
      h.store.crashOnCommit = h.store.commits + 2; // the "sending" commit
      await expect(h.deliver.execute(UID)).rejects.toThrow('simulated crash');
      expect(h.sender.sends).toHaveLength(0);
      expect(h.store.get(UID)?.lastAttempt?.status).toBe('claimed');

      h.clock.advance(5 * MIN);
      await expect(h.deliver.execute(UID)).resolves.toBe('skipped'); // lease still held
      h.clock.set(DUE + h.policy.delivery.leaseMs);
      await expect(h.deliver.execute(UID)).resolves.toBe('sent');
      expect(h.sender.sends.map((s) => s.attemptId)).toEqual([ATTEMPT_1]);
    });

    test('crash after FCM accepted it: no duplicate; resolved as outcome_unknown', async () => {
      const h = await dueUser();
      h.store.crashOnCommit = h.store.commits + 3; // the completion commit
      await expect(h.deliver.execute(UID)).rejects.toThrow('simulated crash');
      expect(h.sender.sends).toHaveLength(1);
      expect(h.store.get(UID)?.lastAttempt?.status).toBe('sending');

      h.clock.advance(5 * MIN);
      await expect(h.deliver.execute(UID)).resolves.toBe('skipped');
      h.clock.set(DUE + h.policy.delivery.leaseMs);
      await expect(h.deliver.execute(UID)).resolves.toBe('recovered_unknown_outcome');
      expect(h.sender.sends).toHaveLength(1); // never re-sent
      expect(h.store.get(UID)).toMatchObject({
        remindersSentInCycle: 1,
        lastReminderSentAtMs: DUE,
        nextReminderAtMs: DUE + 72 * HOUR,
        lastAttempt: { id: ATTEMPT_1, status: 'outcome_unknown' },
      });

      h.clock.set(DUE + 72 * HOUR);
      await expect(h.deliver.execute(UID)).resolves.toBe('sent');
      expect(h.sender.sends.map((s) => s.attemptId)).toEqual([ATTEMPT_1, `c${ACT}:r2`]);
    });
  });

  describe('races with the user', () => {
    test('workout logged between claim and send: nothing is sent', async () => {
      const h = await dueUser();
      h.tokens.duringListing = async () => {
        h.tokens.duringListing = null;
        await h.activity(UID, 'set');
      };
      await expect(h.deliver.execute(UID)).resolves.toBe('superseded');
      expect(h.sender.sends).toHaveLength(0);
      expect(h.store.get(UID)).toMatchObject({
        cycleId: `c${DUE}`,
        remindersSentInCycle: 0,
        leaseId: null,
        nextReminderAtMs: DUE + 48 * HOUR,
        lastAttempt: { status: 'superseded' },
      });
    });

    test('workout logged while FCM handles the send: the new cycle wins', async () => {
      const h = await dueUser();
      h.sender.duringSend = async () => {
        h.sender.duringSend = null;
        await h.activity(UID, 'session');
      };
      await expect(h.deliver.execute(UID)).resolves.toBe('superseded');
      expect(h.sender.sends).toHaveLength(1); // already handed to FCM
      expect(h.store.get(UID)).toMatchObject({ remindersSentInCycle: 0, nextReminderAtMs: DUE + 48 * HOUR });
    });

    test('reminders turned off between claim and send: cancelled, nothing sent', async () => {
      const h = await dueUser();
      h.tokens.duringListing = async () => {
        h.preferences.byUid.set(UID, { inactivityRemindersEnabled: false });
        await h.sync.execute(UID);
      };
      await expect(h.deliver.execute(UID)).resolves.toBe('cancelled');
      expect(h.sender.sends).toHaveLength(0);
      expect(h.store.get(UID)).toMatchObject({ nextReminderAtMs: null, leaseId: null, lastAttempt: { status: 'cancelled' } });
    });
  });

  describe('devices and failures', () => {
    test('per-device results: accepted counts as sent, invalid tokens are removed', async () => {
      const h = await dueUser(['a', 'b', 'c']);
      h.sender.outcomes.set('b', 'invalid_token');
      h.sender.outcomes.set('c', 'retryable');
      await expect(h.deliver.execute(UID)).resolves.toBe('sent');
      expect(h.tokens.removed).toEqual([{ uid: UID, ids: ['b'] }]);
      expect(h.store.get(UID)?.lastAttempt).toMatchObject({ acceptedDevices: 1, invalidDevices: 1, failedDevices: 1 });
    });

    test('tokens the directory rejects are removed before sending', async () => {
      const h = await dueUser(['phone']);
      h.tokens.discardByUid.set(UID, ['transferred-elsewhere']);
      await h.deliver.execute(UID);
      expect(h.tokens.removed[0]).toEqual({ uid: UID, ids: ['transferred-elsewhere'] });
      expect(h.sender.sends[0].tokens).toEqual([token('phone')]);
    });

    test('no devices: not counted as sent, checked again in 24 h', async () => {
      const h = await dueUser([]);
      await expect(h.deliver.execute(UID)).resolves.toBe('no_deliverable_device');
      expect(h.sender.sends).toHaveLength(0);
      expect(h.store.get(UID)).toMatchObject({ remindersSentInCycle: 0, nextReminderAtMs: DUE + 24 * HOUR });
    });

    test('every device invalid: tokens removed, nothing counted', async () => {
      const h = await dueUser(['a', 'b']);
      h.sender.outcomes.set('a', 'invalid_token');
      h.sender.outcomes.set('b', 'invalid_token');
      await expect(h.deliver.execute(UID)).resolves.toBe('no_deliverable_device');
      expect(h.tokens.byUid.get(UID)).toEqual([]);
      expect(h.store.get(UID)?.remindersSentInCycle).toBe(0);
    });

    test('FCM unavailable: retried in 1 h with the same attempt id', async () => {
      const h = await dueUser();
      h.sender.throwError = true;
      await expect(h.deliver.execute(UID)).resolves.toBe('retry_scheduled');
      expect(h.store.get(UID)).toMatchObject({ remindersSentInCycle: 0, consecutiveFailures: 1, nextReminderAtMs: DUE + HOUR });
      h.sender.throwError = false;
      h.clock.set(DUE + HOUR);
      await expect(h.deliver.execute(UID)).resolves.toBe('sent');
      expect(h.sender.sends.map((s) => s.attemptId)).toEqual([ATTEMPT_1, ATTEMPT_1]);
    });

    test('no answer from FCM for a device: outcome_unknown, counted, never re-sent', async () => {
      const h = await dueUser(['a', 'b']);
      h.sender.outcomes.set('a', 'unknown');
      h.sender.outcomes.set('b', 'retryable');
      await expect(h.deliver.execute(UID)).resolves.toBe('outcome_unknown');
      expect(h.store.get(UID)).toMatchObject({
        remindersSentInCycle: 1,
        lastReminderSentAtMs: DUE,
        nextReminderAtMs: DUE + 72 * HOUR,
        lastAttempt: { status: 'outcome_unknown', unknownDevices: 1, failedDevices: 1 },
      });
      for (const later of [DUE + HOUR, DUE + 24 * HOUR]) {
        h.clock.set(later);
        await expect(h.deliver.execute(UID)).resolves.toBe('skipped');
      }
      expect(h.sender.sends.map((s) => s.attemptId)).toEqual([ATTEMPT_1]);
    });

    test('every device failed (FCM answered, nothing accepted): the same attempt is retried', async () => {
      const h = await dueUser(['a']);
      h.sender.outcomes.set('a', 'failed');
      await expect(h.deliver.execute(UID)).resolves.toBe('retry_scheduled');
      expect(h.store.get(UID)).toMatchObject({ remindersSentInCycle: 0, nextReminderAtMs: DUE + HOUR });
    });

    test('device lookup failure: no send, retried with backoff', async () => {
      const h = await dueUser();
      h.tokens.failListing = true;
      await expect(h.deliver.execute(UID)).resolves.toBe('retry_scheduled');
      expect(h.sender.sends).toHaveLength(0);
      expect(h.store.get(UID)).toMatchObject({ leaseId: null, nextReminderAtMs: DUE + HOUR });
    });

    test('token cleanup failure does not fail the reminder', async () => {
      const h = await dueUser(['a', 'b']);
      h.sender.outcomes.set('b', 'invalid_token');
      h.tokens.removeTokens = async () => {
        throw new Error('write failed');
      };
      await expect(h.deliver.execute(UID)).resolves.toBe('sent');
      expect(h.logger.entries.some((e) => e.event === 'inactivity_token_cleanup_failed')).toBe(true);
    });
  });

  test('logs carry no uid, raw token, token id or activity-derived attempt id', async () => {
    const h = await dueUser(['phone-token-id']);
    h.sender.outcomes.set('phone-token-id', 'invalid_token');
    await h.deliver.execute(UID);
    const logs = h.logger.text();
    for (const secret of [UID, token('phone-token-id').token, 'phone-token-id', ATTEMPT_1, String(ACT)]) {
      expect(logs).not.toContain(secret);
    }
    expect(logs).toContain(pseudonymForLogs(UID));
  });
});
