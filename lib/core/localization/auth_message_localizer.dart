import 'package:ae_coaching/auth/domain/entities/email_auth_messages.dart';
import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';

/// Translates the fixed success messages AuthCubit emits.
String localizeAuthMessage(AppLocalizations l10n, String? message) {
  switch (message) {
    case 'Logged in successfully':
      return l10n.loginSuccessMessage;
    case 'Email verified successfully':
      return l10n.emailVerifiedSuccessMessage;
    case 'Account setup complete':
      return l10n.accountSetupCompleteMessage;
    default:
      return message ?? l10n.genericSuccess;
  }
}

/// Centralized translation of the fixed set of English auth error strings
/// produced by the email-first flow ([EmailAuthMessages]) and the
/// domain input guards ([AuthInputGuard]). Matching is exact, and
/// auth_message_localizer_test.dart extracts every message from source
/// and fails if one is untranslated. Unknown text passes through
/// unchanged.
String localizeAuthError(AppLocalizations l10n, String message) {
  switch (message) {
    case EmailAuthMessages.incorrectCredentials:
      return l10n.authErrorIncorrectEmailCredentials;
    case EmailAuthMessages.emailInUse:
      return l10n.authErrorEmailInUse;
    case EmailAuthMessages.newEmailInUse:
      return l10n.authErrorNewEmailInUse;
    case EmailAuthMessages.recentLogin:
      return l10n.authErrorRecentLoginEmail;
    case EmailAuthMessages.sessionExpired:
      return l10n.authErrorSessionExpired;
    case EmailAuthMessages.noSession:
      return l10n.authErrorSessionEnded;
    case EmailAuthMessages.network:
      return l10n.authErrorNetwork;
    case EmailAuthMessages.tooManyRequests:
      return l10n.authErrorTooManyRequests;
    case EmailAuthMessages.disabled:
      return l10n.authErrorAccountDisabled;
    case EmailAuthMessages.generic:
      return l10n.authErrorGeneric;
    case EmailAuthMessages.profilePermissionDenied:
      return l10n.authErrorProfilePermissionDenied;
    case EmailAuthMessages.profileConflicting:
      return l10n.authErrorProfileConflicting;
    case AuthInputGuard.weakPasswordMessage:
      return l10n.authErrorWeakPassword;
    case AuthInputGuard.passwordEdgeWhitespaceMessage:
      return l10n.passwordEdgeWhitespaceError;
    case AuthInputGuard.invalidNameMessage:
      return l10n.authErrorInvalidName;
    case AuthInputGuard.invalidEmailMessage:
      return l10n.emailInvalidError;
    default:
      return message;
  }
}

String? localizeNameError(AppLocalizations l10n, NameInputError? error) {
  switch (error) {
    case null:
      return null;
    case NameInputError.required:
      return l10n.fullNameRequired;
    case NameInputError.tooLong:
      return l10n.nameTooLong(AuthInputRules.nameMaxLength);
    case NameInputError.noLetters:
      return l10n.nameNeedsLetters;
  }
}

String? localizeNewPasswordError(
  AppLocalizations l10n,
  PasswordInputError? error,
) {
  switch (error) {
    case null:
      return null;
    case PasswordInputError.required:
      return l10n.passwordRequired;
    case PasswordInputError.tooShort:
      return l10n.passwordMinLengthError(AuthInputRules.passwordMinLength);
    case PasswordInputError.tooLong:
      return l10n.passwordMaxLengthError(AuthInputRules.passwordMaxLength);
    case PasswordInputError.edgeWhitespace:
      return l10n.passwordEdgeWhitespaceError;
  }
}

String? localizeConfirmPasswordError(
  AppLocalizations l10n,
  ConfirmPasswordInputError? error,
) {
  switch (error) {
    case null:
      return null;
    case ConfirmPasswordInputError.required:
      return l10n.confirmPasswordRequired;
    case ConfirmPasswordInputError.mismatch:
      return l10n.passwordsDoNotMatch;
  }
}

String? localizeEmailError(AppLocalizations l10n, EmailInputError? error) {
  switch (error) {
    case null:
      return null;
    case EmailInputError.required:
      return l10n.emailRequired;
    case EmailInputError.invalid:
      return l10n.emailInvalidError;
    case EmailInputError.tooLong:
      return l10n.emailTooLongError;
    case EmailInputError.reservedDomain:
      return l10n.emailReservedError;
  }
}
