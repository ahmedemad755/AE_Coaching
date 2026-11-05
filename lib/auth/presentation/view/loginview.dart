import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/core/theme/auth_screen_theme.dart';
import 'package:ae_coaching/auth/presentation/view/verify_phone_migration_view.dart';
import 'package:ae_coaching/core/utils/phone_normalizer.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController =
      TextEditingController(); // بيستقبل رقم الهاتف
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return AuthScreenTheme.fieldDecoration(
      context,
      hint: hint,
      icon: icon,
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: AuthScreenTheme.background(context),
        child: Stack(
          children: [
            BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) async {
                if (state is AuthSuccess) {
                  // Phase 4 restart-bypass fix: a legacy account that
                  // still needs phone migration must NOT have a
                  // completed Hive session written yet — otherwise
                  // killing the app on VerifyPhoneMigrationView before
                  // finishing OTP lets a restart reach Home via the
                  // Hive fast-path without ever completing migration.
                  // VerifyPhoneMigrationView already persists the same
                  // session (idempotently) once migration actually
                  // succeeds, so this branch deliberately writes
                  // nothing to Hive and only navigates.
                  if (state.user?.needsPhoneVerification == true) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localizeAuthMessage(l10n, state.message),
                          ),
                        ),
                      );
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppNavigator.verifyPhoneMigration,
                        (route) => false,
                        arguments: VerifyPhoneMigrationArgs(
                          uid: state.user!.uid,
                          name: state.user!.name,
                          phone: state.user!.phoneNumber,
                        ),
                      );
                    }
                    return;
                  }

                  if (state.user != null) {
                    await sl<SessionStorage>().persistLoggedInSession(
                      uid: state.user!.uid,
                      name: state.user!.name,
                      phone: state.user!.phoneNumber,
                    );
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizeAuthMessage(l10n, state.message)),
                      ),
                    );
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppNavigator.home,
                      (route) => false,
                    );
                  }
                } else if (state is AuthError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
              builder: (context, state) {
                return SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                          decoration: BoxDecoration(
                            color: AuthScreenTheme.panelColor(context),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 34,
                                offset: const Offset(0, 20),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  l10n.appBrandShort,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.loginSubtitle,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType
                                      .phone, // خليناها أرقام عشان تجربة المستخدم
                                  decoration: _fieldDecoration(
                                    hint: l10n.phoneNumberHint,
                                    icon: Icons.phone,
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? l10n.phoneNumberRequired
                                      : null,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _isPasswordObscured,
                                  decoration: _fieldDecoration(
                                    hint: l10n.passwordHint,
                                    icon: Icons.lock,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordObscured
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordObscured =
                                              !_isPasswordObscured;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                      ? l10n.passwordRequired
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: state is AuthLoading
                                        ? null
                                        : () {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              try {
                                                final normalizedPhone =
                                                    EgyptianPhoneNormalizer.normalize(
                                                      _emailController.text,
                                                    );

                                                context.read<AuthCubit>().login(
                                                  normalizedPhone,
                                                  _passwordController.text
                                                      .trim(),
                                                );
                                              } on PhoneNormalizationException catch (
                                                e
                                              ) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(e.message),
                                                    backgroundColor: Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 8,
                                      shadowColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.35),
                                    ),
                                    child: state is AuthLoading
                                        ? SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                            ),
                                          )
                                        : Text(
                                            l10n.loginButton,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            AppNavigator.forgotPassword,
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          side: BorderSide(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                        child: Text(l10n.forgotPassword),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            AppNavigator.register,
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          foregroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
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
                    color: Theme.of(context).colorScheme.primary,
                    tooltip: l10n.languageToggleTooltip,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
