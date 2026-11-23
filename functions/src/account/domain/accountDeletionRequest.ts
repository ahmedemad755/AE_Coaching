/**
 * A user's request to delete their account, filed by the app in
 * `accountDeletionRequests/{uid}` (Spark plan: no deployed functions, so
 * deletion is completed by an operator with a local Admin SDK tool).
 *
 * Lifecycle: `pending` (written by the app, once) → `processing` (operator
 * tool started) → document removed (deletion complete). A request stuck in
 * `processing` is an interrupted run; running the tool again resumes it.
 */
export type DeletionRequestStatus = 'pending' | 'processing';

export interface AccountDeletionRequest {
  readonly uid: string;
  readonly status: DeletionRequestStatus;
  readonly requestedAtMs: number;
}

/** Untrusted stored values (Timestamps already converted to millis). */
export interface RawDeletionRequest {
  readonly uid?: unknown;
  readonly status?: unknown;
  readonly requestedAtMs?: unknown;
}

/**
 * A valid request, or `null`. The stored `uid` must equal the document id:
 * a request can only ever target the account it is filed under.
 */
export function parseDeletionRequest(documentId: string, raw: RawDeletionRequest): AccountDeletionRequest | null {
  const { uid, status, requestedAtMs } = raw;
  if (typeof uid !== 'string' || uid.length === 0 || uid !== documentId) return null;
  if (status !== 'pending' && status !== 'processing') return null;
  if (typeof requestedAtMs !== 'number' || !Number.isFinite(requestedAtMs)) return null;
  return { uid, status, requestedAtMs };
}
