import { existsSync, readFileSync } from 'fs';
import { EMULATOR_SMS_OUTBOX_PATH, EmulatorOutboxEntry } from '../../src/emulatorSmsOutbox';

/**
 * Reads back what EmulatorFileSmsProvider (emulator-only) wrote for the
 * given phone. Safe to call right after a requestPasswordReset HTTP
 * response returns: handleRequestPasswordReset `await`s the SMS send
 * before responding, and the write itself is a synchronous
 * `appendFileSync`, so there is no race between "the callable
 * responded" and "the file has the entry."
 */
export function readLatestOtpForPhone(phone: string): string | null {
  if (!existsSync(EMULATOR_SMS_OUTBOX_PATH)) return null;
  const lines = readFileSync(EMULATOR_SMS_OUTBOX_PATH, 'utf8')
    .split('\n')
    .filter((l) => l.trim().length > 0);
  const entries: EmulatorOutboxEntry[] = lines.map((l) => JSON.parse(l));
  const forPhone = entries.filter((e) => e.toE164Phone === phone);
  if (forPhone.length === 0) return null;
  const latest = forPhone[forPhone.length - 1];
  const match = latest.body.match(/code is (\d{6})/);
  return match ? match[1] : null;
}
