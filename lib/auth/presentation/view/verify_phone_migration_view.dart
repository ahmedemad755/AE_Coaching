import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VerifyPhoneMigrationArgs {
  final String uid;
  final String name;
  final String phone;
  const VerifyPhoneMigrationArgs({
    required this.uid,
    required this.name,
    required this.phone,
  });
}

/// Phase 4: shown only to an already-authenticated legacy user (login
/// already succeeded, Hive session is already valid) who has no phone
/// provider linked yet. The phone is fixed to the account's own
/// canonical number — never editable here.
///
/// Phone verification is now REQUIRED before Home: there is no way to
/// bypass or dismiss this step, and back-navigation cannot pop this
/// route (see [PopScope] below) — the only way forward is a successful
/// [linkWithCredential].
/// A wrong/expired OTP or a network failure never signs the user out —
/// the authenticated legacy session stays intact and resend/retry
/// remain available indefinitely.
class VerifyPhoneMigrationView extends StatefulWidget {
  final String uid;
  final String name;
  final String phone;

  const VerifyPhoneMigrationView({
    super.key,
    required this.uid,
    required this.name,
    required this.phone,
  });

  @override
  State<VerifyPhoneMigrationView> createState() =>
      _VerifyPhoneMigrationViewState();
}

class _VerifyPhoneMigrationViewState extends State<VerifyPhoneMigrationView> {
  final TextEditingController _otpController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthCubit>().requestPhoneMigrationOtp(widget.phone);
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppNavigator.home,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Phone verification is required before Home: this route can never
    // be popped (hardware back button, iOS swipe-back gesture, or any
    // other pop request), so there is no way to reveal whatever was
    // underneath without a successful migration. In practice nothing is
    // underneath anyway — LoginView reaches this screen via
    // pushNamedAndRemoveUntil, which clears the stack — but canPop:
    // false makes that a guarantee rather than an incidental one.
    return PopScope(
      canPop: false,
      child: Scaffold(
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
              if (state is AuthOtpSent) {
                setState(() => _verificationId = state.verificationId);
              } else if (state is AuthSuccess) {
                // Same UID/name/phone as before migration — this write is
                // idempotent, not a new session.
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
                _goHome();
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
                                l10n.verifyPhoneMigrationTitle,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xff202936),
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.verifyPhoneMigrationSubtitle(widget.phone),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xff7d8792),
                                ),
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
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: state is AuthLoading
                                          ? null
                                          : () => context
                                                .read<AuthCubit>()
                                                .requestPhoneMigrationOtp(
                                                  widget.phone,
                                                ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xff2f80ed,
                                        ),
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size.fromHeight(50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                      onPressed:
                                          state is AuthLoading ||
                                              _verificationId == null
                                          ? null
                                          : () {
                                              if (!_formKey.currentState!
                                                  .validate()) {
                                                return;
                                              }
                                              context
                                                  .read<AuthCubit>()
                                                  .linkPhoneMigration(
                                                    verificationId:
                                                        _verificationId!,
                                                    smsCode: _otpController.text
                                                        .trim(),
                                                    uid: widget.uid,
                                                    name: widget.name,
                                                    phone: widget.phone,
                                                  );
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(
                                          0xff2f80ed,
                                        ),
                                        minimumSize: const Size.fromHeight(50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
      ),
    );
  }
}
