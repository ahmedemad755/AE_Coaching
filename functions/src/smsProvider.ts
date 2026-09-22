/**
 * SMS dispatch abstraction. Deliberately NOT Firebase Phone Auth — see
 * the Phase 5B architecture report for why Firebase's phone-auth
 * primitive can't be reused server-side without inheriting the same
 * account-creation risk it has client-side. This sends a plain SMS via
 * a normal third-party provider API, with no Firebase Auth interaction
 * of any kind.
 */
export interface SmsProvider {
  /**
   * Sends `body` to `toE164Phone`. MUST be awaited by the caller — no
   * fire-and-forget (see Phase 5B correction: the caller only persists
   * a usable challenge after this promise resolves successfully).
   * Rejects if the provider fails or refuses the message.
   */
  send(toE164Phone: string, body: string): Promise<void>;
}

export function otpMessageBody(otp: string): string {
  return `Your AE Coaching verification code is ${otp}. It expires in 10 minutes. Do not share this code.`;
}

/**
 * Production implementation, suitable for Twilio (or any provider with
 * a comparable simple REST send API). Credentials are read from
 * Secret Manager values passed in at construction time — NEVER
 * hardcoded, never read from an environment file committed to source
 * control, never logged (the constructor and send() below must not
 * print `accountSid`/`authToken`/`fromNumber` under any circumstance).
 *
 * NOTE: this class is not exercised against a real Twilio account in
 * this stage — see the Phase 5B report's "NOT actually tested" section.
 * Its shape is deliberately provider-agnostic (accountSid/authToken/
 * fromNumber map onto Twilio's model; swapping providers only requires
 * a new class implementing the same `SmsProvider` interface).
 */
export class TwilioSmsProvider implements SmsProvider {
  constructor(
    private readonly accountSid: string,
    private readonly authToken: string,
    private readonly fromNumber: string
  ) {}

  async send(toE164Phone: string, body: string): Promise<void> {
    const url = `https://api.twilio.com/2010-04-01/Accounts/${this.accountSid}/Messages.json`;
    const params = new URLSearchParams({
      To: toE164Phone,
      From: this.fromNumber,
      Body: body,
    });
    const basicAuth = Buffer.from(`${this.accountSid}:${this.authToken}`).toString('base64');

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${basicAuth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    });

    if (!response.ok) {
      // Never include `body` (contains the raw OTP) in a thrown error
      // message or in anything that might be logged upstream.
      throw new Error(`SMS provider rejected the message (status ${response.status}).`);
    }
  }
}

/** In-memory record of a single "sent" message, for test assertions
 * only — never written to any persistent store or log. */
export interface FakeSentMessage {
  toE164Phone: string;
  body: string;
}

/**
 * Test/emulator double. Performs NO external network call, so
 * automated tests never require a paid SMS send. Captures the message
 * (including the OTP, since it's embedded in `body`) in an in-memory
 * array for test assertions only — this is test-process memory, never
 * a log line, never a file, never a Firestore write, never returned
 * from a production callable response.
 */
export class FakeSmsProvider implements SmsProvider {
  public readonly sentMessages: FakeSentMessage[] = [];
  private failNextCalls = 0;

  /** Configures the next N calls to `send` to reject, simulating a
   * provider outage/rejection. */
  failNext(times = 1): void {
    this.failNextCalls = times;
  }

  async send(toE164Phone: string, body: string): Promise<void> {
    if (this.failNextCalls > 0) {
      this.failNextCalls -= 1;
      throw new Error('Simulated SMS provider failure (test double).');
    }
    this.sentMessages.push({ toE164Phone, body });
  }
}
