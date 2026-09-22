/**
 * True only inside the real Firebase Functions Emulator, which sets
 * `FUNCTIONS_EMULATOR=true` on the child process it spawns (confirmed
 * by reading firebase-tools' functionsEmulator.js — not assumed). This
 * env var is never present in a deployed Cloud Functions instance, so
 * anything gated on it can never run in production.
 */
export function isFunctionsEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === 'true';
}
