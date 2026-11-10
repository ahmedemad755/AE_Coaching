import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/auth/presentation/widgets/auth_dialogs.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Signed-out Forgot Password (Stage 3B): Firebase sends a reset link
/// and the user picks the new password on Firebase's own page. The app
/// never handles the reset code or the new password, so nothing here can
/// sign anyone in.
///
/// The confirmation is neutral ("if an account exists…") and shows the
/// same either way, so this screen can't be used to discover which
/// emails are registered.
class ForgotPasswordView extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordView({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail.trim(),
  );
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _sentTo;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (context.read<AuthCubit>().state is AuthLoading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().sendPasswordResetEmail(
      email: _emailController.text,
      languageCode: Localizations.localeOf(context).languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthPasswordResetEmailSent) {
            setState(() => _sentTo = state.email);
          } else if (state is AuthError) {
            showAuthSnackBar(context, state.message, isError: true);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          final sentTo = _sentTo;
          return AuthCardScaffold(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const BackButtonIcon(),
                    color: context.authBlue,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                  ),
                ),
                if (sentTo != null) ...[
                  Icon(
                    Icons.mark_email_read_outlined,
                    color: context.authBlue,
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  AuthTitle(
                    title: l10n.passwordResetEmailSentTitle,
                    subtitle: l10n.passwordResetEmailSentBody(sentTo),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.verifyEmailSpamHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.authMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    key: const Key('forgot_back_to_login_button'),
                    label: l10n.backToLoginButton,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ] else
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthTitle(
                          title: l10n.forgotPasswordTitle,
                          subtitle: l10n.forgotPasswordEmailSubtitle,
                        ),
                        const SizedBox(height: 22),
                        TextFormField(
                          key: const Key('forgot_email_field'),
                          controller: _emailController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          autocorrect: false,
                          textInputAction: TextInputAction.send,
                          autofillHints: const [AutofillHints.email],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: authFieldDecoration(
                            context,
                            hint: l10n.emailHint,
                            icon: Icons.email_outlined,
                          ),
                          validator: (value) => localizeEmailError(
                            l10n,
                            AuthInputRules.validateEmail(value ?? ''),
                          ),
                        ),
                        const SizedBox(height: 18),
                        AuthPrimaryButton(
                          key: const Key('forgot_submit_button'),
                          label: l10n.sendResetLinkButton,
                          loading: isLoading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
