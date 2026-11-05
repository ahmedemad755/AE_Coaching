import { createHash, randomUUID } from 'node:crypto';
import { FieldValue, Firestore, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { getMessaging, Messaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';

export const INACTIVITY_THRESHOLD_MS = 3 * 24 * 60 * 60 * 1000;
export const INACTIVITY_REMINDER_SCHEDULE = '0 19 * * *';
export const INACTIVITY_REMINDER_TIME_ZONE = 'Africa/Cairo';
export const INACTIVITY_SEND_LEASE_MS = 26 * 60 * 60 * 1000;

const MAX_MULTICAST_TOKENS = 500;
const TOKEN_PLATFORMS = new Set(['android', 'ios', 'macos']);
const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

export interface InactivityStateRecord {
  uid: string;
  data: Record<string, unknown>;
}

export interface FcmTokenRecord {
  id: string;
  token: unknown;
  platform: unknown;
}

export interface InactivityReminderStore {
  listInactivityStates(): Promise<InactivityStateRecord[]>;
  hasCompletedWorkout(uid: string, cycleId: string): Promise<boolean>;
  listFcmTokens(uid: string): Promise<FcmTokenRecord[]>;
  deleteTokens(uid: string, tokenIds: string[]): Promise<void>;
  claimCycle(params: {
    uid: string;
    cycleId: string;
    leaseId: string;
    nowMs: number;
  }): Promise<boolean>;
  markCycleSent(params: {
    uid: string;
    cycleId: string;
    leaseId: string;
  }): Promise<boolean>;
  releaseCycle(params: {
    uid: string;
    cycleId: string;
    leaseId: string;
  }): Promise<void>;
}

export interface InactivitySendResult {
  successCount: number;
  responses: Array<{
    success: boolean;
    errorCode?: string;
  }>;
}

export interface InactivityReminderSender {
  send(params: {
    tokens: string[];
    cycleId: string;
    language?: string;
  }): Promise<InactivitySendResult>;
}

export interface InactivityReminderPassResult {
  statesChecked: number;
  sent: number;
  noToken: number;
  errors: number;
}

export function isValidCycleId(value: unknown): value is string {
  return typeof value === 'string' && /^[a-z0-9_]{1,128}$/i.test(value);
}

function timestampMillis(value: unknown): number | null {
  if (value instanceof Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return null;
}

export function isInactivityReminderEligible(
  state: Record<string, unknown>,
  nowMs: number,
): boolean {
  const cycleId = state.inactivityCycleId;
  const lastCompletedAt = timestampMillis(state.lastCompletedWorkoutAt);
  if (
    state.inactivityRemindersEnabled !== true ||
    lastCompletedAt === null ||
    nowMs - lastCompletedAt < INACTIVITY_THRESHOLD_MS ||
    state.reminderSentForCycle !== false ||
    !isValidCycleId(cycleId)
  ) {
    return false;
  }

  return !(
    state.sendState === 'sent' &&
    state.claimedCycleId === cycleId
  );
}

export function inactivityNotificationContent(language?: string): {
  title: string;
  body: string;
} {
  if (language?.toLowerCase().split('-')[0] === 'ar') {
    return {
      title: 'وقت الرجوع للتمرين 💪',
      body: 'بقالك 3 أيام من غير تمرين. يلا نرجع تاني.',
    };
  }
  return {
    title: 'Time to get back 💪',
    body: "You haven't trained in 3 days. Let's get back on track.",
  };
}

function tokenDocumentId(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function isValidToken(record: FcmTokenRecord): record is FcmTokenRecord & {
  token: string;
  platform: string;
} {
  return (
    typeof record.token === 'string' &&
    record.token.trim().length > 0 &&
    TOKEN_PLATFORMS.has(record.platform as string) &&
    record.id === tokenDocumentId(record.token)
  );
}

export async function runInactivityReminderPass(params: {
  store: InactivityReminderStore;
  sender: InactivityReminderSender;
  nowMs: number;
  createLeaseId?: () => string;
}): Promise<InactivityReminderPassResult> {
  const result: InactivityReminderPassResult = {
    statesChecked: 0,
    sent: 0,
    noToken: 0,
    errors: 0,
  };
  const states = await params.store.listInactivityStates();

  for (const record of states) {
    result.statesChecked++;
    const cycleId = record.data.inactivityCycleId;
    if (
      !isInactivityReminderEligible(record.data, params.nowMs) ||
      !isValidCycleId(cycleId)
    ) {
      continue;
    }

    try {
      if (!(await params.store.hasCompletedWorkout(record.uid, cycleId))) {
        continue;
      }

      const tokenRecords = await params.store.listFcmTokens(record.uid);
      const validTokens = tokenRecords.filter(isValidToken);
      const validIds = new Set(validTokens.map((token) => token.id));
      const malformedIds = tokenRecords
        .filter((token) => !validIds.has(token.id))
        .map((token) => token.id);
      if (malformedIds.length > 0) {
        try {
          await params.store.deleteTokens(record.uid, malformedIds);
        } catch {
          result.errors++;
        }
      }
      if (validTokens.length === 0) {
        result.noToken++;
        continue;
      }

      const leaseId = (params.createLeaseId ?? randomUUID)();
      const claimed = await params.store.claimCycle({
        uid: record.uid,
        cycleId,
        leaseId,
        nowMs: params.nowMs,
      });
      if (!claimed) continue;

      let deliveredAny = false;
      const staleTokenIds = new Set<string>();
      try {
        for (let offset = 0; offset < validTokens.length; offset += MAX_MULTICAST_TOKENS) {
          const batch = validTokens.slice(offset, offset + MAX_MULTICAST_TOKENS);
          const sendResult = await params.sender.send({
            tokens: batch.map((token) => token.token),
            cycleId,
            language: typeof record.data.language === 'string'
              ? record.data.language
              : undefined,
          });
          deliveredAny ||= sendResult.successCount > 0;
          sendResult.responses.forEach((response, index) => {
            if (
              batch[index] !== undefined &&
              !response.success &&
              response.errorCode !== undefined &&
              INVALID_TOKEN_CODES.has(response.errorCode)
            ) {
              staleTokenIds.add(batch[index].id);
            }
          });
        }
      } catch {
        result.errors++;
      }

      if (staleTokenIds.size > 0) {
        try {
          await params.store.deleteTokens(record.uid, [...staleTokenIds]);
        } catch {
          result.errors++;
        }
      }

      if (deliveredAny) {
        try {
          if (await params.store.markCycleSent({ uid: record.uid, cycleId, leaseId })) {
            result.sent++;
          }
        } catch {
          result.errors++;
        }
      } else {
        try {
          await params.store.releaseCycle({ uid: record.uid, cycleId, leaseId });
        } catch {
          result.errors++;
        }
      }
    } catch {
      result.errors++;
    }
  }

  return result;
}

export class FirestoreInactivityReminderStore implements InactivityReminderStore {
  constructor(private readonly db: Firestore) {}

  async listInactivityStates(): Promise<InactivityStateRecord[]> {
    const users = await this.db.collection('users').listDocuments();
    const records: InactivityStateRecord[] = [];
    const batchSize = 50;
    for (let offset = 0; offset < users.length; offset += batchSize) {
      const batch = users.slice(offset, offset + batchSize);
      const snapshots = await Promise.all(
        batch.map((user) => user.collection('notificationState').doc('inactivity').get()),
      );
      snapshots.forEach((snapshot, index) => {
        if (snapshot.exists) {
          records.push({ uid: batch[index].id, data: snapshot.data() ?? {} });
        }
      });
    }
    return records;
  }

  async hasCompletedWorkout(uid: string, cycleId: string): Promise<boolean> {
    if (!isValidCycleId(cycleId)) return false;
    const snapshot = await this.db
      .collection('users')
      .doc(uid)
      .collection('workout_sessions')
      .doc(cycleId)
      .get();
    const session = snapshot.data();
    return (
      snapshot.exists &&
      session?.id === cycleId &&
      session.status === 'completed' &&
      typeof session.completedAt === 'string' &&
      session.completedAt.length > 0
    );
  }

  async listFcmTokens(uid: string): Promise<FcmTokenRecord[]> {
    const snapshot = await this.db
      .collection('users')
      .doc(uid)
      .collection('fcmTokens')
      .get();
    return snapshot.docs.map((doc) => {
      const data = doc.data();
      return { id: doc.id, token: data.token, platform: data.platform };
    });
  }

  async deleteTokens(uid: string, tokenIds: string[]): Promise<void> {
    const tokenCollection = this.db.collection('users').doc(uid).collection('fcmTokens');
    for (let offset = 0; offset < tokenIds.length; offset += 450) {
      const batch = this.db.batch();
      tokenIds.slice(offset, offset + 450).forEach((id) => {
        batch.delete(tokenCollection.doc(id));
      });
      await batch.commit();
    }
  }

  async claimCycle(params: {
    uid: string;
    cycleId: string;
    leaseId: string;
    nowMs: number;
  }): Promise<boolean> {
    const stateRef = this.stateRef(params.uid);
    const workoutRef = this.db
      .collection('users')
      .doc(params.uid)
      .collection('workout_sessions')
      .doc(params.cycleId);
    return this.db.runTransaction(async (transaction) => {
      const [snapshot, workoutSnapshot] = await Promise.all([
        transaction.get(stateRef),
        transaction.get(workoutRef),
      ]);
      if (!snapshot.exists || !workoutSnapshot.exists) return false;
      const workout = workoutSnapshot.data();
      if (
        workout?.id !== params.cycleId ||
        workout.status !== 'completed' ||
        typeof workout.completedAt !== 'string' ||
        workout.completedAt.length === 0
      ) {
        return false;
      }

      const state = snapshot.data() ?? {};
      if (
        state.inactivityCycleId !== params.cycleId ||
        !isInactivityReminderEligible(state, params.nowMs)
      ) {
        return false;
      }

      if (
        state.sendState === 'sending' &&
        state.claimedCycleId === params.cycleId &&
        timestampMillis(state.leaseExpiresAt) !== null &&
        timestampMillis(state.leaseExpiresAt)! > params.nowMs
      ) {
        return false;
      }

      // The next daily run is 24 hours away; this lease also blocks a
      // scheduler retry after a crash between FCM acceptance and finalization.
      transaction.update(stateRef, {
        sendState: 'sending',
        claimedCycleId: params.cycleId,
        leaseId: params.leaseId,
        leaseExpiresAt: Timestamp.fromMillis(params.nowMs + INACTIVITY_SEND_LEASE_MS),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  async markCycleSent(params: {
    uid: string;
    cycleId: string;
    leaseId: string;
  }): Promise<boolean> {
    const stateRef = this.stateRef(params.uid);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(stateRef);
      const state = snapshot.data();
      if (!this.ownsActiveClaim(state, params)) return false;

      transaction.update(stateRef, {
        reminderSentForCycle: true,
        sendState: 'sent',
        leaseId: null,
        leaseExpiresAt: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  async releaseCycle(params: {
    uid: string;
    cycleId: string;
    leaseId: string;
  }): Promise<void> {
    const stateRef = this.stateRef(params.uid);
    await this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(stateRef);
      const state = snapshot.data();
      if (!this.ownsActiveClaim(state, params)) return;

      transaction.update(stateRef, {
        sendState: 'pending',
        leaseId: null,
        leaseExpiresAt: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  private stateRef(uid: string) {
    return this.db
      .collection('users')
      .doc(uid)
      .collection('notificationState')
      .doc('inactivity');
  }

  private ownsActiveClaim(
    state: FirebaseFirestore.DocumentData | undefined,
    params: { cycleId: string; leaseId: string },
  ): boolean {
    return (
      state?.inactivityCycleId === params.cycleId &&
      state?.claimedCycleId === params.cycleId &&
      state?.leaseId === params.leaseId &&
      state?.sendState === 'sending'
    );
  }
}

export class FirebaseInactivityReminderSender implements InactivityReminderSender {
  constructor(private readonly messaging: Messaging) {}

  async send(params: {
    tokens: string[];
    cycleId: string;
    language?: string;
  }): Promise<InactivitySendResult> {
    const copy = inactivityNotificationContent(params.language);
    const collapseId = createHash('sha256').update(params.cycleId).digest('hex');
    const response = await this.messaging.sendEachForMulticast({
      tokens: params.tokens,
      notification: copy,
      data: {
        type: 'inactivity_reminder',
        inactivityCycleId: params.cycleId,
      },
      android: { notification: { tag: `inactivity_${params.cycleId}` } },
      apns: { headers: { 'apns-collapse-id': collapseId } },
    });
    return {
      successCount: response.successCount,
      responses: response.responses.map((item) => ({
        success: item.success,
        errorCode: item.error?.code,
      })),
    };
  }
}

export const sendInactivityRemindersDaily = onSchedule(
  {
    schedule: INACTIVITY_REMINDER_SCHEDULE,
    timeZone: INACTIVITY_REMINDER_TIME_ZONE,
    timeoutSeconds: 540,
    memory: '512MiB',
  },
  async () => {
    try {
      const result = await runInactivityReminderPass({
        store: new FirestoreInactivityReminderStore(getFirestore()),
        sender: new FirebaseInactivityReminderSender(getMessaging()),
        nowMs: Date.now(),
      });
      logger.info('Daily inactivity reminder pass completed.', result);
    } catch {
      logger.error('Daily inactivity reminder pass failed.');
      throw new Error('Daily inactivity reminder pass failed.');
    }
  },
);
