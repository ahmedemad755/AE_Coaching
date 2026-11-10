import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOURCE-LEVEL security guards for the email-first auth stack.
///
/// - Carried over from the retired forgot-password regression file
///   (Stage 3C): auth screens never touch Hive or the session store
///   directly, and never print or log.
/// - Added in Stage 3C: phone authentication and the SMS backend can't
///   creep back in unnoticed.
String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  final screens = Directory('lib/auth/presentation/view')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('the expected auth screens exist (guards the scans below)', () {
    final names = screens.map((f) => f.uri.pathSegments.last).toSet();
    expect(names, {
      'complete_profile_view.dart',
      'forgot_password_view.dart',
      'loginview.dart',
      'register_view.dart',
      'session_reconciliation_view.dart',
      'verify_email_view.dart',
    });
  });

  group('Auth screens never handle storage or logging themselves', () {
    for (final file in screens) {
      final name = file.uri.pathSegments.last;
      test('$name: no Hive, no SessionStorage, no print/log', () {
        final source = _read(file.path);
        expect(source.toLowerCase().contains('hive'), isFalse);
        expect(source.contains('SessionStorage'), isFalse);
        expect(source.contains('print('), isFalse);
        expect(source.contains('developer.log'), isFalse);
      });
    }
  });

  test('the email data source never logs a password or an email address', () {
    final source = _read(
      'lib/auth/data/datasources/email_auth_remote_data_source.dart',
    );
    final logCalls = RegExp(
      r'developer\.log\(([^;]*)\);',
      dotAll: true,
    ).allMatches(source).map((m) => m.group(1)!).toList();
    expect(logCalls, isNotEmpty);
    for (final call in logCalls) {
      expect(call.contains(r'$password'), isFalse, reason: call);
      expect(call.contains(r'$email'), isFalse, reason: call);
      expect(call.contains(r'${email'), isFalse, reason: call);
      expect(call.contains(r'$newEmail'), isFalse, reason: call);
    }
  });

  group('Phone authentication and the SMS backend are gone for good', () {
    final libSources = _dartFiles('lib')
        .where((f) => !f.path.replaceAll('\\', '/').contains('lib/l10n/'))
        .map((f) => MapEntry(f.path, _read(f.path)));

    for (final api in [
      'PhoneAuthProvider',
      'verifyPhoneNumber',
      'signInWithPhoneNumber',
      'linkWithCredential',
      'httpsCallable',
      'package:cloud_functions',
    ]) {
      test('no "$api" anywhere in lib', () {
        final hits = libSources
            .where((e) => e.value.contains(api))
            .map((e) => e.key)
            .toList();
        expect(hits, isEmpty);
      });
    }

    test('cloud_functions is no longer a dependency', () {
      expect(_read('pubspec.yaml').contains('cloud_functions'), isFalse);
    });

    test('firebase.json no longer deploys or emulates Cloud Functions', () {
      final config = _read('firebase.json');
      expect(config.contains('"functions"'), isFalse);
    });
  });
}
