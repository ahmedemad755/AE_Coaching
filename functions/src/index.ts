import { initializeApp } from 'firebase-admin/app';

// Initialize the Admin app once, at module load, using the runtime's
// managed service identity (Application Default Credentials) — no
// service-account key file is ever bundled or referenced here.
initializeApp();

// Workout inactivity reminders (built and tested locally; not deployed:
// deploy only with `firebase deploy --only functions` after approval).
export { onWorkoutSessionCreated, onWorkoutSetCreated } from './inactivity/entrypoints/activityTriggers';
export { onReminderPreferencesWritten } from './inactivity/entrypoints/preferencesTrigger';
export { sendDueInactivityReminders } from './inactivity/entrypoints/reminderScheduler';
export { onFcmTokenWritten } from './tokens/entrypoints/tokenOwnershipTriggers';
