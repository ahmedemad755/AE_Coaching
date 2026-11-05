import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/auth_screen_theme.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/core/utils/phone_normalizer.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isPasswordObscured = true; // متغير إخفاء/إظهار الباسورد

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    String hint,
    IconData icon, {
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
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) async {
            if (state is AuthSuccess) {
              if (state.user != null) {
                await sl<SessionStorage>().persistLoggedInSession(
                  uid: state.user!.uid,
                  name: state.user!.name,
                  phone: state.user!.phoneNumber,
                );
              }

              if (!context.mounted) return;
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
              // Temporarily disabled while testing without SMS OTP.
              // } else if (state is AuthOtpSent) {
              //   Navigator.pushNamed(
              //     context,
              //     AppNavigator.otp,
              //     arguments: {
              //       'phone': state.phone,
              //       'password': _passwordController.text.trim(),
              //       'name': _nameController.text.trim(),
              //       'verificationId': state.verificationId,
              //     },
              //   );
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
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back_ios_new),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              l10n.createAccountTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.startJourneySubtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 22),
                            TextFormField(
                              controller: _nameController,
                              decoration: _fieldDecoration(
                                l10n.fullNameHint,
                                Icons.person,
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? l10n.fullNameRequired
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _fieldDecoration(
                                l10n.phoneNumberFieldHint,
                                Icons.phone,
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? l10n.phoneNumberRequiredRegister
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _isPasswordObscured,
                              decoration: _fieldDecoration(
                                l10n.passwordHint,
                                Icons.lock,
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
                                  value == null || value.length < 6
                                  ? l10n.passwordTooShort
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: state is AuthLoading
                                    ? null
                                    : () {
                                        if (_formKey.currentState!.validate()) {
                                          try {
                                            final normalizedPhone =
                                                EgyptianPhoneNormalizer.normalize(
                                                  _phoneController.text,
                                                );

                                            // OTP registration is temporarily
                                            // bypassed while SMS billing is
                                            // being configured.
                                            // — password/name are held
                                            // Previously, these values were
                                            // passed to OtpView after the
                                            // OTP request succeeded.
                                            context
                                                .read<AuthCubit>()
                                                .registerWithPhonePassword(
                                                  name: _nameController.text
                                                      .trim(),
                                                  phone: normalizedPhone,
                                                  password: _passwordController
                                                      .text
                                                      .trim(),
                                                );
                                            // Previous OTP flow:
                                            // context
                                            //     .read<AuthCubit>()
                                            //     .requestOtp(normalizedPhone);
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
                                  shadowColor: const Color(
                                    0xff2f80ed,
                                  ).withValues(alpha: 0.35),
                                ),
                                child: state is AuthLoading
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
            );
          },
        ),
      ),
    );
  }
}
