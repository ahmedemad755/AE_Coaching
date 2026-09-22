import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/auth/presentation/view/reset_password_view.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/utils/phone_normalizer.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Phase 5 — entry point for signed-out Forgot Password. Collects the
/// phone number only (no password re-entry — the user doesn't remember
/// it, that's the whole point) and sends an OTP. Identity is fully
/// resolved later, in [ResetPasswordView], via
/// AuthRemoteDataSourceImpl.verifyPasswordResetOtpAndUpdatePassword,
/// which never creates a lasting new Firebase user.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xff2f80ed)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff2f80ed)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff2f80ed), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffdbe9f7), Color(0xff8fb6e6)],
          ),
        ),
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthPasswordResetOtpSent) {
              // Replace (not push) so Back from ResetPasswordView goes
              // straight to Login rather than back to this now-stale
              // phone-entry step, and resubmitting the phone here never
              // stacks up more than one ResetPasswordView instance.
              Navigator.pushReplacementNamed(
                context,
                AppNavigator.resetPassword,
                arguments: ResetPasswordArgs(
                  phone: state.phone,
                  challengeId: state.challengeId,
                ),
              );
            } else if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
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
                        color: Colors.white.withValues(alpha: 0.93),
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
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: IconButton(
                                onPressed: state is AuthLoading
                                    ? null
                                    : () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back_ios_new),
                                color: const Color(0xff2f80ed),
                              ),
                            ),
                            Text(
                              l10n.forgotPasswordTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xff202936),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.forgotPasswordSubtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xff7d8792)),
                            ),
                            const SizedBox(height: 22),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _fieldDecoration(
                                hint: l10n.phoneNumberFieldHint,
                                icon: Icons.phone,
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? l10n.phoneNumberRequiredRegister
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: state is AuthLoading
                                    ? null
                                    : () {
                                        if (!_formKey.currentState!
                                            .validate()) {
                                          return;
                                        }
                                        try {
                                          final normalizedPhone =
                                              EgyptianPhoneNormalizer.normalize(
                                                _phoneController.text,
                                              );
                                          context
                                              .read<AuthCubit>()
                                              .requestPasswordResetOtp(
                                                normalizedPhone,
                                              );
                                        } on PhoneNormalizationException catch (
                                          e
                                        ) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.message),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff2f80ed),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 8,
                                  shadowColor: const Color(
                                    0xff2f80ed,
                                  ).withValues(alpha: 0.35),
                                ),
                                child: state is AuthLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        l10n.sendCodeButton,
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
