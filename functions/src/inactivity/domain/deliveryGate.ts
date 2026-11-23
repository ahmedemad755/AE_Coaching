/**
 * Server-side rollout switch for reminder DELIVERY (activity and preference
 * tracking always run). Operator-controlled only: it lives in a document no
 * client can read or write (firestore.rules), and anything missing, invalid
 * or unreadable means OFF.
 *
 * - `off`: nothing is sent (the default until explicitly enabled);
 * - `allowlist`: only the listed accounts (staging / internal canary);
 * - `all`: every eligible user.
 *
 * When open, at most `maxSendsPerPass` reminders are sent per hourly pass
 * (default [DEFAULT_MAX_SENDS_PER_PASS]); the rest wait for the next pass.
 * Per-user eligibility (reminders on, app and device confirmed, due, quiet
 * hours, backlog spreading) still applies in every mode.
 */
export type DeliveryGate =
  | { readonly mode: 'off' }
  | { readonly mode: 'all'; readonly maxSendsPerPass: number }
  | { readonly mode: 'allowlist'; readonly uids: readonly string[]; readonly maxSendsPerPass: number };

export const CLOSED_DELIVERY_GATE: DeliveryGate = { mode: 'off' };

/** A canary list, not a user segment; larger lists are rejected (closed). */
export const MAX_ALLOWLIST_UIDS = 100;

/** Conservative unless an operator raises it explicitly. */
export const DEFAULT_MAX_SENDS_PER_PASS = 100;
/** Equal to the pass's own examination cap. */
export const MAX_SENDS_PER_PASS = 5000;

function isUid(value: unknown): value is string {
  return typeof value === 'string' && value.length > 0 && value.length <= 128 && !value.includes('/');
}

/**
 * Stored shape: `{ deliveryMode: 'off'|'allowlist'|'all',
 * allowlistUids?: string[], maxSendsPerPass?: integer 1–5000 }`.
 * An invalid budget closes the gate rather than guessing.
 */
export function parseDeliveryGate(raw: unknown): DeliveryGate {
  if (typeof raw !== 'object' || raw === null) return CLOSED_DELIVERY_GATE;
  const { deliveryMode, allowlistUids, maxSendsPerPass: budget } = raw as Record<string, unknown>;
  const maxSendsPerPass = budget === undefined ? DEFAULT_MAX_SENDS_PER_PASS : budget;
  if (
    typeof maxSendsPerPass !== 'number' ||
    !Number.isInteger(maxSendsPerPass) ||
    maxSendsPerPass < 1 ||
    maxSendsPerPass > MAX_SENDS_PER_PASS
  ) {
    return CLOSED_DELIVERY_GATE;
  }
  if (deliveryMode === 'all') return { mode: 'all', maxSendsPerPass };
  if (deliveryMode !== 'allowlist' || !Array.isArray(allowlistUids)) return CLOSED_DELIVERY_GATE;
  if (!allowlistUids.every(isUid)) return CLOSED_DELIVERY_GATE;
  const uids = [...new Set(allowlistUids as string[])].sort();
  if (uids.length === 0 || uids.length > MAX_ALLOWLIST_UIDS) return CLOSED_DELIVERY_GATE;
  return { mode: 'allowlist', uids, maxSendsPerPass };
}
