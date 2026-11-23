import type { AccountDeletionRequest } from '../domain/accountDeletionRequest';

/** `accountDeletionRequests/{uid}` (operator side). */
export interface DeletionRequestStore {
  /** Valid requests, oldest first; malformed documents are reported as invalid ids. */
  list(limit: number): Promise<{ readonly requests: readonly AccountDeletionRequest[]; readonly invalidIds: readonly string[] }>;
  get(uid: string): Promise<AccountDeletionRequest | null>;
  markProcessing(uid: string, atMs: number): Promise<void>;
  remove(uid: string): Promise<void>;
}

/** Everything stored for one account outside Firebase Auth. */
export interface UserDataStore {
  /** Documents under `users/{uid}` (the profile and every nested subcollection). */
  countUserTree(uid: string): Promise<number>;
  /** Recursively deletes `users/{uid}` and all nested subcollections. */
  deleteUserTree(uid: string): Promise<void>;
  /** `fcmTokenOwners` records naming [uid] (they live outside `users/{uid}`). */
  countTokenOwnerships(uid: string): Promise<number>;
  deleteTokenOwnerships(uid: string): Promise<number>;
}

export interface AuthAccounts {
  exists(uid: string): Promise<boolean>;
  /** `absent` when the account was already deleted (idempotent). */
  delete(uid: string): Promise<'deleted' | 'absent'>;
}
