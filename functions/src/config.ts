/**
 * Named constants for the Phase 5B password-reset backend. Kept in one
 * place so the values referenced throughout the design report (lease
 * duration, attempt caps, etc.) are unambiguous and easy to review.
 */

/** How long an OTP challenge stays usable after creation. */
export const OTP_EXPIRY_SECONDS = 10 * 60; // 10 minutes

/** Maximum wrong-OTP guesses across BOTH the initial claim and any
 * applying-state reclaim attempts (shared budget — see the approved
 * state machine). */
export const OTP_MAX_ATTEMPTS = 5;

/** How long a claimed/reclaimed lease is valid before another caller
 * may attempt to reclaim it. */
export const LEASE_DURATION_SECONDS = 30;

/** How long a completed challenge's hashes are retained to serve
 * idempotent-retry responses, before the whole document is eligible
 * for TTL deletion. */
export const COMPLETED_RETENTION_SECONDS = 45 * 60; // 45 minutes

/** Minimum time between two requestPasswordReset calls for the same
 * canonical phone number (resend cooldown). */
export const RESEND_COOLDOWN_SECONDS = 60;

/** Maximum requestPasswordReset calls allowed per canonical phone
 * number within the rolling window below. */
export const REQUESTS_PER_PHONE_WINDOW_MAX = 3;
export const REQUESTS_PER_PHONE_WINDOW_SECONDS = 60 * 60; // 1 hour

/** Minimum accepted password length — mirrors the existing Flutter
 * app-wide policy (see passwordPolicy.ts for the verification note on
 * whether a stronger Identity Platform policy is configured). */
export const MIN_PASSWORD_LENGTH = 6;

/** Firestore collection holding password-reset challenge documents.
 * Server-only — see firestore.rules.local for the intended (not yet
 * deployed) security rule. */
export const CHALLENGES_COLLECTION = 'passwordResetChallenges';

/** Synthetic email domain — must exactly match the Flutter app's
 * EgyptianPhoneNormalizer + _authEmailFromPhone algorithm. Never change
 * this independently of the Flutter side. */
export const SYNTHETIC_EMAIL_DOMAIN = 'ae-coaching.app';
