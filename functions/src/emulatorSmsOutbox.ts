import { appendFileSync, existsSync, mkdirSync, unlinkSync } from 'fs';
import { dirname, join } from 'path';
import { SmsProvider } from './smsProvider';

/**
 * EMULATOR-ONLY. The real Twilio provider sends over the network, so an
 * external end-to-end test (a separate process calling the Functions
 * Emulator over HTTP) has no way to observe what OTP was "sent" — the
 * function and the test run in different Node processes and share no
 * memory. This writes each message to a local file instead, so the test
 * process can read back the OTP the emulator process generated.
 *
 * Only ever constructed when `isFunctionsEmulator()` is true (see
 * requestPasswordReset.ts) — never reachable in a deployed function.
 * The OTP is sensitive in general, but this file exists solely on the
 * developer's own machine during a local emulator run, is gitignored,
 * and is never read by any production code path.
 */
const OUTBOX_PATH = join(__dirname, '..', '.emulator-sms-outbox.jsonl');

export interface EmulatorOutboxEntry {
  toE164Phone: string;
  body: string;
  sentAt: number;
}

export class EmulatorFileSmsProvider implements SmsProvider {
  async send(toE164Phone: string, body: string): Promise<void> {
    mkdirSync(dirname(OUTBOX_PATH), { recursive: true });
    const entry: EmulatorOutboxEntry = { toE164Phone, body, sentAt: Date.now() };
    appendFileSync(OUTBOX_PATH, JSON.stringify(entry) + '\n');
  }
}

/** Test-side helper: clears the outbox before a test run so stale
 * entries from a previous run are never misread as the current one. */
export function clearEmulatorSmsOutbox(): void {
  if (existsSync(OUTBOX_PATH)) {
    unlinkSync(OUTBOX_PATH);
  }
}

export { OUTBOX_PATH as EMULATOR_SMS_OUTBOX_PATH };
