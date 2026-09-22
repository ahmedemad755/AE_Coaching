import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ResetPasswordArgs {
  final String phone;
  final String challengeId;
  const ResetPasswordArgs({required this.phone, required this.challengeId});
}

/// Phase 5 — OTP entry + new password for signed-out Forgot Password.
///
/// The actual account identity is resolved entirely inside
/// AuthRemoteDataSourceImpl.verifyPasswordResetOtpAndUpdatePassword:
/// this screen has no knowledge of, and makes no assumption about,
/// whether an account exists for the phone — it just forwards the OTP
/// credential and the chosen new password. A "no account found" result
/// is a normal, expected AuthError here, not a bug.
///
/// On success the flow always ends signed out (see the data source),
/// so this screen navigates to Login, never Home — the user logs in
/// fresh with their new password.
class ResetPasswordView extends StatefulWidget {
  final String phone;
  final String challengeId;

  const ResetPasswordView({
    super.key,
    required this.phone,
    required this.challengeId,
  });

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late String _challengeId = widget.challengeId;

  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xff2f80ed)),
      suffixIcon: suffixIcon,
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
              // Resend succeeded — a NEW challenge replaces the old
              // one. The old challengeId is never submitted again.
              setState(() => _challengeId = state.challengeId);
            } else if (state is AuthPasswordResetSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(localizeAuthMessage(l10n, state.message)),
                ),
              );
              // Always signed out by this point (the backend never
              // authenticates the caller) — the user logs in fresh
              // with the new password. Never Home, never a locally
              // persisted logged-in session.
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppNavigator.login,
                (route) => false,
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
                            Text(
                              l10n.resetPasswordTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xff202936),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.resetPasswordSubtitle(widget.phone),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xff7d8792)),
                            ),
                            const SizedBox(height: 22),
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 6,
                              style: const TextStyle(
                                color: Color(0xff202936),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: InputDecoration(
                                hintText: '000000',
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 17,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xff2f80ed),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xff2f80ed),
                                    width: 1.6,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.length < 6
                                  ? l10n.enterSixDigitCodeValidator
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _isPasswordObscured,
                              decoration: _fieldDecoration(
                                hint: l10n.passwordHint,
                                icon: Icons.lock,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordObscured
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => setState(
                                    () => _isPasswordObscured =
                                        !_isPasswordObscured,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.length < 6
                                  ? l10n.passwordTooShort
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _isConfirmObscured,
                              decoration: _fieldDecoration(
                                hint: l10n.confirmPasswordHint,
                                icon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmObscured
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => setState(
                                    () => _isConfirmObscured =
                                        !_isConfirmObscured,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.confirmPasswordRequired;
                                }
                                if (value != _newPasswordController.text) {
                                  return l10n.passwordsDoNotMatch;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: state is AuthLoading
                                        ? null
                                        : () => context
                                              .read<AuthCubit>()
                                              .requestPasswordResetOtp(
                                                widget.phone,
                                              ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xff2f80ed),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      l10n.resendButton,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: state is AuthLoading
                                        ? null
                                        : () {
                                            if (!_formKey.currentState!
                                                .validate()) {
                                              return;
                                            }
                                            context
                                                .read<AuthCubit>()
                                                .resetPassword(
                                                  challengeId: _challengeId,
                                                  smsCode: _otpController.text
                                                      .trim(),
                                                  newPassword:
                                                      _newPasswordController
                                                          .text
                                                          .trim(),
                                                );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xff2f80ed),
                                      minimumSize: const Size.fromHeight(50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: state is AuthLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                            ),
                                          )
                                        : Text(
                                            l10n.resetPasswordButton,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
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
      ),
    );
  }
}
