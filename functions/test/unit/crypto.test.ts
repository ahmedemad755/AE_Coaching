import {
  generateChallengeId,
  generateLeaseId,
  generateSixDigitOtp,
  hmacSha256Hex,
  timingSafeEqualHex,
} from '../../src/crypto';

describe('generateSixDigitOtp', () => {
  test('always produces exactly 6 digits, zero-padded', () => {
    for (let i = 0; i < 200; i++) {
      const otp = generateSixDigitOtp();
      expect(otp).toMatch(/^\d{6}$/);
    }
  });
});

describe('generateLeaseId / generateChallengeId', () => {
  test('produce distinct values across calls', () => {
    const a = generateLeaseId();
    const b = generateLeaseId();
    expect(a).not.toBe(b);
    const c = generateChallengeId();
    const d = generateChallengeId();
    expect(c).not.toBe(d);
  });
});

describe('hmacSha256Hex', () => {
  test('is deterministic for the same input and pepper', () => {
    expect(hmacSha256Hex('123456', 'pepperA')).toBe(hmacSha256Hex('123456', 'pepperA'));
  });

  test('differs for different peppers (domain separation)', () => {
    expect(hmacSha256Hex('123456', 'pepperA')).not.toBe(hmacSha256Hex('123456', 'pepperB'));
  });

  test('differs for different input data', () => {
    expect(hmacSha256Hex('123456', 'pepperA')).not.toBe(hmacSha256Hex('654321', 'pepperA'));
  });

  test('never contains the raw input as a substring (sanity check that '
    + 'this is a real hash, not an identity/echo function)', () => {
    const hash = hmacSha256Hex('123456', 'pepperA');
    expect(hash).not.toContain('123456');
  });
});

describe('timingSafeEqualHex', () => {
  test('returns true for identical hex digests', () => {
    const h = hmacSha256Hex('hello', 'pepper');
    expect(timingSafeEqualHex(h, h)).toBe(true);
  });

  test('returns false for different hex digests', () => {
    const h1 = hmacSha256Hex('hello', 'pepper');
    const h2 = hmacSha256Hex('world', 'pepper');
    expect(timingSafeEqualHex(h1, h2)).toBe(false);
  });

  test('returns false (never throws) for mismatched lengths', () => {
    expect(timingSafeEqualHex('ab', 'abcd')).toBe(false);
  });
});
