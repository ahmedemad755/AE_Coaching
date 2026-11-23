import 'dart:convert';
import 'dart:io';

import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every user-facing English error string the client can produce, pulled
/// from the source files themselves, so adding a message without
/// translating it fails here instead of reaching an Arabic user in
/// English.
Set<String> _clientAuthErrorStrings() {
  String read(String p) => File(p).readAsStringSync().replaceAll('\r\n', '\n');
  String join(String literals) => RegExp(
    r"'([^']*)'|"
    r'"([^"]*)"',
  ).allMatches(literals).map((m) => m.group(1) ?? m.group(2)!).join();

  final strings = <String>{};
  // Every message constant the email flow can surface.
  final emailMessages = read(
    'lib/auth/domain/entities/email_auth_messages.dart',
  );
  for (final m in RegExp(
    r"""static const String \w+ =\s*((?:(?:'[^']*'|"[^"]*")\s*)+);""",
  ).allMatches(emailMessages)) {
    strings.add(join(m.group(1)!));
  }
  // Every guard message.
  final rules = read('lib/auth/domain/validation/auth_input_rules.dart');
  for (final m in RegExp(
    r"""static const String \w+Message =\s*((?:(?:'[^']*'|"[^"]*")\s*)+);""",
  ).allMatches(rules)) {
    strings.add(join(m.group(1)!));
  }
  // Any literal thrown directly by the email data source.
  final dataSource = read(
    'lib/auth/data/datasources/email_auth_remote_data_source.dart',
  );
  for (final m in RegExp(
    r"Exception\(\s*('[^']*')\s*\)",
  ).allMatches(dataSource)) {
    strings.add(join(m.group(1)!));
  }
  return strings;
}

Map<String, int> _topLevelKeyCounts(String arbPath) {
  final counts = <String, int>{};
  final keyPattern = RegExp(r'^  "([^"]+)"\s*:', multiLine: true);
  for (final m in keyPattern.allMatches(File(arbPath).readAsStringSync())) {
    counts.update(m.group(1)!, (v) => v + 1, ifAbsent: () => 1);
  }
  return counts;
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  group('localizeAuthError covers every client error string', () {
    final messages = _clientAuthErrorStrings();

    test('the extractor found the expected volume of messages', () {
      expect(messages.length, greaterThanOrEqualTo(16));
      expect(messages, contains('Incorrect email or password.'));
      expect(
        messages,
        contains('Your session has ended. Please sign in again.'),
      );
    });

    for (final message in messages) {
      test('Arabic translation exists: "$message"', () {
        final translated = localizeAuthError(ar, message);
        expect(translated, isNot(message));
        expect(translated.trim(), isNotEmpty);
      });
    }

    test('unknown (e.g. backend-provided) text passes through unchanged', () {
      expect(localizeAuthError(ar, 'Server says no.'), 'Server says no.');
    });
  });

  group('validation message mappers', () {
    test('every enum value maps to a non-empty message in both '
        'languages', () {
      for (final l10n in [en, ar]) {
        for (final e in NameInputError.values) {
          expect(localizeNameError(l10n, e), isNotEmpty);
        }
        for (final e in PasswordInputError.values) {
          expect(localizeNewPasswordError(l10n, e), isNotEmpty);
        }
        for (final e in ConfirmPasswordInputError.values) {
          expect(localizeConfirmPasswordError(l10n, e), isNotEmpty);
        }
        for (final e in EmailInputError.values) {
          expect(localizeEmailError(l10n, e), isNotEmpty);
        }
      }
    });

    test('valid input maps to null (no error shown)', () {
      expect(localizeNameError(en, null), isNull);
      expect(localizeNewPasswordError(en, null), isNull);
      expect(localizeConfirmPasswordError(en, null), isNull);
      expect(localizeEmailError(en, null), isNull);
    });

    test('limits in messages come from the rules, not hard-coded text', () {
      expect(
        localizeNewPasswordError(en, PasswordInputError.tooShort),
        contains('${AuthInputRules.passwordMinLength}'),
      );
      expect(
        localizeNameError(ar, NameInputError.tooLong),
        contains('${AuthInputRules.nameMaxLength}'),
      );
    });
  });

  group('ARB integrity', () {
    test('no duplicate keys (a duplicate silently overrides an earlier '
        'translation)', () {
      for (final path in ['lib/l10n/app_en.arb', 'lib/l10n/app_ar.arb']) {
        final dups = _topLevelKeyCounts(
          path,
        ).entries.where((e) => e.value > 1).map((e) => e.key).toList();
        expect(dups, isEmpty, reason: path);
      }
    });

    test('Arabic defines every English message key', () {
      final enKeys =
          (jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
                  as Map<String, dynamic>)
              .keys
              .where((k) => !k.startsWith('@'))
              .toSet();
      final arKeys =
          (jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
                  as Map<String, dynamic>)
              .keys
              .where((k) => !k.startsWith('@'))
              .toSet();
      expect(enKeys.difference(arKeys), isEmpty);
    });
  });
}
