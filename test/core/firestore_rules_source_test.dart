import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source guards for firestore.rules (Stage 3D). The rules' behavior is
/// tested in the emulator (firestore-tests/, `npm test`). These keep the
/// Flutter suite failing if the file is unhooked or a known-dangerous
/// pattern returns.
void main() {
  final rules = File('firestore.rules').readAsStringSync();
  final code = rules
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  test('firebase.json deploys and emulates exactly firestore.rules', () {
    final config = jsonDecode(File('firebase.json').readAsStringSync()) as Map;
    expect((config['firestore'] as Map)['rules'], 'firestore.rules');
  });

  test('no recursive wildcard: unknown paths stay denied by default', () {
    expect(code.contains('=**'), isFalse);
  });

  test('no blanket allow anywhere', () {
    expect(RegExp(r'allow [a-z, ]+:\s*if\s+true').hasMatch(code), isFalse);
    expect(RegExp(r'allow [a-z, ]+;').hasMatch(code), isFalse);
  });

  test('protected data requires a verified email', () {
    expect(code.contains('request.auth.token.email_verified == true'), isTrue);
    for (final c in [
      'exercise_sets',
      'body_measurements',
      'workout_programs',
      'workout_templates',
      'workout_sessions',
    ]) {
      final start = code.indexOf('match /$c/');
      expect(start, greaterThan(-1), reason: c);
      // Up to the block's closing brace (not the `}` of `{docId}`).
      final block = code.substring(start, code.indexOf('\n      }', start));
      expect(
        RegExp(
          r'allow [a-z, ]+: if isVerifiedOwner\(userId\)',
        ).allMatches(block).length,
        2,
        reason: '$c: read/delete and create/update both verified-owner',
      );
    }
  });

  test('every Firestore collection the app uses has an explicit rule', () {
    final used = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in RegExp(
        r"\.collection\('([^']+)'\)",
      ).allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    expect(used, isNotEmpty);
    for (final name in used) {
      expect(code.contains('match /$name/'), isTrue, reason: name);
    }
  });
}
