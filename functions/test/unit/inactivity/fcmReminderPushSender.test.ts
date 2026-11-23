import type { BatchResponse, MulticastMessage } from 'firebase-admin/messaging';
import {
  classifyFcmError,
  collapseKeyFor,
  FCM_MULTICAST_LIMIT,
  FcmReminderPushSender,
} from '../../../src/inactivity/infrastructure/fcmReminderPushSender';
import { selectReminderMessage } from '../../../src/inactivity/domain/reminderMessages';
import { token } from '../../support/inactivityFakes';

/** Mock Admin messaging: records requests, never contacts FCM. */
function mockMessaging(errorFor: (rawToken: string) => string | null = () => null) {
  const requests: MulticastMessage[] = [];
  const messaging = {
    async sendEachForMulticast(message: MulticastMessage): Promise<BatchResponse> {
      requests.push(message);
      const responses = message.tokens.map((raw) => {
        const code = errorFor(raw);
        return code === null
          ? { success: true, messageId: 'm' }
          : { success: false, error: { code, message: 'x' } as unknown as Error & { code: string } };
      });
      const successCount = responses.filter((r) => r.success).length;
      return { responses, successCount, failureCount: responses.length - successCount } as unknown as BatchResponse;
    },
  };
  return { messaging, requests };
}

const contract = { notificationType: 'inactivity_reminder', androidChannelId: 'inactivity_reminders' };
const ATTEMPT = 'c1794153600000:r3';

describe('FcmReminderPushSender', () => {
  test('payload: localized copy and the routing type only; opaque collapse key', async () => {
    const { messaging, requests } = mockMessaging();
    const message = selectReminderMessage('ar', 3);
    await new FcmReminderPushSender(messaging, contract).send({ tokens: [token('a')], message, attemptId: ATTEMPT });

    const key = collapseKeyFor(ATTEMPT);
    expect(requests).toEqual([
      {
        tokens: [token('a').token],
        notification: { title: message.title, body: message.body },
        data: { type: 'inactivity_reminder' },
        android: { priority: 'high', collapseKey: key, notification: { channelId: 'inactivity_reminders', tag: key } },
        apns: { headers: { 'apns-collapse-id': key } },
      },
    ]);
    // The attempt id encodes the activity time: it never leaves the server.
    expect(JSON.stringify(requests)).not.toContain('1794153600000');
    expect(key).toMatch(/^ir-[0-9a-f]{24}$/);
    expect(collapseKeyFor(ATTEMPT)).toBe(key);
    expect(collapseKeyFor('c1794153600000:r4')).not.toBe(key);
  });

  test('splits more than 500 devices into batches and reports every device in order', async () => {
    const tokens = Array.from({ length: 1201 }, (_, i) => token(`t${i}`));
    const invalid = new Set([token('t3').token, token('t700').token]);
    const { messaging, requests } = mockMessaging((raw) =>
      invalid.has(raw) ? 'messaging/registration-token-not-registered' : raw === token('t1200').token ? 'messaging/unavailable' : null,
    );
    const results = await new FcmReminderPushSender(messaging, contract).send({
      tokens,
      message: selectReminderMessage('en', 1),
      attemptId: ATTEMPT,
    });
    expect(requests.map((r) => r.tokens.length)).toEqual([FCM_MULTICAST_LIMIT, FCM_MULTICAST_LIMIT, 201]);
    expect(results.map((r) => r.tokenId)).toEqual(tokens.map((t) => t.id));
    expect(results.filter((r) => r.outcome === 'invalid_token').map((r) => r.tokenId)).toEqual(['t3', 't700']);
    expect(results.find((r) => r.tokenId === 't1200')?.outcome).toBe('retryable');
    expect(results.filter((r) => r.outcome === 'accepted')).toHaveLength(1198);
  });

  test('error classification', () => {
    expect(classifyFcmError('messaging/registration-token-not-registered')).toBe('invalid_token');
    expect(classifyFcmError('messaging/invalid-registration-token')).toBe('invalid_token');
    for (const code of ['messaging/unavailable', 'messaging/internal-error', 'messaging/quota-exceeded']) {
      expect(classifyFcmError(code)).toBe('retryable');
    }
    // Not the token's fault, not transient: neither removed nor counted as sent.
    expect(classifyFcmError('messaging/invalid-argument')).toBe('failed');
    expect(classifyFcmError('messaging/mismatched-credential')).toBe('failed');
    // No answer from FCM (firebase-admin reports transport failures per
    // device): it may have been accepted, so it must never be re-sent.
    expect(classifyFcmError('app/network-timeout')).toBe('unknown');
    expect(classifyFcmError('app/network-error')).toBe('unknown');
    expect(classifyFcmError('messaging/unknown-error')).toBe('unknown');
    expect(classifyFcmError(undefined)).toBe('unknown');
  });
});
