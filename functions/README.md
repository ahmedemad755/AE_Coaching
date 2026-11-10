# AE Coaching — Firebase Functions (retained prototype)

**Status: not exported, not deployed.** `firebase.json` has no Functions
deploy target.

## History

- The phone-OTP password-reset backend (Phase 5B: `requestPasswordReset`,
  `completePasswordReset`, SMS provider, challenge store, rate limiter, …)
  was retired with email/password authentication. Password reset now uses
  Firebase Auth's own reset-email link, so no trusted backend is required.
- `src/inactivityReminder.ts` is a retained backend prototype for scheduled
  inactivity reminders. It is not exported. Workout inactivity reminders are
  scheduled locally on each device instead.

## Layout

- `src/index.ts` — initializes the Admin SDK; exports nothing.
- `src/inactivityReminder.ts` — prototype (not exported).
- `test/unit/inactivityReminder.test.ts` — its unit tests.

## Running tests locally

```
npm install
npm run test:unit   # mocked, no Firebase project/emulator needed
```
