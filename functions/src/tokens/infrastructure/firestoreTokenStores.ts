import {
  type DocumentSnapshot,
  FieldPath,
  type Firestore,
  type QueryDocumentSnapshot,
  Timestamp,
} from 'firebase-admin/firestore';
import type { RawStoredFcmToken } from '../domain/fcmToken';
import type { StoredTokenCopy } from '../domain/tokenOwnershipMigration';
import type { OwnershipDecision, TokenOwner } from '../domain/tokenOwnership';
import type { TokenInventory, TokenOwnershipRegistry, UserTokenStore } from '../application/ports';

/**
 * `fcmTokenOwners/{sha256(token)}` = { uid, registeredAt }.
 * Server-only (Admin SDK; firestore.rules deny every client access).
 * Holds no raw token, only the owning account and when it registered.
 */
export const TOKEN_OWNERS_COLLECTION = 'fcmTokenOwners';

/** Value of `source` on owner records created by the backfill migration. */
export const MIGRATION_SOURCE = 'migration';

/** Firestore `getAll` / batch limits keep each call bounded. */
const READ_CHUNK = 100;
const WRITE_CHUNK = 450;
/** A user has a handful of devices; anything beyond this is not normal. */
const MAX_TOKENS_PER_USER = 50;

function ownerFromData(data: Readonly<Record<string, unknown>> | undefined): TokenOwner | null {
  if (data === undefined) return null;
  const { uid, registeredAt } = data;
  if (typeof uid !== 'string' || uid.length === 0 || !(registeredAt instanceof Timestamp)) return null;
  return { uid, registeredAtMs: registeredAt.toMillis() };
}

export class FirestoreTokenOwnershipRegistry implements TokenOwnershipRegistry {
  constructor(private readonly db: Firestore) {}

  async record(tokenId: string, decide: (current: TokenOwner | null) => OwnershipDecision): Promise<OwnershipDecision> {
    const ref = this.db.collection(TOKEN_OWNERS_COLLECTION).doc(tokenId);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const decision = decide(ownerFromData(snapshot.data()));
      transaction.set(ref, {
        uid: decision.next.uid,
        registeredAt: Timestamp.fromMillis(decision.next.registeredAtMs),
      });
      return decision;
    });
  }

  async createIfAbsent(tokenId: string, owner: TokenOwner): Promise<boolean> {
    const ref = this.db.collection(TOKEN_OWNERS_COLLECTION).doc(tokenId);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (snapshot.exists) return false;
      // `source` marks a backfilled record, so a rollback can remove exactly
      // these. A later live registration rewrites the record without it.
      transaction.set(ref, {
        uid: owner.uid,
        registeredAt: Timestamp.fromMillis(owner.registeredAtMs),
        source: MIGRATION_SOURCE,
      });
      return true;
    });
  }

  async releaseIfOwnedBy(tokenId: string, uid: string): Promise<void> {
    const ref = this.db.collection(TOKEN_OWNERS_COLLECTION).doc(tokenId);
    await this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (ownerFromData(snapshot.data())?.uid === uid) transaction.delete(ref);
    });
  }

  async ownersOf(tokenIds: readonly string[]): Promise<ReadonlyMap<string, string>> {
    const owners = new Map<string, string>();
    for (let offset = 0; offset < tokenIds.length; offset += READ_CHUNK) {
      const refs = tokenIds
        .slice(offset, offset + READ_CHUNK)
        .map((id) => this.db.collection(TOKEN_OWNERS_COLLECTION).doc(id));
      if (refs.length === 0) continue;
      for (const snapshot of await this.db.getAll(...refs)) {
        const owner = ownerFromData(snapshot.data());
        if (owner !== null) owners.set(snapshot.id, owner.uid);
      }
    }
    return owners;
  }
}

export class FirestoreUserTokenStore implements UserTokenStore {
  constructor(private readonly db: Firestore) {}

  private collection(uid: string) {
    return this.db.collection('users').doc(uid).collection('fcmTokens');
  }

  async list(uid: string): Promise<readonly { readonly id: string; readonly raw: RawStoredFcmToken }[]> {
    const snapshot = await this.collection(uid).limit(MAX_TOKENS_PER_USER).get();
    return snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        raw: {
          token: data.token,
          platform: data.platform,
          updatedAtMs: millisOrNull(data.updatedAt),
          serverRemindersReadyAtMs: millisOrNull(data.serverRemindersReadyAt),
        },
      };
    });
  }

  async delete(uid: string, tokenIds: readonly string[]): Promise<void> {
    for (let offset = 0; offset < tokenIds.length; offset += WRITE_CHUNK) {
      const batch = this.db.batch();
      for (const id of tokenIds.slice(offset, offset + WRITE_CHUNK)) batch.delete(this.collection(uid).doc(id));
      await batch.commit();
    }
  }

  async deleteUnlessRefreshedAfter(uid: string, tokenId: string, registeredAtMs: number): Promise<boolean> {
    const ref = this.collection(uid).doc(tokenId);
    return this.db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) return false;
      if (registrationTimeOf(snapshot) > registeredAtMs) return false;
      transaction.delete(ref);
      return true;
    });
  }
}

function millisOrNull(value: unknown): number | null {
  return value instanceof Timestamp ? value.toMillis() : null;
}

/** Server time of a token document's latest registration. */
function registrationTimeOf(snapshot: DocumentSnapshot): number {
  const updatedAt: unknown = snapshot.get('updatedAt');
  if (updatedAt instanceof Timestamp) return updatedAt.toMillis();
  return snapshot.updateTime?.toMillis() ?? 0;
}

/**
 * Every `users/{uid}/fcmTokens/{id}` document, in pages (collection-group
 * query in document order; needs no extra index). Read-only.
 */
export class FirestoreTokenInventory implements TokenInventory {
  constructor(private readonly db: Firestore) {}

  async *copies(pageSize: number): AsyncIterable<StoredTokenCopy> {
    let cursor: QueryDocumentSnapshot | undefined;
    for (;;) {
      let query = this.db.collectionGroup('fcmTokens').orderBy(FieldPath.documentId()).limit(pageSize);
      if (cursor !== undefined) query = query.startAfter(cursor);
      const page = await query.get();
      for (const doc of page.docs) {
        const userRef = doc.ref.parent.parent;
        if (userRef === null || userRef.parent.id !== 'users') continue;
        const data = doc.data();
        yield {
          uid: userRef.id,
          tokenId: doc.id,
          raw: { token: data.token, platform: data.platform },
          registeredAtMs: registrationTimeOf(doc),
        };
      }
      if (page.docs.length < pageSize) return;
      cursor = page.docs[page.docs.length - 1];
    }
  }
}
