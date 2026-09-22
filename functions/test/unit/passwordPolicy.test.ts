import { validatePasswordPolicy, WeakPasswordError } from '../../src/passwordPolicy';

describe('validatePasswordPolicy', () => {
  test('accepts a 6+ character password', () => {
    expect(() => validatePasswordPolicy('abcdef')).not.toThrow();
    expect(() => validatePasswordPolicy('longerpassword123')).not.toThrow();
  });

  test('rejects fewer than 6 characters', () => {
    expect(() => validatePasswordPolicy('abc')).toThrow(WeakPasswordError);
  });

  test('rejects an empty password', () => {
    expect(() => validatePasswordPolicy('')).toThrow(WeakPasswordError);
  });
});
