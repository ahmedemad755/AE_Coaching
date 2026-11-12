import { parseStoredFcmToken, type StoredFcmToken } from '../domain/fcmToken';
import type { TokenOwnershipRegistry, UserTokenStore } from './ports';

/**
 * Which of a user's stored tokens may receive their notifications: valid
 * tokens whose ownership by THIS account is confirmed in the registry AND
 * whose latest registration came from a build that handles server
 * reminders (decided per device: one account may still have devices on
 * older builds, which schedule their own local reminder).
 *
 * - owned by another account: reported for removal (the registry check also
 *   closes the window between a transfer and the old copy's deletion);
 * - malformed: reported for removal;
 * - no owner record yet (stored before the registry, or its ownership event
 *   has not been processed): not used and NOT removed. It becomes eligible
 *   once the migration assigns it or the app registers it again (every app
 *   start of a signed-in, verified user rewrites `updatedAt`);
 * - owned, but registered last by an older build: not used and NOT removed;
 *   it becomes eligible when that device registers from a newer build.
 */
export class DeliverableTokenDirectory {
  constructor(
    private readonly deps: { readonly registry: TokenOwnershipRegistry; readonly userTokens: UserTokenStore },
  ) {}

  async listDeliverableTokens(uid: string): Promise<{
    readonly deliverable: readonly StoredFcmToken[];
    readonly discard: readonly string[];
  }> {
    const stored = await this.deps.userTokens.list(uid);
    const valid: StoredFcmToken[] = [];
    const discard: string[] = [];
    for (const { id, raw } of stored) {
      const token = parseStoredFcmToken(id, raw);
      if (token === null) discard.push(id);
      else valid.push(token);
    }
    const owners = await this.deps.registry.ownersOf(valid.map((token) => token.id));
    const deliverable = valid.filter((token) => {
      const owner = owners.get(token.id);
      if (owner !== undefined && owner !== uid) discard.push(token.id);
      return owner === uid && token.serverRemindersReady;
    });
    return { deliverable, discard };
  }

  removeTokens(uid: string, tokenIds: readonly string[]): Promise<void> {
    return this.deps.userTokens.delete(uid, tokenIds);
  }
}
