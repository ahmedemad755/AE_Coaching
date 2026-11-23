import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:ae_coaching/core/feedback/app_feedback.dart';
import 'package:ae_coaching/auth/presentation/auth_flow_navigation.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/auth/presentation/widgets/auth_dialogs.dart';
import 'package:ae_coaching/auth/presentation/widgets/auth_password_field.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Email + password sign-in (Stage 3B).
///
/// A successful sign-in is routed by its resolved status. An unverified
/// account goes to Verify Email and is NOT recorded as a local session.
/// Only an authenticated result persists the session and enters Home.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FocusNode _passwordFocus = FocusNode();
  bool _submitAttempted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (context.read<AuthCubit>().state is AuthLoading) return;
    setState(() => _submitAttempted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().loginWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          BlocConsumer<AuthCubit, AuthState>(
            listener: (context, state) async {
              if (state is AuthSuccess && state.user != null) {
                await AuthFlowNavigation.enterApp(
                  context,
                  state.user!,
                  message: state.message,
                );
              } else if (state is AuthEmailVerificationRequired) {
                AuthFlowNavigation.toVerifyEmail(context, state.email);
              } else if (state is AuthProfileUnavailable) {
                AuthFlowNavigation.toAccountCheck(context);
              } else if (state is AuthProfileIncomplete) {
                AuthFlowNavigation.toCompleteProfile(context, state.email);
              } else if (state is AuthLegacyAccountSignedOut) {
                showAuthFeedback(
                  context,
                  l10n.legacyAccountSignedOutMessage,
                  type: FeedbackType.warning,
                );
              } else if (state is AuthError) {
                showAuthFeedback(
                  context,
                  state.message,
                  type: FeedbackType.error,
                );
              }
            },
            builder: (context, state) {
              final isLoading = state is AuthLoading;
              return AuthCardScaffold(
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _submitAttempted
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.appBrandShort,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.authBlue,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.appBrandFull,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.authDark,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.loginSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.authMuted),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          key: const Key('login_email_field'),
                          controller: _emailController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textDirection: TextDirection.ltr,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.username,
                          ],
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
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
                        const SizedBox(height: 14),
                        AuthPasswordField(
                          key: const Key('login_password_field'),
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          enabled: !isLoading,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: authFieldDecoration(
                            context,
                            hint: l10n.passwordHint,
                            icon: Icons.lock,
                          ),
                          // Sign-in never applies the new-password policy:
                          // existing accounts must keep working.
                          validator: (value) => (value == null || value.isEmpty)
                              ? l10n.passwordRequired
                              : null,
                        ),
                        const SizedBox(height: 16),
                        AuthPrimaryButton(
                          key: const Key('login_submit_button'),
                          label: l10n.loginButton,
                          loading: isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('login_forgot_button'),
                                onPressed: isLoading
                                    ? null
                                    : () => Navigator.pushNamed(
                                        context,
                                        AppNavigator.forgotPassword,
                                        arguments: _emailController.text,
                                      ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: context.authBlue,
                                  side: BorderSide(color: context.authBlue),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(l10n.forgotPassword),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextButton(
                                key: const Key('login_register_button'),
                                onPressed: isLoading
                                    ? null
                                    : () => Navigator.pushNamed(
                                        context,
                                        AppNavigator.register,
                                      ),
                                style: TextButton.styleFrom(
                                  backgroundColor: context.authSubtleFill,
                                  foregroundColor: context.authBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(l10n.registerNow),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: () => context.read<LocaleCubit>().toggle(),
                  icon: const Icon(Icons.translate),
                  color: context.authBlue,
                  tooltip: l10n.languageToggleTooltip,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
