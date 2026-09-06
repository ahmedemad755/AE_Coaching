import 'package:ae_coaching/l10n/app_localizations.dart';

/// Maps the small, fixed set of success messages [AuthCubit] emits today
/// to a localized string, without touching AuthCubit itself (it's
/// business logic — out of scope to modify for translation).
///
/// Any other message (Firebase/network error text, which is dynamic and
/// not enumerable) is shown as-is, unchanged.
String localizeAuthMessage(AppLocalizations l10n, String? message) {
  switch (message) {
    case 'Logged in successfully':
      return l10n.loginSuccessMessage;
    case 'Account created successfully. Please login.':
      return l10n.accountCreatedPendingLogin;
    case 'Account created successfully':
      return l10n.accountCreatedSuccess;
    case 'Account Verified! Please Login.':
      return l10n.accountVerifiedMessage;
    default:
      return message ?? l10n.genericSuccess;
  }
}
