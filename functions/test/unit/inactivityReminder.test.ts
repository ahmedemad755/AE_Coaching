import { createHash } from 'node:crypto';
import { Timestamp } from 'firebase-admin/firestore';
import {
  FirebaseInactivityReminderSender,
  INACTIVITY_REMINDER_SCHEDULE,
  INACTIVITY_REMINDER_TIME_ZONE,
  INACTIVITY_THRESHOLD_MS,
  InactivityReminderSender,
  InactivityReminderStore,
  InactivitySendResult,
  InactivityStateRecord,
  FcmTokenRecord,
  isInactivityReminderEligible,
  runInactivityReminderPass,
} from '../../src/inactivityReminder';
import { Messaging } from 'firebase-admin/messaging';

const NOW = Date.UTC(2026, 0, 10, 19);
const CYCLE = 'session_100_abc123';

function state(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    lastCompletedWorkoutAt: Timestamp.fromMillis(NOW - INACTIVITY_THRESHOLD_MS),
    inactivityRemindersEnabled: true,
    inactivityCycleId: CYCLE,
    reminderSentForCycle: false,
    updatedAt: Timestamp.fromMillis(NOW),
    ...overrides,
  };
}

function tokenRecord(token: string, platform = 'android'): FcmTokenRecord {
  return {
    id: createHash('sha256').update(token).digest('hex'),
    token,
    platform,
  };
}

class MemoryReminderStore implements InactivityReminderStore {
  readonly states = new Map<string, Record<string, unknown>>();
  readonly completedCycles = new Set<string>();
  readonly tokens = new Map<string, FcmTokenRecord[]>();

  async listInactivityStates(): Promise<InactivityStateRecord[]> {
    return [...this.states.entries()].map(([uid, data]) => ({ uid, data }));
  }

  async hasCompletedWorkout(uid: string, cycleId: string): Promise<boolean> {
    return this.completedCycles.has(`${uid}/${cycleId}`);
  }

  async listFcmTokens(uid: string): Promise<FcmTokenRecord[]> {
    return [...(this.tokens.get(uid) ?? [])];
  }

  async deleteTokens(uid: string, tokenIds: string[]): Promise<void> {
    const ids = new Set(tokenIds);
    this.tokens.set(
      uid,
      (this.tokens.get(uid) ?? []).filter((token) => !ids.has(token.id)),
    );
  }

  async claimCycle(params: {
    uid: string;
    cycleId: string;
    leaseId: string;
    nowMs: number;
  }): Promise<boolean> {
    const current = this.states.get(params.uid);
    if (
      !current ||
      current.inactivityCycleId !== params.cycleId ||
      !this.completedCycles.has(`${params.uid}/${params.cycleId}`) ||
      !isInactivityReminderEligible(current, params.nowMs)
    ) {
      return false;
    }

    const leaseExpiresAt = current.leaseExpiresAt as Timestamp | undefined;
    if (
      current.sendState === 'sending' &&
      current.claimedCycleId === params.cycleId &&
      leaseExpiresAt !== undefined &&
      leaseExpiresAt.toMillis() > params.nowMs
    ) {
      return false;
    }

    this.states.set(params.uid, {
      ...current,
      sendState: 'sending',
      claimedCycleId: params.cycleId,
      leaseId: params.leaseId,
      leaseExpiresAt: Timestamp.fromMillis(NOW + 26 * 60 * 60 * 1000),
    });
    return true;
  }

  async markCycleSent(params: {
    uid: string;
    cycleId: string;
    leaseId: string;
  }): Promise<boolean> {
    const current = this.states.get(params.uid);
    if (!this.ownsClaim(current, params)) return false;
    this.states.set(params.uid, {
      ...current,
      reminderSentForCycle: true,
      sendState: 'sent',
      leaseId: null,
      leaseExpiresAt: null,
    });
    return true;
  }

  async releaseCycle(params: {
    uid: string;
    cycleId: string;
    leaseId: string;
  }): Promise<void> {
    const current = this.states.get(params.uid);
    if (!this.ownsClaim(current, params)) return;
    this.states.set(params.uid, {
      ...current,
      sendState: 'pending',
      leaseId: null,
      leaseExpiresAt: null,
    });
  }

  private ownsClaim(
    current: Record<string, unknown> | undefined,
    params: { cycleId: string; leaseId: string },
  ): current is Record<string, unknown> {
    return (
      current?.inactivityCycleId === params.cycleId &&
      current.claimedCycleId === params.cycleId &&
      current.leaseId === params.leaseId &&
      current.sendState === 'sending'
    );
  }
}

