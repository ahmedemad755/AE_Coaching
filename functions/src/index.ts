import { initializeApp } from 'firebase-admin/app';

// Initialize the Admin app once, at module load, using the runtime's
// managed service identity (Application Default Credentials) — no
// service-account key file is ever bundled or referenced here.
initializeApp();

// Nothing is exported. The phone-OTP password-reset callables were retired
// with email/password authentication (password reset is now Firebase's own
// email link). `inactivityReminder.ts` is a retained, non-exported
// prototype: workout inactivity reminders are scheduled locally on device.
export {};
