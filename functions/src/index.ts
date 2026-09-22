import { initializeApp } from 'firebase-admin/app';

// Initialize the Admin app once, at module load, using the runtime's
// managed service identity (Application Default Credentials) — no
// service-account key file is ever bundled or referenced here.
initializeApp();

export { requestPasswordReset } from './requestPasswordReset';
export { completePasswordReset } from './completePasswordReset';
