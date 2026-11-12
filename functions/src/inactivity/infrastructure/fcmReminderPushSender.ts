import { createHash } from 'node:crypto';
import type { BatchResponse, Messaging, MulticastMessage } from 'firebase-admin/messaging';
import type { DeviceSendOutcome, ReminderPush, ReminderPushSender } from '../application/ports';

/** FCM limit per multicast request. */
export const FCM_MULTICAST_LIMIT = 500;

/** The token itself is no longer valid: remove it. */
const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/** Temporary provider-side problems: worth retrying later. */
const RETRYABLE_CODES = new Set([
  'messaging/unavailable',
  'messaging/internal-error',
  'messaging/server-unavailable',
  'messaging/quota-exceeded',
  'messaging/message-rate-exceeded',
  'messaging/device-message-rate-exceeded',
]);

/**
 * No answer from FCM: the request may have been accepted. firebase-admin
 * reports such transport failures per device (a FirebaseAppError network
 * code, or a raw error without a code).
 */
const UNKNOWN_OUTCOME_CODES = new Set(['app/network-timeout', 'app/network-error', 'messaging/unknown-error']);

export function classifyFcmError(code: string | undefined): DeviceSendOutcome {
  if (code === undefined || UNKNOWN_OUTCOME_CODES.has(code)) return 'unknown';
  if (INVALID_TOKEN_CODES.has(code)) return 'invalid_token';
  if (RETRYABLE_CODES.has(code)) return 'retryable';
  return 'failed';
}

/** Opaque, stable per attempt; never reveals the attempt id (activity time). */
export function collapseKeyFor(attemptId: string): string {
  return `ir-${createHash('sha256').update(attemptId).digest('hex').slice(0, 24)}`;
}

export interface FcmReminderOptions {
  /** Android channel (the app's existing `inactivity_reminders`). */
  readonly androidChannelId: string;
  /** Routing contract with the app's FcmNotificationRouting. */
  readonly notificationType: string;
}

/**
 * Firebase Admin FCM adapter. The payload contains only the localized copy
 * and the routing type: no workout data, no uid, no timestamps.
 */
export class FcmReminderPushSender implements ReminderPushSender {
  constructor(
    private readonly messaging: Pick<Messaging, 'sendEachForMulticast'>,
    private readonly options: FcmReminderOptions,
  ) {}

  async send(push: ReminderPush): Promise<readonly { readonly tokenId: string; readonly outcome: DeviceSendOutcome }[]> {
    const collapseKey = collapseKeyFor(push.attemptId);
    const results: { tokenId: string; outcome: DeviceSendOutcome }[] = [];
    for (let offset = 0; offset < push.tokens.length; offset += FCM_MULTICAST_LIMIT) {
      const batch = push.tokens.slice(offset, offset + FCM_MULTICAST_LIMIT);
      const message: MulticastMessage = {
        tokens: batch.map((token) => token.token),
        notification: { title: push.message.title, body: push.message.body },
        data: { type: this.options.notificationType },
        android: {
          priority: 'high',
          collapseKey,
          notification: { channelId: this.options.androidChannelId, tag: collapseKey },
        },
        apns: { headers: { 'apns-collapse-id': collapseKey } },
      };
      const response: BatchResponse = await this.messaging.sendEachForMulticast(message);
      response.responses.forEach((result, index) => {
        results.push({
          tokenId: batch[index].id,
          outcome: result.success ? 'accepted' : classifyFcmError(result.error?.code),
        });
      });
    }
    return results;
  }
}
