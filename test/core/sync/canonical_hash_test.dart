import 'dart:convert';

import 'package:ae_coaching/core/sync/canonical_hash.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('map key order never changes the text or the fingerprint', () {
    final a = {
      'name': 'يوم الدفع',
      'orderIndex': 2,
      'activities': [
        {'id': 'a1', 'type': 'strength', 'strength': {'sets': 3, 'repsMin': 8}},
      ],
    };
    final b = {
      'activities': [
        {'strength': {'repsMin': 8, 'sets': 3}, 'type': 'strength', 'id': 'a1'},
      ],
      'orderIndex': 2,
      'name': 'يوم الدفع',
    };
    expect(canonicalJson(a), canonicalJson(b));
    expect(contentHash(a), contentHash(b));
    expect(contentHash(a), hasLength(64));
    expect(
      contentHash(a),
      sha256.convert(utf8.encode(canonicalJson(a))).toString(),
    );
  });

  test('a fixed, documented text (the format can never drift silently)', () {
    expect(
      canonicalJson({
        'b': [1, 2.5, true, null, 'x'],
        'a': {'z': 1, 'y': null},
      }),
      '{"a":{"z":1},"b":[1,2.5,true,null,"x"]}',
    );
  });

  test('null entries are the same as missing entries', () {
    expect(contentHash({'a': 1, 'b': null}), contentHash({'a': 1}));
  });

  test('integral doubles equal integers (storage round trips keep the hash)', () {
    expect(contentHash({'speedKmh': 5.0}), contentHash({'speedKmh': 5}));
    expect(contentHash({'speedKmh': 5.5}), isNot(contentHash({'speedKmh': 5})));
  });

  test('list order is meaningful (activity order is content)', () {
    expect(contentHash(['a', 'b']), isNot(contentHash(['b', 'a'])));
  });

  test('any real change changes the fingerprint', () {
    final base = {'name': 'Push', 'sets': 3};
    expect(contentHash(base), isNot(contentHash({'name': 'Push', 'sets': 4})));
    expect(contentHash(base), isNot(contentHash({'name': 'push', 'sets': 3})));
  });

  test('rejects values that have no stable form', () {
    expect(() => canonicalJson(double.nan), throwsArgumentError);
    expect(() => canonicalJson(double.infinity), throwsArgumentError);
    expect(() => canonicalJson({1: 'x'}), throwsArgumentError);
    expect(() => canonicalJson(DateTime(2026)), throwsArgumentError);
  });
}
