import type { Auth } from 'firebase-admin/auth';
import { type DocumentReference, type Firestore, Timestamp } from 'firebase-admin/firestore';
import { TOKEN_OWNERS_COLLECTION } from '../../tokens/infrastructure/firestoreTokenStores';
import type { AuthAccounts, DeletionRequestStore, UserDataStore } from '../application/ports';
import { type AccountDeletionRequest, parseDeletionRequest } from '../domain/accountDeletionRequest';

/** Filed by the app (rules: owner, recent sign-in, create only). */
export const DELETION_REQUESTS_COLLECTION = 'accountDeletionRequests';

/** Firestore batch limit with headroom. */
const DELETE_CHUNK = 400;

export class FirestoreDeletionRequestStore implements DeletionRequestStore {
  constructor(private readonly db: Firestore) {}

  private ref(uid: string): DocumentReference {
    return this.db.collection(DELETION_REQUESTS_COLLECTION).doc(uid);
  }

  async list(limit: number) {
    const snapshot = await this.db.collection(DELETION_REQUESTS_COLLECTION).orderBy('requestedAt').limit(limit).get();
    const requests: AccountDeletionRequest[] = [];
    const invalidIds: string[] = [];
    for (const doc of snapshot.docs) {
      const request = parseDeletionRequest(doc.id, toRaw(doc.data()));
      if (request === null) invalidIds.push(doc.id);
      else requests.push(request);
    }
    return { requests, invalidIds };
  }

  async get(uid: string): Promise<AccountDeletionRequest | null> {
    const snapshot = await this.ref(uid).get();
    return snapshot.exists ? parseDeletionRequest(uid, toRaw(snapshot.data() ?? {})) : null;
  }

  async markProcessing(uid: string, atMs: number): Promise<void> {
    await this.ref(uid).update({ status: 'processing', processingStartedAt: Timestamp.fromMillis(atMs) });
  }

  async remove(uid: string): Promise<void> {
    await this.ref(uid).delete();
  }
}

function toRaw(data: Readonly<Record<string, unknown>>) {
  const requestedAt = data.requestedAt;
  return {
    uid: data.uid,
    status: data.status,
    requestedAtMs: requestedAt instanceof Timestamp ? requestedAt.toMillis() : undefined,
  };
}

/**
 * Deleting a document does NOT delete its subcollections; the Admin SDK's
 * `recursiveDelete` removes the document and every nested subcollection,
 * whether or not the parent document itself exists.
 */
export class FirestoreUserDataStore implements UserDataStore {
  constructor(private readonly db: Firestore) {}

  private userRef(uid: string): DocumentReference {
    return this.db.collection('users').doc(uid);
  }

  async countUserTree(uid: string): Promise<number> {
    const root = this.userRef(uid);
    return ((await root.get()).exists ? 1 : 0) + (await countSubtree(root));
  }

  async deleteUserTree(uid: string): Promise<void> {
    await this.db.recursiveDelete(this.userRef(uid));
  }

  private ownershipQuery(uid: string) {
    return this.db.collection(TOKEN_OWNERS_COLLECTION).where('uid', '==', uid);
  }

  async countTokenOwnerships(uid: string): Promise<number> {
    return (await this.ownershipQuery(uid).count().get()).data().count;
  }

  async deleteTokenOwnerships(uid: string): Promise<number> {
    let deleted = 0;
    for (;;) {
      const page = await this.ownershipQuery(uid).limit(DELETE_CHUNK).get();
      if (page.empty) return deleted;
      const batch = this.db.batch();
      for (const doc of page.docs) batch.delete(doc.ref);
      await batch.commit();
      deleted += page.size;
    }
  }
}

/** Documents in every subcollection below [ref], recursively. */
async function countSubtree(ref: DocumentReference): Promise<number> {
  let total = 0;
  for (const collection of await ref.listCollections()) {
    for (const doc of await collection.listDocuments()) {
      if ((await doc.get()).exists) total += 1;
      total += await countSubtree(doc);
    }
  }
  return total;
}

export class FirebaseAuthAccounts implements AuthAccounts {
  constructor(private readonly auth: Auth) {}

  async exists(uid: string): Promise<boolean> {
    try {
      await this.auth.getUser(uid);
      return true;
    } catch (error) {
      if (isUserNotFound(error)) return false;
      throw error;
    }
  }

  async delete(uid: string): Promise<'deleted' | 'absent'> {
    try {
      await this.auth.deleteUser(uid);
      return 'deleted';
    } catch (error) {
      if (isUserNotFound(error)) return 'absent';
      throw error;
    }
  }
}

function isUserNotFound(error: unknown): boolean {
  return typeof error === 'object' && error !== null && (error as { code?: unknown }).code === 'auth/user-not-found';
}
