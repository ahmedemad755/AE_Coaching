import * as crypto from 'crypto';

/**
 * Generates a cryptographically random 6-digit OTP as a zero-padded
 * string (e.g. "004821"). Uses `crypto.randomInt`, not `Math.random`.
 */
export function generateSixDigitOtp(): string {
  const value = crypto.randomInt(0, 1_000_000);
  return value.toString().padStart(6, '0');
}

/**
 * Generates a random opaque lease identifier (used for
 * `challenge.leaseId`). Not a secret in the cryptographic sense — its
 * only job is to distinguish "which specific claim attempt is this,"
 * so any sufficiently random string works.
 */
export function generateLeaseId(): string {
  return crypto.randomUUID();
}

/**
 * Generates a random opaque challenge document ID.
 */
export function generateChallengeId(): string {
  return crypto.randomUUID();
}

/**
 * HMAC-SHA256(data, pepper), hex-encoded. `pepper` must come from
 * Secret Manager (see secrets.ts) — never hardcoded, never logged.
 */
export function hmacSha256Hex(data: string, pepper: string): string {
  return crypto.createHmac('sha256', pepper).update(data, 'utf8').digest('hex');
}

/**
 * Constant-time comparison of two hex-encoded digests. Returns false
 * (never throws) if the inputs have different lengths, since
 * `crypto.timingSafeEqual` requires equal-length buffers and comparing
 * their lengths first would itself leak a (much coarser, effectively
 * harmless for fixed-length hex digests) timing signal — but for two
 * correctly-generated SHA-256 hex digests the lengths are always equal
 * in practice, so this branch is a defensive guard, not the normal path.
 */
export function timingSafeEqualHex(a: string, b: string): boolean {
  const bufA = Buffer.from(a, 'hex');
  const bufB = Buffer.from(b, 'hex');
  if (bufA.length !== bufB.length) {
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}