class FakeSender implements InactivityReminderSender {
  readonly calls: Array<{ tokens: string[]; cycleId: string; language?: string }> = [];
  fail = false;
  responseFactory?: (tokens: string[]) => InactivitySendResult;

  async send(params: {
    tokens: string[];
    cycleId: string;
    language?: string;
  }): Promise<InactivitySendResult> {
    this.calls.push({
      tokens: [...params.tokens],
      cycleId: params.cycleId,
      language: params.language,
    });
    if (this.fail) throw new Error('simulated FCM transport failure');
    return (
      this.responseFactory?.(params.tokens) ?? {
        successCount: params.tokens.length,
        responses: params.tokens.map(() => ({ success: true })),
      }
    );
  }
}

function eligibleStore(uid = 'user-a', cycleId = CYCLE): MemoryReminderStore {
  const store = new MemoryReminderStore();
  store.states.set(uid, state({ inactivityCycleId: cycleId }));
  store.completedCycles.add(`${uid}/${cycleId}`);
  store.tokens.set(uid, [tokenRecord(`${uid}-device-token`)]);
  return store;
}

describe('inactivity reminder scheduling policy', () => {
  test('uses a fixed threshold of exactly three full days', () => {
    expect(INACTIVITY_THRESHOLD_MS).toBe(3 * 24 * 60 * 60 * 1000);
    expect(INACTIVITY_REMINDER_SCHEDULE).toBe('0 19 * * *');
    expect(INACTIVITY_REMINDER_TIME_ZONE).toBe('Africa/Cairo');
  });

  test('less than three full days is not eligible', async () => {
    const store = eligibleStore();
    store.states.set('user-a', state({
      lastCompletedWorkoutAt: Timestamp.fromMillis(NOW - INACTIVITY_THRESHOLD_MS + 1),
    }));
    const sender = new FakeSender();

    await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(sender.calls).toHaveLength(0);
  });

  test('exactly three full days and older are eligible', async () => {
    const store = eligibleStore();
    store.states.set('older-user', state({
      lastCompletedWorkoutAt: Timestamp.fromMillis(NOW - INACTIVITY_THRESHOLD_MS - 1),
      inactivityCycleId: 'session_older_1',
    }));
    store.completedCycles.add('older-user/session_older_1');
    store.tokens.set('older-user', [tokenRecord('older-user-token')]);
    const sender = new FakeSender();

    await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(sender.calls).toHaveLength(2);
    expect(sender.calls.map((call) => call.cycleId).sort()).toEqual([
      CYCLE,
      'session_older_1',
    ].sort());
  });

  test('reminders OFF prevents sending', async () => {
    const store = eligibleStore();
    store.states.set('user-a', state({ inactivityRemindersEnabled: false }));
    const sender = new FakeSender();

    await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(sender.calls).toHaveLength(0);
  });

  test('a cycle already marked sent is never sent again', async () => {
    const store = eligibleStore();
    store.states.set('user-a', state({ reminderSentForCycle: true }));
    const sender = new FakeSender();

    await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(sender.calls).toHaveLength(0);
  });

  test('a cycle without a matching completed workout is not sent', async () => {
    const store = eligibleStore();
    store.completedCycles.clear();
    const sender = new FakeSender();

    await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(sender.calls).toHaveLength(0);
    expect(store.states.get('user-a')?.sendState).toBeUndefined();
  });

  test('a new completed-workout cycle gets its own three-day eligibility', async () => {
    const store = eligibleStore('user-a', 'session_new_2');
    store.states.set('user-a', state({
      inactivityCycleId: 'session_new_2',
      lastCompletedWorkoutAt: Timestamp.fromMillis(NOW - INACTIVITY_THRESHOLD_MS + 1),
      reminderSentForCycle: false,
      sendState: 'sent',
      claimedCycleId: CYCLE,
    }));
    store.completedCycles.add('user-a/session_new_2');
    const sender = new FakeSender();

    await runInactivityReminderPass({ store, sender, nowMs: NOW });
    expect(sender.calls).toHaveLength(0);

    store.states.set('user-a', state({
      inactivityCycleId: 'session_new_2',
      lastCompletedWorkoutAt: Timestamp.fromMillis(NOW - INACTIVITY_THRESHOLD_MS),
      reminderSentForCycle: false,
      sendState: 'sent',
      claimedCycleId: CYCLE,
    }));
    await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(sender.calls).toHaveLength(1);
    expect(sender.calls[0].cycleId).toBe('session_new_2');
  });

  test('concurrent and repeated passes make no intentional duplicate send', async () => {
    const store = eligibleStore();
    const sender = new FakeSender();

    await Promise.all([
      runInactivityReminderPass({ store, sender, nowMs: NOW }),
      runInactivityReminderPass({ store, sender, nowMs: NOW }),
    ]);
    await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(sender.calls).toHaveLength(1);
    expect(store.states.get('user-a')?.sendState).toBe('sent');
  });

  test('a failed FCM send releases the claim and remains retryable', async () => {
    const store = eligibleStore();
    const sender = new FakeSender();
    sender.fail = true;

    await runInactivityReminderPass({ store, sender, nowMs: NOW });
    expect(store.states.get('user-a')?.reminderSentForCycle).toBe(false);
    expect(store.states.get('user-a')?.sendState).toBe('pending');

    sender.fail = false;
    await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(sender.calls).toHaveLength(2);
    expect(store.states.get('user-a')?.reminderSentForCycle).toBe(true);
  });

  test('successful FCM send marks the cycle sent', async () => {
    const store = eligibleStore();
    const sender = new FakeSender();

    const result = await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(result.sent).toBe(1);
    expect(store.states.get('user-a')?.reminderSentForCycle).toBe(true);
    expect(store.states.get('user-a')?.sendState).toBe('sent');
  });

  test('invalid tokens are deleted only from the owning user', async () => {
    const store = eligibleStore();
    const staleToken = tokenRecord('stale-device-token');
    store.tokens.set('user-a', [staleToken]);
    store.tokens.set('user-b', [staleToken]);
    store.states.set('user-b', state({
      inactivityRemindersEnabled: false,
      inactivityCycleId: 'session_user_b',
    }));
    const sender = new FakeSender();
    sender.responseFactory = (tokens) => ({
      successCount: 0,
      responses: tokens.map(() => ({
        success: false,
        errorCode: 'messaging/registration-token-not-registered',
      })),
    });

    await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(store.tokens.get('user-a')).toHaveLength(0);
    expect(store.tokens.get('user-b')).toEqual([staleToken]);
    expect(store.states.get('user-a')?.reminderSentForCycle).toBe(false);
  });

  test('no valid token does not claim or falsely mark a cycle sent', async () => {
    const store = eligibleStore();
    store.tokens.set('user-a', []);
    const sender = new FakeSender();

    const result = await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(result.noToken).toBe(1);
    expect(sender.calls).toHaveLength(0);
    expect(store.states.get('user-a')?.reminderSentForCycle).toBe(false);
    expect(store.states.get('user-a')?.sendState).toBeUndefined();
  });

  test('users cannot receive another user\'s tokens or alter their state', async () => {
    const store = eligibleStore();
    store.states.set('user-b', state({
      inactivityRemindersEnabled: false,
      inactivityCycleId: 'session_user_b',
    }));
    store.completedCycles.add('user-b/session_user_b');
    store.tokens.set('user-b', [tokenRecord('user-b-private-token')]);
    const sender = new FakeSender();
    const before = { ...store.states.get('user-b')! };

    await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(sender.calls).toEqual([
      { tokens: ['user-a-device-token'], cycleId: CYCLE },
    ]);
    expect(store.states.get('user-b')).toEqual(before);
  });

  test('Admin sender uses the required notification text and routing data', async () => {
    const sentMessages: unknown[] = [];
    const messaging = {
      sendEachForMulticast: async (message: unknown) => {
        sentMessages.push(message);
        return {
          successCount: 1,
          responses: [{ success: true }],
        };
      },
    } as unknown as Messaging;
    const sender = new FirebaseInactivityReminderSender(messaging);

    await sender.send({ tokens: ['test-token'], cycleId: CYCLE });
    await sender.send({ tokens: ['test-token'], cycleId: CYCLE, language: 'ar' });

    const english = sentMessages[0] as {
      notification: { title: string; body: string };
      data: Record<string, string>;
      tokens: string[];
    };
    const arabic = sentMessages[1] as {
      notification: { title: string; body: string };
    };
    expect(english.notification).toEqual({
      title: 'Time to get back 💪',
      body: "You haven't trained in 3 days. Let's get back on track.",
    });
    expect(english.data.type).toBe('inactivity_reminder');
    expect(english.data.inactivityCycleId).toBe(CYCLE);
    expect(english.tokens).toEqual(['test-token']);
    expect(arabic.notification).toEqual({
      title: 'وقت الرجوع للتمرين 💪',
      body: 'بقالك 3 أيام من غير تمرين. يلا نرجع تاني.',
    });
  });

  test('scheduler passes the persisted user language to the sender', async () => {
    const store = eligibleStore();
    store.states.set('user-a', state({ language: 'ar' }));
    const sender = new FakeSender();

    await runInactivityReminderPass({ store, sender, nowMs: NOW });

    expect(sender.calls[0].language).toBe('ar');
  });
});
