import type { RawStoredFcmToken } from '../domain/fcmToken';
import type { StoredTokenCopy } from '../domain/tokenOwnershipMigration';
import type { OwnershipDecision, TokenOwner } from '../domain/tokenOwnership';

/** Server-only record of which account owns each token id. */
export interface TokenOwnershipRegistry {
  /** Atomically applies [decide] to the current owner of [tokenId]. */
  record(tokenId: string, decide: (current: TokenOwner | null) => OwnershipDecision): Promise<OwnershipDecision>;
  /** Atomically records [owner] only if [tokenId] has no owner yet; true if written. */
  createIfAbsent(tokenId: string, owner: TokenOwner): Promise<boolean>;
  /** Removes the record only while [uid] still owns [tokenId]. */
  releaseIfOwnedBy(tokenId: string, uid: string): Promise<void>;
  /** Current owner uid per token id (absent ids have no record). */
  ownersOf(tokenIds: readonly string[]): Promise<ReadonlyMap<string, string>>;
}

/** The app's per-user token documents. */
export interface UserTokenStore {
  list(uid: string): Promise<readonly { readonly id: string; readonly raw: RawStoredFcmToken }[]>;
  delete(uid: string, tokenIds: readonly string[]): Promise<void>;
  /**
   * Atomically deletes the copy unless the account registered it again
   * after [registeredAtMs] (its `updatedAt` is newer). True if deleted.
   * Protects fresh registrations from late or retried ownership events.
   */
  deleteUnlessRefreshedAfter(uid: string, tokenId: string, registeredAtMs: number): Promise<boolean>;
}

/** Read-only, paged view of every stored token copy (migration only). */
export interface TokenInventory {
  copies(pageSize: number): AsyncIterable<StoredTokenCopy>;
}
