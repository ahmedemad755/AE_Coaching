import 'package:ae_coaching/core/feedback/app_feedback.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/theme/auth_screen_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Shows auth feedback through the global feedback overlay. [message] is
/// translated when it is a known auth string (raw Firebase text never
/// reaches the user; unknown errors map to the localized generic error).
void showAuthFeedback(
  BuildContext context,
  String message, {
  FeedbackType type = FeedbackType.info,
}) {
  final l10n = AppLocalizations.of(context)!;
  AppFeedback.show(type, localizeAuthError(l10n, message));
}

/// "Leave verification?" confirmation. Resolves to true only when the
/// user explicitly picks Sign out.
Future<bool> confirmAuthSignOut(BuildContext context, String body) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.leaveVerificationTitle),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.stayButton),
        ),
        TextButton(
          key: const Key('auth_confirm_sign_out'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.signOutButton),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Theme-aware auth palette. In the light theme these resolve to the
/// original auth colors (brand blue primary, #202936 text); in the dark
/// theme they follow the app's dark color scheme.
extension AuthPalette on BuildContext {
  Color get authBlue => Theme.of(this).colorScheme.primary;
  Color get authDark => appColors.textPrimary;
  Color get authMuted => appColors.textMuted;

  /// Subtle filled-button background (light: #EEF2F5).
  Color get authSubtleFill => Theme.of(this).brightness == Brightness.dark
      ? Theme.of(this).colorScheme.surfaceContainerHighest
      : const Color(0xffeef2f5);
}

/// Visual identity shared by the auth screens: gradient background and a
/// centered card. Follows the app's light/dark theme ([AuthScreenTheme]).
class AuthCardScaffold extends StatelessWidget {
  final Widget child;
  const AuthCardScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: AuthScreenTheme.background(context),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                decoration: BoxDecoration(
                  color: AuthScreenTheme.panelColor(context),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.4 : 0.16,
                      ),
                      blurRadius: 34,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration authFieldDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
  String? helperText,
}) {
  final scheme = Theme.of(context).colorScheme;
  final blue = context.authBlue;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    helperText: helperText,
    helperMaxLines: 2,
    errorMaxLines: 3,
    counterText: '',
    prefixIcon: Icon(icon, color: blue),
    filled: true,
    fillColor: isDark
        ? Theme.of(context).inputDecorationTheme.fillColor ?? scheme.surface
        : Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    enabledBorder: border(blue),
    focusedBorder: border(blue, 1.6),
    disabledBorder: border(blue.withValues(alpha: 0.4)),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, 1.6),
  );
}

/// Primary filled button with an inline spinner while [loading].
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 8,
          shadowColor: scheme.primary.withValues(alpha: 0.35),
        ),
        child: loading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: scheme.onPrimary,
                  strokeWidth: 2.4,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
      ),
    );
  }
}

class AuthTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const AuthTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.authDark,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.authMuted),
          ),
        ],
      ],
    );
  }
}
