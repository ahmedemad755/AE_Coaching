import { normalizeEgyptianPhone, PhoneNormalizationError } from '../../src/phoneNormalizer';

describe('normalizeEgyptianPhone', () => {
  const expected = '+201012345678';

  test.each([
    '01012345678',
    '+201012345678',
    '00201012345678',
    '201012345678',
    '010 1234 5678',
    '010-1234-5678',
    '(010) 1234-5678',
  ])('"%s" normalizes to %s (matches the Flutter EgyptianPhoneNormalizer mapping)', (input) => {
    expect(normalizeEgyptianPhone(input)).toBe(expected);
  });

  test.each([
    ['01012345678', '+201012345678'],
    ['01112345678', '+201112345678'],
    ['01212345678', '+201212345678'],
    ['01512345678', '+201512345678'],
  ])('prefix in "%s" is accepted and maps to %s', (input, out) => {
    expect(normalizeEgyptianPhone(input)).toBe(out);
  });

  test.each(['', '   ', '01012345', '010123456789', '01312345678', '01412345678', '+14155552671', 'call-me-maybe', '123'])(
    '"%s" is rejected',
    (input) => {
      expect(() => normalizeEgyptianPhone(input)).toThrow(PhoneNormalizationError);
    }
  );
});
