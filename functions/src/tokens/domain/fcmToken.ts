import { createHash } from 'node:crypto';

/**
 * Device push tokens as stored by the app (FcmDeviceService):
 * `users/{uid}/fcmTokens/{sha256(token)}` with token, platform, createdAt and
 * updatedAt (server time, enforced by firestore.rules).
 */

export const FCM_TOKEN_MAX_LENGTH = 4096;

/** `defaultTargetPlatform.name` values the app writes (and rules accept). */
const PLATFORMS = new Set(['android', 'iOS', 'macOS']);

export function fcmTokenDocumentId(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export interface StoredFcmToken {
  readonly id: string;
  readonly token: string;
  readonly platform: string;
  /**
   * The LATEST registration of this token came from an app build that
   * handles server reminders (and no longer schedules the retired local
   * reminder). A capability of the device's app, never proof of identity or
   * ownership: those come from security rules and the ownership registry.
   */
  readonly serverRemindersReady: boolean;
}

/** Untrusted stored values (already read from the database). */
export interface RawStoredFcmToken {
  readonly token?: unknown;
  readonly platform?: unknown;
  /** Server time of the latest registration (`updatedAt`). */
  readonly updatedAtMs?: number | null;
  /** Server time a capable build last confirmed (`serverRemindersReadyAt`). */
  readonly serverRemindersReadyAtMs?: number | null;
}

/**
 * Capable builds write `serverRemindersReadyAt` and `updatedAt` as the same
 * server timestamp in every registration. An older build re-registering the
 * same token refreshes only `updatedAt`, so the two differ and the token is
 * no longer ready: readiness always describes the build that registered last.
 */
export function isServerRemindersReady(raw: RawStoredFcmToken): boolean {
  const { updatedAtMs, serverRemindersReadyAtMs } = raw;
  return (
    typeof updatedAtMs === 'number' &&
    typeof serverRemindersReadyAtMs === 'number' &&
    updatedAtMs === serverRemindersReadyAtMs
  );
}

/**
 * A usable token, or `null` when the document is malformed: empty or
 * oversized token, unknown platform, or an id that is not the token's hash
 * (which would let one token appear under many ids).
 */
export function parseStoredFcmToken(id: string, raw: RawStoredFcmToken): StoredFcmToken | null {
  const { token, platform } = raw;
  if (typeof token !== 'string') return null;
  const trimmed = token.trim();
  if (trimmed.length === 0 || token.length > FCM_TOKEN_MAX_LENGTH || trimmed !== token) return null;
  if (typeof platform !== 'string' || !PLATFORMS.has(platform)) return null;
  if (id !== fcmTokenDocumentId(token)) return null;
  return { id, token, platform, serverRemindersReady: isServerRemindersReady(raw) };
}
