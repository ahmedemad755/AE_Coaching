import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Name: permissive, never unnecessarily strict', () {
    for (final name in [
      'Ahmed',
      'أحمد عماد',
      'A',
      "O'Brien",
      'Jean-Luc',
      'Ahmed 2nd',
      'José',
    ]) {
      test('accepts "$name"', () {
        expect(AuthInputRules.validateName(name), isNull);
      });
    }

    test('blank / whitespace-only is required', () {
      expect(AuthInputRules.validateName(''), NameInputError.required);
      expect(AuthInputRules.validateName('   '), NameInputError.required);
    });

    test('digits/symbols only is rejected', () {
      expect(AuthInputRules.validateName('12345'), NameInputError.noLetters);
      expect(AuthInputRules.validateName('!!!'), NameInputError.noLetters);
    });

    test('length cap is measured after normalization', () {
      expect(
        AuthInputRules.validateName('a' * AuthInputRules.nameMaxLength),
        isNull,
      );
      expect(
        AuthInputRules.validateName('a' * (AuthInputRules.nameMaxLength + 1)),
        NameInputError.tooLong,
      );
    });

    test('normalizeName trims and collapses internal whitespace', () {
      expect(AuthInputRules.normalizeName('  Ahmed   Emad \n'), 'Ahmed Emad');
    });
  });

  group('New password policy', () {
    test('minimum is 6, matching Firebase and the reset Cloud Function', () {
      expect(AuthInputRules.passwordMinLength, 6);
      expect(
        AuthInputRules.validateNewPassword('12345'),
        PasswordInputError.tooShort,
      );
      expect(AuthInputRules.validateNewPassword('123456'), isNull);
    });

    test('empty is required', () {
      expect(
        AuthInputRules.validateNewPassword(''),
        PasswordInputError.required,
      );
    });

    test('edge whitespace is rejected, never silently trimmed', () {
      for (final pw in [' secret1', 'secret1 ', '\tsecret1', '       ']) {
        expect(
          AuthInputRules.validateNewPassword(pw),
          PasswordInputError.edgeWhitespace,
          reason: '"$pw"',
        );
      }
    });

    test('internal spaces and any characters are allowed', () {
      expect(AuthInputRules.validateNewPassword('my pass phrase'), isNull);
      expect(AuthInputRules.validateNewPassword('كلمةسر١٢٣'), isNull);
    });

    test('over-long input is rejected', () {
      expect(
        AuthInputRules.validateNewPassword(
          'a' * (AuthInputRules.passwordMaxLength + 1),
        ),
        PasswordInputError.tooLong,
      );
    });
  });

  group('Confirm password', () {
    test('required, then must match exactly (case and spaces count)', () {
      expect(
        AuthInputRules.validateConfirmation('secret1', ''),
        ConfirmPasswordInputError.required,
      );
      expect(
        AuthInputRules.validateConfirmation('secret1', 'Secret1'),
        ConfirmPasswordInputError.mismatch,
      );
      expect(
        AuthInputRules.validateConfirmation('my pass', 'mypass'),
        ConfirmPasswordInputError.mismatch,
      );
      expect(AuthInputRules.validateConfirmation('secret1', 'secret1'), isNull);
    });
  });

  group('Sign-in compatibility', () {
    test('login keeps trimming, so existing accounts (all created with '
        'trimmed passwords) and autofill trailing spaces keep working', () {
      expect(AuthInputRules.passwordForSignIn('secret1 '), 'secret1');
      expect(AuthInputRules.passwordForSignIn(' secret1'), 'secret1');
    });

    test('for every password the new policy accepts, the sign-in trim is a '
        'no-op, so the stored and typed passwords always match', () {
      for (final pw in ['secret1', 'my pass phrase', 'P@ss w0rd!']) {
        expect(AuthInputRules.validateNewPassword(pw), isNull);
        expect(AuthInputRules.passwordForSignIn(pw), pw);
      }
    });
  });

  group('AuthInputGuard (domain boundary)', () {
    test('weak and edge-whitespace passwords carry distinct messages', () {
      expect(
        () => AuthInputGuard.requireNewPassword('123'),
        throwsA(
          predicate(
            (e) => e.toString().contains(AuthInputGuard.weakPasswordMessage),
          ),
        ),
      );
      expect(
        () => AuthInputGuard.requireNewPassword('secret1 '),
        throwsA(
          predicate(
            (e) => e.toString().contains(
              AuthInputGuard.passwordEdgeWhitespaceMessage,
            ),
          ),
        ),
      );
    });

    test('requireName returns the normalized name', () {
      expect(AuthInputGuard.requireName('  Ahmed   Emad '), 'Ahmed Emad');
      expect(() => AuthInputGuard.requireName('  '), throwsA(isA<Exception>()));
    });
  });

  group('Email (Stage 3B)', () {
    test('normalizes by trimming and lower-casing', () {
      expect(
        AuthInputRules.normalizeEmail('  Ahmed.Emad@Example.COM '),
        'ahmed.emad@example.com',
      );
    });

    for (final ok in [
      'a@b.co',
      'first.last+tag@sub.example.org',
      'أحمد@مثال.مصر',
      "o'brien@example.ie",
    ]) {
      test('accepts "$ok" (deliberately loose)', () {
        expect(AuthInputRules.validateEmail(ok), isNull);
      });
    }

    test('required / invalid / too long', () {
      expect(AuthInputRules.validateEmail('  '), EmailInputError.required);
      for (final bad in ['ahmed', 'ahmed@', '@example.com', 'a b@c.d', 'a@b']) {
        expect(
          AuthInputRules.validateEmail(bad),
          EmailInputError.invalid,
          reason: bad,
        );
      }
      final long = '${'a' * 250}@b.co';
      expect(AuthInputRules.validateEmail(long), EmailInputError.tooLong);
    });

    test('the phone-era synthetic domain is reserved (any case, any '
        'subdomain)', () {
      for (final reserved in [
        'u201012345678@ae-coaching.app',
        'Someone@AE-Coaching.App',
        'x@mail.ae-coaching.app',
      ]) {
        expect(
          AuthInputRules.validateEmail(reserved),
          EmailInputError.reservedDomain,
          reason: reserved,
        );
      }
      // Look-alikes are fine.
      expect(AuthInputRules.validateEmail('a@ae-coaching.application'), isNull);
      expect(AuthInputRules.validateEmail('a@notae-coaching.app'), isNull);
    });

    test('requireEmail returns the normalized address or throws', () {
      expect(AuthInputGuard.requireEmail(' A@B.co '), 'a@b.co');
      expect(() => AuthInputGuard.requireEmail('x'), throwsA(isA<Exception>()));
    });
  });
}
