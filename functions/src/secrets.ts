import { defineSecret } from 'firebase-functions/params';

/**
 * Two INDEPENDENT Secret Manager secrets — deliberate key separation
 * per the approved Phase 5B design. Neither value is ever committed,
 * logged, printed, returned to a client, or stored in Firestore.
 *
 * Actual secret VALUES are provisioned later via:
 *   firebase functions:secrets:set OTP_HMAC_PEPPER
 *   firebase functions:secrets:set PASSWORD_INTENT_HMAC_PEPPER
 *   firebase functions:secrets:set SMS_PROVIDER_API_KEY   (Twilio or equivalent)
 * — none of that is done in this stage (local/emulator only).
 */
export const OTP_HMAC_PEPPER = defineSecret('OTP_HMAC_PEPPER');
export const PASSWORD_INTENT_HMAC_PEPPER = defineSecret('PASSWORD_INTENT_HMAC_PEPPER');

/** Real SMS provider credentials (Twilio's three-part model — Account
 * SID, Auth Token, sending number). Read only by the production
 * SmsProvider implementation. Never referenced by FakeSmsProvider
 * (tests) and never provisioned with real values in this stage. */
export const SMS_PROVIDER_ACCOUNT_SID = defineSecret('SMS_PROVIDER_ACCOUNT_SID');
export const SMS_PROVIDER_AUTH_TOKEN = defineSecret('SMS_PROVIDER_AUTH_TOKEN');
export const SMS_PROVIDER_FROM_NUMBER = defineSecret('SMS_PROVIDER_FROM_NUMBER');
