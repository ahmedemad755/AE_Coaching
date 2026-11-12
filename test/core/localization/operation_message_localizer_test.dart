import 'dart:io';

import 'package:ae_coaching/core/errors/exception_message_mapper.dart';
import 'package:ae_coaching/core/localization/operation_message_localizer.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every literal `Exception('…')` message outside auth, read from source, so
/// a new technical message can never reach users untranslated.
List<String> _craftedMessages() {
  final pattern = RegExp(r"Exception\(\s*'([^'$]+)'");
  final messages = <String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.startsWith('lib/auth/') || path.startsWith('lib/l10n/')) continue;
    for (final match in pattern.allMatches(entity.readAsStringSync())) {
      messages.add(match.group(1)!);
    }
  }
  return messages.toList()..sort();
}

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    group('${locale.languageCode}:', () {
      late AppLocalizations l10n;
      setUpAll(() async => l10n = await AppLocalizations.delegate.load(locale));

      test('actionable messages map to specific localized text', () {
        expect(
          localizeOperationError(l10n, 'User not authenticated'),
          l10n.feedbackSignInRequired,
        );
        expect(
          localizeOperationError(l10n, 'Workout template not found.'),
          l10n.feedbackItemUnavailable,
        );
        expect(
          localizeOperationError(
            l10n,
            'Only an inProgress session can be completed '
            '(current status: completed).',
          ),
          l10n.feedbackWorkoutNotActive,
        );
      });

      test(
        'the generic fallback and unknown text map to the generic error',
        () {
          expect(
            localizeOperationError(
              l10n,
              mapGenericExceptionToMessage(StateError('raw')),
            ),
            l10n.feedbackGenericError,
          );
          expect(
            localizeOperationError(l10n, '[cloud_firestore/unavailable] raw'),
            l10n.feedbackGenericError,
          );
        },
      );

      test('no crafted repository message is ever shown verbatim', () {
        final crafted = _craftedMessages();
        expect(crafted, isNotEmpty);
        final localized = {
          l10n.feedbackSignInRequired,
          l10n.feedbackItemUnavailable,
          l10n.feedbackWorkoutNotActive,
          l10n.feedbackGenericError,
        };
        for (final message in crafted) {
          final shown = localizeOperationError(l10n, message);
          expect(localized, contains(shown), reason: message);
          if (locale.languageCode == 'ar') {
            expect(shown, isNot(message), reason: message);
          }
        }
      });
    });
  }
}
