import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OtpView extends StatefulWidget {
  final String phoneNumber;
  final String password;
  final String verificationId;
  final String name; // 🔥 ضفنا الاسم هنا

  const OtpView({
    super.key,
    required this.phoneNumber,
    required this.password,
    required this.verificationId,
    required this.name, // إجباري
  });

  @override
  State<OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<OtpView> {
  final TextEditingController _otpController = TextEditingController();
  late final TextEditingController _passwordController = TextEditingController(
    text: widget.password,
  );
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
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
          listener: (context, state) async {
            if (state is AuthSuccess) {
              // Phase 3: registerWithOtp only reaches AuthSuccess after
              // phone auth + password link + Firestore profile write all
              // succeeded — safe to mark the local session complete now.
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
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back_ios_new),
                                  color: const Color(0xff2f80ed),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: state is AuthLoading
                                      ? null
                                      : () => context
                                            .read<AuthCubit>()
                                            .requestOtp(widget.phoneNumber),
                                  icon: const Icon(Icons.refresh),
                                  color: const Color(0xff2f80ed),
                                  tooltip: l10n.resendCodeTooltip,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.verifyPhoneTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xff202936),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.enterCodeSentTo(widget.phoneNumber),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xff7d8792)),
                            ),
                            const SizedBox(height: 24),
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
                              controller: _passwordController,
                              obscureText: _isPasswordObscured,
                              decoration: InputDecoration(
                                hintText: l10n.passwordHint,
                                prefixIcon: const Icon(
                                  Icons.lock,
                                  color: Color(0xff2f80ed),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordObscured
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordObscured =
                                          !_isPasswordObscured;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 15,
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
                                  ? l10n.passwordTooShort
                                  : null,
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
                                              .requestOtp(widget.phoneNumber),
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
                                            if (_formKey.currentState!
                                                .validate()) {
                                              context.read<AuthCubit>().registerWithOtp(
                                                verificationId:
                                                    widget.verificationId,
                                                smsCode: _otpController.text
                                                    .trim(),
                                                name:
                                                    widget.name, // مررنا الاسم
                                                phone: widget
                                                    .phoneNumber, // مررنا الرقم
                                                // Editable so a weak-password
                                                // rejection can be retried
                                                // with a stronger one against
                                                // the SAME phone-authenticated
                                                // session, without leaving
                                                // this screen or re-verifying
                                                // the OTP.
                                                password: _passwordController
                                                    .text
                                                    .trim(),
                                              );
                                            }
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
                                            l10n.verifyButton,
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
