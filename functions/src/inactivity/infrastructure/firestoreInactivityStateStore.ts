import {
  type DocumentData,
  type DocumentReference,
  type Firestore,
  type QueryDocumentSnapshot,
  Timestamp,
} from 'firebase-admin/firestore';
import type { ActivitySource, ActivityTimeQuality } from '../domain/activityTime';
import type { AttemptStatus, InactivityState, ReminderAttempt } from '../domain/inactivityState';
import type { ReminderPolicy } from '../domain/reminderPolicy';
import { isReminderLanguage } from '../domain/reminderPreferences';
import { effectiveTimeZone } from '../domain/reminderSchedule';
import type { DueReminderFinder, DueReminderPage, InactivityStateStore } from '../application/ports';

/**
 * `users/{uid}/notificationState/inactivity`: server-owned (written only by
 * these functions through the Admin SDK; clients never write it).
 */
export const NOTIFICATION_STATE_COLLECTION = 'notificationState';
export const INACTIVITY_STATE_DOC = 'inactivity';
const SCHEMA_VERSION = 1;

const ACTIVITY_SOURCES: readonly ActivitySource[] = ['session', 'set'];
const TIME_QUALITIES: readonly ActivityTimeQuality[] = ['client', 'missing', 'invalid', 'future', 'too_old'];
const ATTEMPT_STATUSES: readonly AttemptStatus[] = [
  'claimed',
  'sending',
  'accepted',
  'no_deliverable_device',
  'retryable_failure',
  'outcome_unknown',
  'superseded',
  'cancelled',
];

function oneOf<T extends string>(value: unknown, allowed: readonly T[]): T | null {
  return typeof value === 'string' && (allowed as readonly string[]).includes(value) ? (value as T) : null;
}

function millis(value: unknown): number | null {
  return value instanceof Timestamp ? value.toMillis() : null;
}

function count(value: unknown): number {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value : 0;
}

