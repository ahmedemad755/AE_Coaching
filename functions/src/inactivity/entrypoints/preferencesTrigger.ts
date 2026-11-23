import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { appServices } from '../../compositionRoot';

/**
 * Notification preferences changed (created, updated or deleted). The use
 * case re-reads the current document, so the event payload and delivery
 * order do not matter; retries are therefore safe.
 */
export const onReminderPreferencesWritten = onDocumentWritten(
  { document: 'users/{uid}/settings/notifications', retry: true },
  (event) => appServices().syncReminderPreferences.execute(event.params.uid),
);
