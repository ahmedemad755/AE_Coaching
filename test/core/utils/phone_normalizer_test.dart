import 'package:ae_coaching/core/utils/phone_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EgyptianPhoneNormalizer.normalize — equivalent valid inputs', () {
    const expected = '+201012345678';

    for (final input in <String>[
      '01012345678',
      '+201012345678',
      '00201012345678',
      '201012345678',
      '010 1234 5678',
      '010-1234-5678',
      '(010) 1234-5678',
      '  01012345678  ',
    ]) {
      test('"$input" normalizes to $expected', () {
        expect(EgyptianPhoneNormalizer.normalize(input), expected);
      });
    }
  });

  group('EgyptianPhoneNormalizer.normalize — all valid prefixes', () {
    const cases = {
      '01012345678': '+201012345678',
      '01112345678': '+201112345678',
      '01212345678': '+201212345678',
      '01512345678': '+201512345678',
    };

    cases.forEach((input, expected) {
      test('prefix in "$input" is accepted and maps to $expected', () {
        expect(EgyptianPhoneNormalizer.normalize(input), expected);
      });
    });
  });

  group('EgyptianPhoneNormalizer.normalize — invalid input is rejected', () {
    test('empty string throws', () {
      expect(
        () => EgyptianPhoneNormalizer.normalize(''),
        throwsA(isA<PhoneNormalizationException>()),
      );
    });

    test('whitespace-only string throws', () {
      expect(
        () => EgyptianPhoneNormalizer.normalize('   '),
        throwsA(isA<PhoneNormalizationException>()),
      );
    });

    test('too short throws', () {
      expect(
        () => EgyptianPhoneNormalizer.normalize('01012345'),
        throwsA(isA<PhoneNormalizationException>()),
      );
    });

    test('too long throws', () {
      expect(
        () => EgyptianPhoneNormalizer.normalize('010123456789'),
        throwsA(isA<PhoneNormalizationException>()),
      );
    });

    test('unsupported Egyptian prefix (013) throws', () {
      expect(
        () => EgyptianPhoneNormalizer.normalize('01312345678'),
        throwsA(isA<PhoneNormalizationException>()),
      );
    });

    test('unsupported Egyptian prefix (014) throws', () {
      expect(
        () => EgyptianPhoneNormalizer.normalize('01412345678'),
        throwsA(isA<PhoneNormalizationException>()),
      );
    });

    test('non-Egyptian international number (US) throws', () {
      expect(
        () => EgyptianPhoneNormalizer.normalize('+14155552671'),
        throwsA(isA<PhoneNormalizationException>()),
      );
    });

    test('letters/random text throws', () {
      expect(
        () => EgyptianPhoneNormalizer.normalize('call-me-maybe'),
        throwsA(isA<PhoneNormalizationException>()),
      );
    });

    test('digits with no recognizable shape throws', () {
      expect(
        () => EgyptianPhoneNormalizer.normalize('123'),
        throwsA(isA<PhoneNormalizationException>()),
      );
    });
  });

  group(
    'EgyptianPhoneNormalizer.normalize — synthetic-email compatibility',
    () {
      // The existing Firebase synthetic-email derivation strips every
      // non-digit character (including the leading '+') from whatever
      // canonical phone string it is given. This locks in that the
      // normalizer's output continues to produce the exact same digit
      // string as the old duplicated formatPhoneNumber() implementations
      // did, so existing users' u<digits>@ae-coaching.app accounts are
      // unaffected.
      test('canonical output strips to the historical digit string', () {
        final canonical = EgyptianPhoneNormalizer.normalize('01012345678');
        final digitsOnly = canonical.replaceAll(RegExp(r'[^0-9]'), '');
        expect(digitsOnly, '201012345678');
      });
    },
  );
}
