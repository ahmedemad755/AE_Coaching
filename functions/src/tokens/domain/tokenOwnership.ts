/**
 * One device token belongs to at most one account: the account that
 * registered it most recently. A shared device that switched accounts (and
 * whose logout cleanup failed offline) must not keep receiving the previous
 * account's notifications.
 */

export interface TokenOwner {
  readonly uid: string;
  /** Server time of that account's registration (token `updatedAt`). */
  readonly registeredAtMs: number;
}

export type OwnershipDecision =
  /** First registration seen, or the same owner again. */
  | { readonly action: 'owned'; readonly next: TokenOwner }
  /** A newer registration by another account: remove the previous copy. */
  | { readonly action: 'transferred'; readonly next: TokenOwner; readonly previousOwnerUid: string }
  /** An older registration than the current owner's (late event): remove it. */
  | { readonly action: 'rejected_stale'; readonly next: TokenOwner };

/**
 * Idempotent and order-independent: replaying or reordering registration
 * events converges on the most recent registration (ties go to the
 * incoming one, so a re-registration is never rejected).
 */
export function decideOwnership(current: TokenOwner | null, incoming: TokenOwner): OwnershipDecision {
  if (current === null) return { action: 'owned', next: incoming };
  if (current.uid === incoming.uid) {
    return {
      action: 'owned',
      next: { uid: incoming.uid, registeredAtMs: Math.max(current.registeredAtMs, incoming.registeredAtMs) },
    };
  }
  if (incoming.registeredAtMs >= current.registeredAtMs) {
    return { action: 'transferred', next: incoming, previousOwnerUid: current.uid };
  }
  return { action: 'rejected_stale', next: current };
}
