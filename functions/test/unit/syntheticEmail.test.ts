import { syntheticEmailFromCanonicalPhone } from '../../src/syntheticEmail';

describe('syntheticEmailFromCanonicalPhone', () => {
  test('maps +201012345678 to u201012345678@ae-coaching.app exactly, '
    + 'matching the Flutter _authEmailFromPhone algorithm', () => {
    expect(syntheticEmailFromCanonicalPhone('+201012345678')).toBe(
      'u201012345678@ae-coaching.app'
    );
  });

  test('strips all non-digit characters, including the leading +', () => {
    expect(syntheticEmailFromCanonicalPhone('+20 101 234 5678')).toBe(
      'u201012345678@ae-coaching.app'
    );
  });

  test('throws for an input with no digits at all', () => {
    expect(() => syntheticEmailFromCanonicalPhone('+')).toThrow();
  });
});
