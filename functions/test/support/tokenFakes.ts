import type { TokenInventory, TokenOwnershipRegistry, UserTokenStore } from '../../src/tokens/application/ports';
import { fcmTokenDocumentId, type RawStoredFcmToken } from '../../src/tokens/domain/fcmToken';
import type { StoredTokenCopy } from '../../src/tokens/domain/tokenOwnershipMigration';
import type { OwnershipDecision, TokenOwner } from '../../src/tokens/domain/tokenOwnership';

export class InMemoryTokenRegistry implements TokenOwnershipRegistry {
  readonly owners = new Map<string, TokenOwner>();

  async record(tokenId: string, decide: (current: TokenOwner | null) => OwnershipDecision): Promise<OwnershipDecision> {
    const decision = decide(this.owners.get(tokenId) ?? null);
    this.owners.set(tokenId, decision.next);
    return decision;
  }

  async createIfAbsent(tokenId: string, owner: TokenOwner): Promise<boolean> {
    if (this.owners.has(tokenId)) return false;
    this.owners.set(tokenId, owner);
    return true;
  }

  async releaseIfOwnedBy(tokenId: string, uid: string): Promise<void> {
    if (this.owners.get(tokenId)?.uid === uid) this.owners.delete(tokenId);
  }

  async ownersOf(tokenIds: readonly string[]): Promise<ReadonlyMap<string, string>> {
    const result = new Map<string, string>();
    for (const id of tokenIds) {
      const owner = this.owners.get(id);
      if (owner !== undefined) result.set(id, owner.uid);
    }
    return result;
  }
}

interface StoredDoc {
  readonly raw: RawStoredFcmToken;
  /** Server `updatedAt` of the latest registration. */
  readonly updatedAtMs: number;
}

/** `users/{uid}/fcmTokens/{id}` as the app writes them. */
export class InMemoryUserTokens implements UserTokenStore, TokenInventory {
  readonly byUid = new Map<string, Map<string, StoredDoc>>();

  /**
   * Stores [raw] under its hash id, like FcmDeviceService. Returns the id.
   * [serverRemindersReady]: registered by a build that confirms readiness
   * (marker equal to updatedAt); false models an older build.
   */
  register(uid: string, raw: string, updatedAtMs = 0, platform = 'android', serverRemindersReady = true): string {
    const id = fcmTokenDocumentId(raw);
    this.putRaw(
      uid,
      id,
      {
        token: raw,
        platform,
        updatedAtMs,
        serverRemindersReadyAtMs: serverRemindersReady ? updatedAtMs : null,
      },
      updatedAtMs,
    );
    return id;
  }

  putRaw(uid: string, id: string, raw: RawStoredFcmToken, updatedAtMs = 0): void {
    const docs = this.byUid.get(uid) ?? new Map<string, StoredDoc>();
    docs.set(id, { raw, updatedAtMs });
    this.byUid.set(uid, docs);
  }

  ids(uid: string): string[] {
    return [...(this.byUid.get(uid)?.keys() ?? [])];
  }

  async list(uid: string) {
    return [...(this.byUid.get(uid)?.entries() ?? [])].map(([id, doc]) => ({ id, raw: doc.raw }));
  }

  async delete(uid: string, tokenIds: readonly string[]): Promise<void> {
    for (const id of tokenIds) this.byUid.get(uid)?.delete(id);
  }

  async deleteUnlessRefreshedAfter(uid: string, tokenId: string, registeredAtMs: number): Promise<boolean> {
    const doc = this.byUid.get(uid)?.get(tokenId);
    if (doc === undefined || doc.updatedAtMs > registeredAtMs) return false;
    this.byUid.get(uid)?.delete(tokenId);
    return true;
  }

  async *copies(): AsyncIterable<StoredTokenCopy> {
    for (const [uid, docs] of this.byUid) {
      for (const [tokenId, doc] of docs) yield { uid, tokenId, raw: doc.raw, registeredAtMs: doc.updatedAtMs };
    }
  }
}
