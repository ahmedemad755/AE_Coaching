import type { Firestore } from 'firebase-admin/firestore';
import type { RawReminderPreferences } from '../domain/reminderPreferences';
import type { ReminderPreferencesReader } from '../application/ports';

/** `users/{uid}/settings/notifications`, written by the app (Stage 3). */
export const NOTIFICATION_SETTINGS_PATH = { collection: 'settings', doc: 'notifications' } as const;

export class FirestoreReminderPreferencesReader implements ReminderPreferencesReader {
  constructor(private readonly db: Firestore) {}

  async read(uid: string): Promise<RawReminderPreferences | null> {
    const snapshot = await this.db
      .collection('users')
      .doc(uid)
      .collection(NOTIFICATION_SETTINGS_PATH.collection)
      .doc(NOTIFICATION_SETTINGS_PATH.doc)
      .get();
    if (!snapshot.exists) return null;
    const data = snapshot.data() ?? {};
    // Untrusted values; the domain validates them.
    return {
      inactivityRemindersEnabled: data.inactivityRemindersEnabled,
      language: data.language,
      timeZone: data.timeZone,
    };
  }
}
