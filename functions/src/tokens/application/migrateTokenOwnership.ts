import type { StructuredLogger } from '../../shared/application/runtimePorts';
import { planOwnershipMigration, type StoredTokenCopy } from '../domain/tokenOwnershipMigration';
import type { TokenInventory, TokenOwnershipRegistry } from './ports';

export type MigrationMode = 'dry_run' | 'apply';

export interface TokenOwnershipMigrationReport {
  readonly mode: MigrationMode;
  readonly scannedCopies: number;
  readonly distinctTokens: number;
  readonly malformedCopies: number;
  readonly alreadyOwned: number;
  /** Tokens with exactly one holder and no owner yet. */
  readonly assignable: number;
  /** Written by this run (always 0 in a dry run). */
  readonly assigned: number;
  /** Assignable, but an owner appeared before this run wrote (left as is). */
  readonly skippedExisting: number;
  readonly ambiguousTokens: number;
  /** Pseudonymous token reference and holder count; no uid, no token. */
  readonly ambiguous: readonly { readonly token: string; readonly holders: number }[];
}

/**
 * Backfills `fcmTokenOwners` for tokens stored before it existed (see
 * planOwnershipMigration). A dry run reads only. Applying only CREATES
 * missing owner records: it never overwrites an owner, never assigns an
 * ambiguous token and never deletes or edits a user's token documents.
 * Safe to run again (idempotent) and alongside the live triggers.
 */
export class MigrateTokenOwnership {
  constructor(
    private readonly deps: {
      readonly inventory: TokenInventory;
      readonly registry: TokenOwnershipRegistry;
      readonly logger: StructuredLogger;
      readonly pseudonym: (value: string) => string;
      readonly pageSize: number;
      /** Refuse to plan beyond this many copies (memory bound). */
      readonly maxCopies: number;
    },
  ) {}

  async execute(mode: MigrationMode): Promise<TokenOwnershipMigrationReport> {
    const { inventory, registry, pseudonym } = this.deps;
    const copies: StoredTokenCopy[] = [];
    for await (const copy of inventory.copies(this.deps.pageSize)) {
      if (copies.length >= this.deps.maxCopies) {
        throw new Error(`More than ${this.deps.maxCopies} token documents: raise maxCopies deliberately.`);
      }
      copies.push(copy);
    }
    const owners = await registry.ownersOf([...new Set(copies.map((copy) => copy.tokenId))]);
    const plan = planOwnershipMigration(copies, new Set(owners.keys()));

    let assigned = 0;
    let skippedExisting = 0;
    if (mode === 'apply') {
      for (const { tokenId, owner } of plan.assignments) {
        if (await registry.createIfAbsent(tokenId, owner)) assigned += 1;
        else skippedExisting += 1;
      }
    }

    const report: TokenOwnershipMigrationReport = {
      mode,
      scannedCopies: copies.length,
      distinctTokens: plan.distinctTokens,
      malformedCopies: plan.malformedCopies,
      alreadyOwned: plan.alreadyOwned,
      assignable: plan.assignments.length,
      assigned,
      skippedExisting,
      ambiguousTokens: plan.ambiguous.length,
      ambiguous: plan.ambiguous.map(({ tokenId, holderCount }) => ({ token: pseudonym(tokenId), holders: holderCount })),
    };
    const { ambiguous: _details, ...summary } = report;
    this.deps.logger.info('fcm_token_owner_migration', summary);
    return report;
  }
}
