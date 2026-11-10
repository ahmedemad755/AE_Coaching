import 'package:ae_coaching/auth/domain/entities/email_auth_messages.dart';
import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:ae_coaching/auth/presentation/auth_flow_navigation.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/auth/presentation/widgets/auth_dialogs.dart';
import 'package:ae_coaching/auth/presentation/widgets/resend_cooldown.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Mandatory email-verification gate (status
/// `AuthStatus.pendingEmailVerification`).
///
/// - The ONLY way forward is a refresh that comes back verified. Firebase
///   reloads the user from the server, then [AuthSuccess] → Home. Nothing
///   on this screen navigates to Home directly, and the router's guard
///   blocks Home for an unverified account anyway.
/// - Never a trap: Back (including Android system back) and "Sign out and
///   use another account" both confirm, then sign out to Login.
/// - The verification state is re-checked silently whenever the app
///   returns to the foreground, typically right after opening the link in
///   a mail app.
///
/// This gating is client-side UX. Server-side enforcement is Firestore
/// rules on `request.auth.token.email_verified` (Stage 3D).
class VerifyEmailView extends StatefulWidget {
  final String email;
  final bool verificationEmailSent;

  /// Injectable for tests. Production uses the 60s default.
  final Duration resendCooldown;

  const VerifyEmailView({
    super.key,
    required this.email,
    this.verificationEmailSent = false,
    this.resendCooldown = ResendCooldown.defaultDuration,
  });

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView>
    with WidgetsBindingObserver {
  late final ResendCooldown _cooldown = ResendCooldown(
    duration: widget.resendCooldown,
  );
  late String _email = widget.email;
  late bool _emailSent = widget.verificationEmailSent;

  /// Set when the user taps "I've verified", so a still-unverified result
  /// is reported to them. Silent automatic checks stay quiet.
  bool _explicitCheckPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.verificationEmailSent) _cooldown.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldown.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AuthCubit>().refreshEmailVerification(silent: true);
    }
  }

  String get _languageCode => Localizations.localeOf(context).languageCode;
  bool get _isLoading => context.read<AuthCubit>().state is AuthLoading;

  void _checkVerified() {
    if (_isLoading) return;
    _explicitCheckPending = true;
    context.read<AuthCubit>().refreshEmailVerification();
  }

  void _resend() {
    if (_isLoading || _cooldown.isActive) return;
    context.read<AuthCubit>().resendVerificationEmail(
      languageCode: _languageCode,
    );
  }

  Future<void> _confirmSignOut() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      showAuthSnackBar(context, l10n.verificationInProgressMessage);
      return;
    }
    if (await confirmAuthSignOut(context, l10n.leaveEmailVerificationBody) &&
        mounted) {
      context.read<AuthCubit>().signOut();
    }
  }

  Future<void> _changeEmail() async {
    if (_isLoading) return;
    final newEmail = await showDialog<String>(
      context: context,
      builder: (_) => const _ChangeEmailDialog(),
    );
    if (newEmail == null || !mounted) return;
    context.read<AuthCubit>().requestEmailChange(
      newEmail: newEmail,
      languageCode: _languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmSignOut();
      },
      child: Scaffold(
        body: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) async {
            if (state is AuthSuccess && state.user != null) {
              await AuthFlowNavigation.enterApp(
                context,
                state.user!,
                message: state.message,
              );
            } else if (state is AuthEmailVerificationRequired) {
              setState(() => _email = state.email);
              if (_explicitCheckPending) {
                showAuthSnackBar(context, l10n.emailNotVerifiedYetMessage);
              }
              _explicitCheckPending = false;
            } else if (state is AuthProfileUnavailable) {
              AuthFlowNavigation.toAccountCheck(context);
            } else if (state is AuthProfileIncomplete) {
              AuthFlowNavigation.toCompleteProfile(context, state.email);
            } else if (state is AuthVerificationEmailSent) {
              setState(() => _emailSent = true);
              _cooldown.start();
              showAuthSnackBar(context, l10n.verificationEmailSentMessage);
            } else if (state is AuthEmailChangeRequested) {
              showAuthSnackBar(
                context,
                l10n.emailChangeRequestedMessage(state.newEmail),
              );
            } else if (state is AuthLegacyAccountSignedOut) {
              AuthFlowNavigation.toLogin(
                context,
                notice: l10n.legacyAccountSignedOutMessage,
              );
            } else if (state is AuthSignedOut) {
              AuthFlowNavigation.toLogin(context);
            } else if (state is AuthError) {
              _explicitCheckPending = false;
              if (EmailAuthMessages.endedSession.contains(state.message)) {
                AuthFlowNavigation.toLogin(context, notice: state.message);
              } else {
                showAuthSnackBar(context, state.message, isError: true);
              }
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return AuthCardScaffold(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    color: context.authBlue,
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  AuthTitle(
                    title: l10n.verifyEmailTitle,
                    subtitle: _emailSent
                        ? l10n.verifyEmailBody(_email)
                        : l10n.verifyEmailNotSentBody(_email),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.verifyEmailSpamHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.authMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    key: const Key('verify_email_check_button'),
                    label: l10n.iveVerifiedButton,
                    loading: isLoading,
                    onPressed: _checkVerified,
                  ),
                  const SizedBox(height: 12),
                  ListenableBuilder(
                    listenable: _cooldown,
                    builder: (context, _) => OutlinedButton(
                      key: const Key('verify_email_resend_button'),
                      onPressed: isLoading || _cooldown.isActive
                          ? null
                          : _resend,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.authBlue,
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(color: context.authBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _cooldown.isActive
                            ? l10n.resendCodeIn(_cooldown.remainingSeconds)
                            : l10n.resendEmailButton,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('verify_email_change_button'),
                    onPressed: isLoading ? null : _changeEmail,
                    child: Text(l10n.changeEmailButton),
                  ),
                  TextButton(
                    key: const Key('verify_email_sign_out_button'),
                    onPressed: isLoading ? null : _confirmSignOut,
                    child: Text(
                      l10n.signOutUseAnotherAccount,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.authMuted),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Collects and validates the new address. Returns it (normalized) or
/// null when cancelled.
class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog();

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(AuthInputRules.normalizeEmail(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.changeEmailButton),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.changeEmailBody),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('change_email_field'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(hintText: l10n.newEmailHint),
              validator: (value) => localizeEmailError(
                l10n,
                AuthInputRules.validateEmail(value ?? ''),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('change_email_submit'),
          onPressed: _submit,
          child: Text(l10n.sendLinkButton),
        ),
      ],
    );
  }
}
