import type { StructuredLogger } from '../../shared/application/runtimePorts';
import { decideOwnership } from '../domain/tokenOwnership';
import type { TokenOwnershipRegistry, UserTokenStore } from './ports';

/**
 * Keeps each device token under exactly one account (the latest to
 * register it). Safe to run more than once per event and in any order.
 */
export class ReconcileTokenOwnership {
  constructor(
    private readonly deps: {
      readonly registry: TokenOwnershipRegistry;
      readonly userTokens: UserTokenStore;
      readonly logger: StructuredLogger;
      readonly pseudonym: (value: string) => string;
    },
  ) {}

  /** A token document was created or re-registered under [uid]. */
  async onRegistered(input: {
    readonly uid: string;
    readonly tokenId: string;
    readonly registeredAtMs: number;
  }): Promise<'owned' | 'transferred' | 'rejected_stale'> {
    const decision = await this.deps.registry.record(input.tokenId, (current) =>
      decideOwnership(current, { uid: input.uid, registeredAtMs: input.registeredAtMs }),
    );
    // Deletes are conditional: a copy that its account registered again
    // after this event (a newer `updatedAt`) is kept; that newer
    // registration has its own event, which settles ownership.
    if (decision.action === 'transferred') {
      // The registry already names the new owner, so senders skip the old
      // copy even before this delete lands.
      await this.deps.userTokens.deleteUnlessRefreshedAfter(
        decision.previousOwnerUid,
        input.tokenId,
        input.registeredAtMs,
      );
    } else if (decision.action === 'rejected_stale') {
      await this.deps.userTokens.deleteUnlessRefreshedAfter(input.uid, input.tokenId, input.registeredAtMs);
    }
    this.deps.logger.info('fcm_token_ownership', {
      action: decision.action,
      user: this.deps.pseudonym(input.uid),
      token: this.deps.pseudonym(input.tokenId),
    });
    return decision.action;
  }

  /** A token document was deleted under [uid] (logout, rotation, cleanup). */
  async onRemoved(input: { readonly uid: string; readonly tokenId: string }): Promise<void> {
    await this.deps.registry.releaseIfOwnedBy(input.tokenId, input.uid);
  }
}
