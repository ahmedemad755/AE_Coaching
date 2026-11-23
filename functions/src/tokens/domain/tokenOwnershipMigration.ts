import { parseStoredFcmToken, type RawStoredFcmToken } from './fcmToken';
import type { TokenOwner } from './tokenOwnership';

/**
 * One-time backfill of the ownership registry for tokens stored before the
 * registry existed. Senders only use tokens whose owner is CONFIRMED in the
 * registry, so an unregistered legacy token receives nothing until it is
 * either migrated here or registered again by the app.
 *
 * Rules:
 * - a token held by exactly one account is assigned to that account (its
 *   document was written by that account's verified session and no other
 *   account claims it);
 * - a token held by several accounts is AMBIGUOUS (a shared device whose
 *   logout cleanup did not run) and is never assigned: no account receives
 *   reminders on it until the device's current account registers it again;
 * - a token that already has an owner is left alone (the live triggers own
 *   it from then on);
 * - malformed copies are ignored (senders discard them anyway).
 */

export interface StoredTokenCopy {
  readonly uid: string;
  readonly tokenId: string;
  readonly raw: RawStoredFcmToken;
  /** Server time of that account's latest registration (`updatedAt`). */
  readonly registeredAtMs: number;
}

export interface OwnershipMigrationPlan {
  readonly distinctTokens: number;
  readonly assignments: readonly { readonly tokenId: string; readonly owner: TokenOwner }[];
  readonly ambiguous: readonly { readonly tokenId: string; readonly holderCount: number }[];
  readonly alreadyOwned: number;
  readonly malformedCopies: number;
}

export function planOwnershipMigration(
  copies: readonly StoredTokenCopy[],
  ownedTokenIds: ReadonlySet<string>,
): OwnershipMigrationPlan {
  const holdersByToken = new Map<string, Map<string, number>>();
  let malformedCopies = 0;
  for (const copy of copies) {
    if (parseStoredFcmToken(copy.tokenId, copy.raw) === null) {
      malformedCopies += 1;
      continue;
    }
    const holders = holdersByToken.get(copy.tokenId) ?? new Map<string, number>();
    holders.set(copy.uid, Math.max(holders.get(copy.uid) ?? 0, copy.registeredAtMs));
    holdersByToken.set(copy.tokenId, holders);
  }

  const assignments: { tokenId: string; owner: TokenOwner }[] = [];
  const ambiguous: { tokenId: string; holderCount: number }[] = [];
  let alreadyOwned = 0;
  for (const [tokenId, holders] of [...holdersByToken.entries()].sort(([a], [b]) => a.localeCompare(b))) {
    if (ownedTokenIds.has(tokenId)) {
      alreadyOwned += 1;
    } else if (holders.size === 1) {
      const [[uid, registeredAtMs]] = [...holders.entries()];
      assignments.push({ tokenId, owner: { uid, registeredAtMs } });
    } else {
      ambiguous.push({ tokenId, holderCount: holders.size });
    }
  }
  return { distinctTokens: holdersByToken.size, assignments, ambiguous, alreadyOwned, malformedCopies };
}
