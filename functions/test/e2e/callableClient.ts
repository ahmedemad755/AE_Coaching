/**
 * Minimal callable-protocol HTTP client, used ONLY by the E2E tests in
 * this folder to call the REAL Functions Emulator over HTTP (as a
 * Flutter client would via `cloud_functions`), rather than importing
 * the compiled function code directly. This is what makes these tests
 * genuinely exercise: HTTP request -> Functions Emulator -> handler ->
 * Firestore/Auth Emulator, instead of just proving the handler function
 * works when called in-process (already covered by test/emulator/).
 *
 * No client SDK dependency is added for this — the callable wire
 * protocol (POST {data: ...}, response {result: ...} | {error: ...}) is
 * simple enough to speak directly with `fetch`, confirmed by reading
 * firebase-functions' own onCallHandler source rather than assumed.
 */

const FUNCTIONS_HOST = process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST ?? 'localhost:5001';
const PROJECT_ID = process.env.GCLOUD_PROJECT ?? 'ae-coaching-test';
const REGION = 'us-central1';

/**
 * A syntactically-valid but entirely unsigned JWT. The Functions
 * Emulator sets FIREBASE_DEBUG_MODE=true and
 * FIREBASE_DEBUG_FEATURES={"skipTokenVerification":true} on the
 * function process (confirmed by reading firebase-tools'
 * functionsEmulator.js), which makes firebase-functions decode this
 * WITHOUT verifying its signature (unsafeDecodeAppCheckToken) — it
 * still requires the header to be present and JWT-shaped, but the
 * token's authenticity is never actually checked in this mode. This
 * never happens in production: enforceAppCheck:true there requires a
 * real, cryptographically verified App Check token from Play Integrity
 * (or equivalent), and FIREBASE_DEBUG_MODE is never set on a deployed
 * function.
 */
function fakeAppCheckToken(): string {
  const header = Buffer.from(JSON.stringify({ alg: 'none', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ sub: 'e2e-test-app-id', app_id: 'e2e-test-app-id', exp: Math.floor(Date.now() / 1000) + 3600 })
  ).toString('base64url');
  const signature = Buffer.from('local-e2e-test-only-unsigned').toString('base64url');
  return `${header}.${payload}.${signature}`;
}

export interface CallableError {
  status?: string;
  message?: string;
  details?: unknown;
}

export interface CallableResponse<T> {
  httpStatus: number;
  result?: T;
  error?: CallableError;
}

export async function callCallable<T>(functionName: string, data: unknown): Promise<CallableResponse<T>> {
  const url = `http://${FUNCTIONS_HOST}/${PROJECT_ID}/${REGION}/${functionName}`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Firebase-AppCheck': fakeAppCheckToken(),
    },
    body: JSON.stringify({ data }),
  });
  const json = (await response.json()) as { result?: T; error?: CallableError };
  return { httpStatus: response.status, result: json.result, error: json.error };
}
