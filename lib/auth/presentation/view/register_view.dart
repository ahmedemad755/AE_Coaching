import 'package:ae_coaching/auth/domain/validation/auth_input_rules.dart';
import 'package:ae_coaching/auth/presentation/auth_flow_navigation.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/auth/presentation/widgets/auth_dialogs.dart';
import 'package:ae_coaching/auth/presentation/widgets/auth_password_field.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/theme/auth_screen_theme.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Email-first registration (Stage 3B): name, email, password, confirm.
///
/// Success always continues to Verify Email. The account exists from
/// here on, but it is NOT a local session and can't reach Home until the
/// email is verified. Validation rules live in [AuthInputRules], and the
/// use case re-checks them before Firebase is called. The password is
/// sent exactly as typed (edge whitespace is rejected, never trimmed).
class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> _confirmFieldKey = GlobalKey();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  /// Errors appear only after the first submit attempt, then update live.
  bool _submitAttempted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    String hint,
    IconData icon, {
    String? helperText,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final blue = context.authBlue;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: blue),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: blue, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: blue.withValues(alpha: 0.4)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
    );
  }

  void _submit() {
    if (context.read<AuthCubit>().state is AuthLoading) return;
    setState(() => _submitAttempted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().registerWithEmail(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      languageCode: Localizations.localeOf(context).languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: AuthScreenTheme.background(context),
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) async {
            if (state is AuthEmailVerificationRequired) {
              AuthFlowNavigation.toVerifyEmail(
                context,
                state.email,
                verificationEmailSent: state.verificationEmailSent,
              );
            } else if (state is AuthSuccess && state.user != null) {
              // Not reachable for a new email/password account (it is
              // always unverified), but routed safely if a provider ever
              // returns a verified identity.
              await AuthFlowNavigation.enterApp(context, state.user!);
            } else if (state is AuthProfileUnavailable) {
              AuthFlowNavigation.toAccountCheck(context);
            } else if (state is AuthError) {
              showAuthSnackBar(context, state.message, isError: true);
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;
            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      decoration: BoxDecoration(
                        color: AuthScreenTheme.panelColor(context),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.4
                                  : 0.16,
                            ),
                            blurRadius: 34,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          autovalidateMode: _submitAttempted
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
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
                              Text(
                                l10n.createAccountTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.authDark,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.startJourneySubtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: context.authMuted),
                              ),
                              const SizedBox(height: 22),
                              TextFormField(
                                key: const Key('register_name_field'),
                                controller: _nameController,
                                enabled: !isLoading,
                                keyboardType: TextInputType.name,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                maxLength: AuthInputRules.nameMaxLength + 10,
                                onFieldSubmitted: (_) =>
                                    _emailFocus.requestFocus(),
                                decoration: _fieldDecoration(
                                  l10n.fullNameHint,
                                  Icons.person,
                                ),
                                validator: (value) => localizeNameError(
                                  l10n,
                                  AuthInputRules.validateName(value ?? ''),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('register_email_field'),
                                controller: _emailController,
                                focusNode: _emailFocus,
                                enabled: !isLoading,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                // Email addresses read left-to-right in
                                // Arabic too.
                                textDirection: TextDirection.ltr,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [AutofillHints.email],
                                onFieldSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                                decoration: _fieldDecoration(
                                  l10n.emailHint,
                                  Icons.email_outlined,
                                ),
                                validator: (value) => localizeEmailError(
                                  l10n,
                                  AuthInputRules.validateEmail(value ?? ''),
                                ),
                              ),
                              const SizedBox(height: 14),
                              AuthPasswordField(
                                key: const Key('register_password_field'),
                                toggleKey: const Key(
                                  'register_password_toggle',
                                ),
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                enabled: !isLoading,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    _confirmFocus.requestFocus(),
                                onChanged: (_) {
                                  // Keep "passwords do not match" honest
                                  // when the first field changes after
                                  // the second was filled in.
                                  if (_submitAttempted &&
                                      _confirmController.text.isNotEmpty) {
                                    _confirmFieldKey.currentState?.validate();
                                  }
                                },
                                decoration: _fieldDecoration(
                                  l10n.passwordHint,
                                  Icons.lock,
                                  helperText: l10n.passwordRequirementsHelper(
                                    AuthInputRules.passwordMinLength,
                                  ),
                                ),
                                validator: (value) => localizeNewPasswordError(
                                  l10n,
                                  AuthInputRules.validateNewPassword(
                                    value ?? '',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              AuthPasswordField(
                                key: const Key('register_confirm_field'),
                                fieldKey: _confirmFieldKey,
                                controller: _confirmController,
                                focusNode: _confirmFocus,
                                enabled: !isLoading,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: _fieldDecoration(
                                  l10n.confirmPasswordHint,
                                  Icons.lock_outline,
                                ),
                                validator: (value) =>
                                    localizeConfirmPasswordError(
                                      l10n,
                                      AuthInputRules.validateConfirmation(
                                        _passwordController.text,
                                        value ?? '',
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  key: const Key('register_submit_button'),
                                  onPressed: isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    disabledBackgroundColor: context.authBlue
                                        .withValues(alpha: 0.7),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 8,
                                    shadowColor: context.authBlue.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                  child: isLoading
                                      ? SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                            strokeWidth: 2.4,
                                          ),
                                        )
                                      : Text(
                                          l10n.createAccountButton,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
