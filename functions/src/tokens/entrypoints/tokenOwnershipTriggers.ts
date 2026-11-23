import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { Timestamp } from 'firebase-admin/firestore';
import { appServices } from '../../compositionRoot';

/**
 * Token ownership reconciliation on every write of a token document.
 *
 * Created or updated = a registration: the app writes `updatedAt` (server
 * time, enforced by firestore.rules) whenever a signed-in, verified user
 * registers the device: first registration, each app start, account switch
 * and token refresh. Re-registering an existing document is an UPDATE, which
 * is why this listens to writes, not only creates; it is also how legacy
 * tokens without an owner record become eligible again.
 *
 * Deleted = logout, rotation or cleanup: the owner record is released if
 * this account still owns it.
 *
 * Idempotent and order-independent (see decideOwnership and the conditional
 * deletes in ReconcileTokenOwnership), so retries are on.
 */
export const onFcmTokenWritten = onDocumentWritten(
  { document: 'users/{uid}/fcmTokens/{tokenId}', retry: true },
  async (event) => {
    const { uid, tokenId } = event.params;
    const after = event.data?.after;
    const reconcile = appServices().reconcileTokenOwnership;
    if (after === undefined || !after.exists) {
      await reconcile.onRemoved({ uid, tokenId });
      return;
    }
    const updatedAt: unknown = after.get('updatedAt');
    await reconcile.onRegistered({
      uid,
      tokenId,
      registeredAtMs:
        updatedAt instanceof Timestamp
          ? updatedAt.toMillis()
          : (after.updateTime?.toMillis() ?? Date.parse(event.time)),
    });
  },
);
