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
      'custom_exercises',
      'workout_sessions',
    ]) {
      final start = code.indexOf('match /$c/');
      expect(start, greaterThan(-1), reason: c);
      // Up to the block's closing brace (not the `}` of `{docId}`).
      final block = code.substring(start, code.indexOf('\n      }', start));
      // Every allow statement starts with the verified-owner check, and
      // together they cover reading, creating, updating and deleting.
      final allows = RegExp(r'allow ([a-z, ]+):').allMatches(block).toList();
      expect(allows.length, greaterThanOrEqualTo(2), reason: c);
      expect(
        RegExp(
          r'allow [a-z, ]+: if isVerifiedOwner\(userId\)',
        ).allMatches(block).length,
        allows.length,
        reason: '$c: every allow requires a verified owner',
      );
      final operations = {
        for (final allow in allows)
          for (final operation in allow.group(1)!.split(',')) operation.trim(),
      };
      expect(
        operations,
        containsAll(['read', 'create', 'update', 'delete']),
        reason: c,
      );
    }
  });

  test('every Firestore collection the app uses has an explicit rule', () {
    final used = <String>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final source = f.readAsStringSync();
      for (final m in RegExp(r"\.collection\('([^']+)'\)").allMatches(source)) {
        used.add(m.group(1)!);
      }
      // Synced collections are named through FirestoreRevisionCloud.
      for (final m in RegExp(r"collection: '([^']+)'").allMatches(source)) {
        used.add(m.group(1)!);
      }
    }
    expect(used, isNotEmpty);
    for (final name in used) {
      expect(code.contains('match /$name/'), isTrue, reason: name);
    }
  });
}
