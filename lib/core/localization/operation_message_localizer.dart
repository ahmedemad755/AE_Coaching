import 'package:ae_coaching/l10n/app_localizations.dart';

/// Turns a non-auth Cubit's error text (`state.message`) into localized,
/// user-facing feedback.
///
/// Cubits keep their existing error mapping (`mapGenericExceptionToMessage`
/// and crafted repository messages, all English and some purely technical,
/// such as an invalid session status). They are never shown verbatim: the
/// few messages a user can act on map to specific localized text, and
/// everything else maps to the localized generic error. Raw exception text
/// therefore never reaches the UI, in any language.
String localizeOperationError(AppLocalizations l10n, String message) {
  final text = message.trim();
  if (text.startsWith('User not authenticated')) {
    return l10n.feedbackSignInRequired;
  }
  if (text.startsWith('Only an inProgress session') ||
      text == 'Workout session is no longer active.') {
    return l10n.feedbackWorkoutNotActive;
  }
  if (text.endsWith(' not found.')) return l10n.feedbackItemUnavailable;
  return l10n.feedbackGenericError;
}
