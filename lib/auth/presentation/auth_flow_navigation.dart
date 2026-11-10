import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/presentation/widgets/auth_dialogs.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Arguments for [AppNavigator.verifyEmail].
class VerifyEmailArgs {
  final String email;
  final bool verificationEmailSent;
  const VerifyEmailArgs({
    required this.email,
    this.verificationEmailSent = false,
  });
}

/// Arguments for [AppNavigator.completeProfile].
class CompleteProfileArgs {
  final String email;
  const CompleteProfileArgs({required this.email});
}

/// Writes the local "setup finished" marker for an AUTHENTICATED user.
/// Replaceable in widget tests, where real Hive I/O can't complete.
@visibleForTesting
Future<void> Function(AuthUser user) persistAuthenticatedSession = (user) =>
    sl<SessionStorage>().persistLoggedInSession(
      uid: user.uid,
      name: user.name,
      email: user.email,
    );

/// Every email-first screen ends a flow through these, so the
/// "authenticated → persist → Home" step exists exactly once and only
/// [AuthSuccess]-driven code can reach it.
class AuthFlowNavigation {
  const AuthFlowNavigation._();

  static Future<void> enterApp(
    BuildContext context,
    AuthUser user, {
    String? message,
  }) async {
    await persistAuthenticatedSession(user);
    // Lets the platform offer to save the credentials.
    TextInput.finishAutofillContext();
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizeAuthMessage(l10n, message))),
      );
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppNavigator.home,
      (route) => false,
    );
  }

  static void toVerifyEmail(
    BuildContext context,
    String email, {
    bool verificationEmailSent = false,
  }) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppNavigator.verifyEmail,
      (route) => false,
      arguments: VerifyEmailArgs(
        email: email,
        verificationEmailSent: verificationEmailSent,
      ),
    );
  }

  static void toCompleteProfile(BuildContext context, String email) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppNavigator.completeProfile,
      (route) => false,
      arguments: CompleteProfileArgs(email: email),
    );
  }

  /// Profile couldn't be confirmed. The account check shows the reason
  /// with Retry / Sign out.
  static void toAccountCheck(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppNavigator.sessionCheck,
      (route) => false,
    );
  }

  static void toLogin(BuildContext context, {String? notice}) {
    if (notice != null) {
      // The root ScaffoldMessenger keeps this visible across the route
      // change.
      showAuthSnackBar(context, notice);
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppNavigator.login,
      (route) => false,
    );
  }
}
