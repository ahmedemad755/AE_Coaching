import 'package:ae_coaching/auth/data/datasources/user_profile_store.dart';
import 'package:ae_coaching/auth/domain/validation/profile_integrity.dart';
import 'package:flutter_test/flutter_test.dart';

const _now = 'NOW';

Map<String, dynamic>? _write(Map<String, dynamic>? existing) => profileWriteFor(
  existing: existing,
  uid: 'u',
  name: 'Recovered Name',
  email: 'a@example.com',
  now: _now,
);

void main() {
  group('assessProfile: only a complete, matching profile is valid', () {
    test('no document → missing', () {
      expect(assessProfile(null, 'u'), ProfileCondition.missing);
    });

    test('matching uid + valid name → valid', () {
      expect(
        assessProfile({'uid': 'u', 'name': 'Ahmed'}, 'u'),
        ProfileCondition.valid,
      );
    });

    for (final bad in <Map<String, dynamic>>[
      {'uid': 'u'},
      {'uid': 'u', 'name': ''},
      {'uid': 'u', 'name': '   '},
      {'uid': 'u', 'name': '1234'},
      {'uid': 'u', 'name': 42},
      {'name': 'Ahmed'},
      <String, dynamic>{},
    ]) {
      test('$bad → repairable (never silently valid)', () {
        expect(assessProfile(bad, 'u'), ProfileCondition.repairable);
      });
    }

    test("another account's uid → conflicting", () {
      expect(
        assessProfile({'uid': 'other', 'name': 'Ahmed'}, 'u'),
        ProfileCondition.conflicting,
      );
    });
  });

  group('profileWriteFor: create or repair without destroying data', () {
    test('missing → full create', () {
      expect(_write(null), {
        'uid': 'u',
        'name': 'Recovered Name',
        'email': 'a@example.com',
        'createdAt': _now,
        'updatedAt': _now,
      });
    });

    test('valid → no write (retry is a no-op)', () {
      expect(_write({'uid': 'u', 'name': 'Ahmed', 'createdAt': 'T0'}), isNull);
    });

    test('conflicting → no write, ever', () {
      expect(_write({'uid': 'other', 'name': ''}), isNull);
    });

    test('blank name → only name and updatedAt; createdAt, email and other '
        'fields are preserved', () {
      expect(
        _write({
          'uid': 'u',
          'name': '',
          'email': 'old@example.com',
          'createdAt': 'T0',
          'customField': 'kept',
        }),
        {'name': 'Recovered Name', 'updatedAt': _now},
      );
    });

    test('missing uid field → adds uid, keeps the valid name', () {
      expect(_write({'name': 'Ahmed', 'createdAt': 'T0'}), {
        'uid': 'u',
        'email': 'a@example.com',
        'updatedAt': _now,
      });
    });

    test('a profile that never got createdAt receives one (and only then)', () {
      expect(_write({'uid': 'u', 'name': ''})!['createdAt'], _now);
      expect(
        _write({
          'uid': 'u',
          'name': '',
          'createdAt': 'T0',
        })!.containsKey('createdAt'),
        isFalse,
      );
    });
  });
}
