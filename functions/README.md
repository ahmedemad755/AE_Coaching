# AE Coaching — Firebase Functions

Trusted backend using Cloud Functions 2nd gen + Firebase Admin SDK.
Includes signed-out password reset and scheduled inactivity reminders.

**Status: local/emulator only. Nothing here has been deployed.**

## Layout

- `src/phoneNormalizer.ts` — server-side Egyptian phone normalization (mirrors Flutter's `EgyptianPhoneNormalizer`)
- `src/syntheticEmail.ts` — synthetic email mapping (mirrors `_authEmailFromPhone`)
- `src/accountResolution.ts` — read-only Admin SDK phone/email → UID resolution
- `src/smsProvider.ts` — `SmsProvider` interface, `TwilioSmsProvider` (prod), `FakeSmsProvider` (tests)
- `src/crypto.ts` — OTP generation, HMAC helpers, constant-time comparison
- `src/secrets.ts` — Secret Manager parameter definitions (no values committed)
- `src/rateLimiter.ts` — per-phone rate limiting / resend cooldown
- `src/passwordPolicy.ts` — server-side password validation
- `src/challengeStore.ts` — the approved challenge state machine (transactions #1/#2)
- `src/requestPasswordReset.ts`, `src/completePasswordReset.ts` — password-reset callable functions
- `src/inactivityReminder.ts` — retained backend prototype; it is not exported or deployed. Workout inactivity reminders are scheduled locally on each device.
- `src/index.ts` — exports

## Running tests locally

```
npm install
npm run test:unit          # mocked, no Firebase project/emulator needed
npm run test:emulator:exec # spins up Auth + Firestore emulators, runs test/emulator/**
```

## NOT done yet (deliberately, per the approved stage scope)

- No secrets have been created (`OTP_HMAC_PEPPER`, `PASSWORD_INTENT_HMAC_PEPPER`,
  `SMS_PROVIDER_ACCOUNT_SID`, `SMS_PROVIDER_AUTH_TOKEN`, `SMS_PROVIDER_FROM_NUMBER`).
- No deployment (`firebase deploy`) has been run.
- The inactivity scheduler is disabled in the Functions export and has not
  been deployed. Workout inactivity reminders are now local notifications.
- `firestore.rules` (repo root) is local and NOT deployed — it includes FCM,
  inactivity-state, and password-reset rules, but is still incomplete and must
  be merged with the project's actual existing rules before any deploy.
- App Check is configured in code (`enforceAppCheck: true`) but not
  verified against a real device/Play Integrity attestation.
- Inactivity reminders use the app's current language and are scheduled
  locally on the device.
