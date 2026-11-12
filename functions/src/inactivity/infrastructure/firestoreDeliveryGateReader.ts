import type { Firestore } from 'firebase-admin/firestore';
import type { DeliveryGateReader } from '../application/ports';
import { type DeliveryGate, parseDeliveryGate } from '../domain/deliveryGate';

/**
 * `serverConfig/inactivityReminders`: written only by operators (Admin SDK
 * or Console); firestore.rules deny every client. A missing document means
 * delivery is off.
 */
export const DELIVERY_GATE_PATH = { collection: 'serverConfig', doc: 'inactivityReminders' } as const;

export class FirestoreDeliveryGateReader implements DeliveryGateReader {
  constructor(private readonly db: Firestore) {}

  async read(): Promise<DeliveryGate> {
    const snapshot = await this.db.collection(DELIVERY_GATE_PATH.collection).doc(DELIVERY_GATE_PATH.doc).get();
    return parseDeliveryGate(snapshot.exists ? snapshot.data() : null);
  }
}