function text(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function timestamp(ms: number | null): Timestamp | null {
  return ms === null ? null : Timestamp.fromMillis(ms);
}

function attemptFromData(value: unknown): ReminderAttempt | null {
  if (typeof value !== 'object' || value === null) return null;
  const data = value as Record<string, unknown>;
  const id = text(data.id);
  const cycleId = text(data.cycleId);
  const status = oneOf(data.status, ATTEMPT_STATUSES);
  const claimedAtMs = millis(data.claimedAt);
  const reminderNumber = count(data.reminderNumber);
  if (id === null || cycleId === null || status === null || claimedAtMs === null || reminderNumber < 1) {
    return null;
  }
  return {
    id,
    cycleId,
    reminderNumber,
    status,
    claimedAtMs,
    sendingAtMs: millis(data.sendingAt),
    completedAtMs: millis(data.completedAt),
    acceptedDevices: count(data.acceptedDevices),
    invalidDevices: count(data.invalidDevices),
    failedDevices: count(data.failedDevices),
    unknownDevices: count(data.unknownDevices),
  };
}

/**
 * Maps a stored document to the domain state. Every field is validated;
 * a corrupt field falls back to its safe default (e.g. no lease, no
 * scheduled send) instead of failing the whole pass.
 */
export function inactivityStateFromData(data: DocumentData, policy: ReminderPolicy): InactivityState {
  return {
    lastActivityAtMs: millis(data.lastActivityAt),
    lastActivitySource: oneOf(data.lastActivitySource, ACTIVITY_SOURCES),
    lastActivityOccurredAtMs: millis(data.lastActivityOccurredAt),
    lastActivityReceivedAtMs: millis(data.lastActivityReceivedAt),
    lastActivityTimeQuality: oneOf(data.lastActivityTimeQuality, TIME_QUALITIES),
    cycleId: text(data.cycleId),
    remindersSentInCycle: count(data.remindersSentInCycle),
    lastReminderSentAtMs: millis(data.lastReminderSentAt),
    nextReminderDueAtMs: millis(data.nextReminderDueAt),
    nextReminderAtMs: millis(data.nextReminderAt),
    enabled: typeof data.enabled === 'boolean' ? data.enabled : policy.defaults.enabled,
    // Missing or invalid: not confirmed, so nothing is sent (fails closed).
    appSupportsServerReminders: data.appSupportsServerReminders === true,
    language: isReminderLanguage(data.language) ? data.language : policy.defaults.language,
    timeZone: effectiveTimeZone(data.timeZone, policy),
    reactivationGraceUntilMs: millis(data.reactivationGraceUntil),
    leaseId: text(data.leaseId),
    leaseExpiresAtMs: millis(data.leaseExpiresAt),
    consecutiveFailures: count(data.consecutiveFailures),
    lastAttempt: attemptFromData(data.lastAttempt),
    updatedAtMs: millis(data.updatedAt) ?? 0,
  };
}

export function inactivityStateToData(state: InactivityState): DocumentData {
  const attempt = state.lastAttempt;
  return {
    schemaVersion: SCHEMA_VERSION,
    lastActivityAt: timestamp(state.lastActivityAtMs),
    lastActivitySource: state.lastActivitySource,
    lastActivityOccurredAt: timestamp(state.lastActivityOccurredAtMs),
    lastActivityReceivedAt: timestamp(state.lastActivityReceivedAtMs),
    lastActivityTimeQuality: state.lastActivityTimeQuality,
    cycleId: state.cycleId,
    remindersSentInCycle: state.remindersSentInCycle,
    lastReminderSentAt: timestamp(state.lastReminderSentAtMs),
    nextReminderDueAt: timestamp(state.nextReminderDueAtMs),
    nextReminderAt: timestamp(state.nextReminderAtMs),
    enabled: state.enabled,
    appSupportsServerReminders: state.appSupportsServerReminders,
    language: state.language,
    timeZone: state.timeZone,
    reactivationGraceUntil: timestamp(state.reactivationGraceUntilMs),
    leaseId: state.leaseId,
    leaseExpiresAt: timestamp(state.leaseExpiresAtMs),
    consecutiveFailures: state.consecutiveFailures,
    lastAttempt:
      attempt === null
        ? null
        : {
            id: attempt.id,
            cycleId: attempt.cycleId,
            reminderNumber: attempt.reminderNumber,
            status: attempt.status,
            claimedAt: Timestamp.fromMillis(attempt.claimedAtMs),
            sendingAt: timestamp(attempt.sendingAtMs),
            completedAt: timestamp(attempt.completedAtMs),
            acceptedDevices: attempt.acceptedDevices,
            invalidDevices: attempt.invalidDevices,
            failedDevices: attempt.failedDevices,
            unknownDevices: attempt.unknownDevices,
          },
    updatedAt: Timestamp.fromMillis(state.updatedAtMs),
  };
}

export class FirestoreInactivityStateStore implements InactivityStateStore {
  constructor(
    private readonly db: Firestore,
    private readonly policy: ReminderPolicy,
  ) {}

  private ref(uid: string): DocumentReference {
    return this.db.collection('users').doc(uid).collection(NOTIFICATION_STATE_COLLECTION).doc(INACTIVITY_STATE_DOC);
  }

  update<T>(
    uid: string,
    mutate: (current: InactivityState | null) => { readonly next: InactivityState | null; readonly result: T },
  ): Promise<T> {
    const ref = this.ref(uid);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const current = snapshot.exists ? inactivityStateFromData(snapshot.data() ?? {}, this.policy) : null;
      const { next, result } = mutate(current);
      if (next !== null) transaction.set(ref, inactivityStateToData(next));
      return result;
    });
  }
}

/**
 * Indexed collection-group query on `nextReminderAt` (null when nothing is
 * scheduled, so disabled users are never returned). Requires a
 * collection-group index on notificationState.nextReminderAt (Stage 2).
 */
export class FirestoreDueReminderFinder implements DueReminderFinder {
  constructor(private readonly db: Firestore) {}

  async findDue(nowMs: number, limit: number, cursor: unknown | null): Promise<DueReminderPage> {
    let query = this.db
      .collectionGroup(NOTIFICATION_STATE_COLLECTION)
      .where('nextReminderAt', '<=', Timestamp.fromMillis(nowMs))
      .orderBy('nextReminderAt')
      .limit(limit);
    if (isQueryCursor(cursor)) query = query.startAfter(cursor);
    const snapshot = await query.get();
    const uids = snapshot.docs.flatMap((doc) => {
      const userRef = doc.ref.parent.parent;
      return doc.id === INACTIVITY_STATE_DOC && userRef !== null && userRef.parent.id === 'users' ? [userRef.id] : [];
    });
    const last = snapshot.docs.at(-1);
    return { uids, cursor: snapshot.docs.length < limit || last === undefined ? null : last };
  }
}

function isQueryCursor(value: unknown): value is QueryDocumentSnapshot {
  return typeof value === 'object' && value !== null && 'ref' in value && 'data' in value;
}
