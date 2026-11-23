import type { DeliveryGate } from '../domain/deliveryGate';
import type { InactivityState } from '../domain/inactivityState';
import type { ReminderMessage } from '../domain/reminderMessages';
import type { RawReminderPreferences } from '../domain/reminderPreferences';

/**
 * Atomic read-modify-write of one user's reminder state. [mutate] may run
 * more than once (transaction retries) and must therefore be pure. Returning
 * `next: null` means "write nothing".
 */
export interface InactivityStateStore {
  update<T>(
    uid: string,
    mutate: (current: InactivityState | null) => { readonly next: InactivityState | null; readonly result: T },
  ): Promise<T>;
}

export interface DueReminderPage {
  readonly uids: readonly string[];
  /** Opaque continuation; `null` when there are no more due states. */
  readonly cursor: unknown | null;
}

/** Users whose next reminder is due at or before [nowMs], oldest first. */
export interface DueReminderFinder {
  findDue(nowMs: number, limit: number, cursor: unknown | null): Promise<DueReminderPage>;
}

/** The operator's delivery switch (see deliveryGate.ts). */
export interface DeliveryGateReader {
  read(): Promise<DeliveryGate>;
}

export interface ReminderPreferencesReader {
  /** The user's stored preference document, or `null` when absent. */
  read(uid: string): Promise<RawReminderPreferences | null>;
}

export interface RecipientToken {
  /** Stored token document id (sha256 of the token). Safe to log hashed. */
  readonly id: string;
  readonly token: string;
}

/** Devices that may receive this user's reminders. */
export interface ReminderRecipientTokens {
  /**
   * Valid tokens currently owned by [uid], plus ids that must be removed
   * (malformed, or now registered to another account).
   */
  listDeliverableTokens(uid: string): Promise<{
    readonly deliverable: readonly RecipientToken[];
    readonly discard: readonly string[];
  }>;
  removeTokens(uid: string, tokenIds: readonly string[]): Promise<void>;
}

/**
 * Per-device result of handing a message to the push provider:
 * - accepted: the provider accepted it (not a delivery receipt);
 * - invalid_token: the token is unusable and must be removed;
 * - retryable: rejected for a temporary reason; nothing was accepted;
 * - failed: rejected for another reason; nothing was accepted;
 * - unknown: the request may have reached the provider but no answer came
 *   back (e.g. a timeout); it may or may not have been accepted.
 */
export type DeviceSendOutcome = 'accepted' | 'invalid_token' | 'retryable' | 'failed' | 'unknown';

export interface ReminderPush {
  readonly tokens: readonly RecipientToken[];
  readonly message: ReminderMessage;
  /**
   * Deterministic attempt id. It encodes the activity time, so adapters must
   * never send it verbatim; they derive an opaque collapse key from it so a
   * repeated display of the same attempt replaces the earlier one.
   */
  readonly attemptId: string;
}

/** Sends one reminder to devices; reports one outcome per token, in order. */
export interface ReminderPushSender {
  send(push: ReminderPush): Promise<readonly { readonly tokenId: string; readonly outcome: DeviceSendOutcome }[]>;
}
