import 'package:ae_coaching/auth/domain/entities/auth_session_inspection.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CompleteRegistrationArgs {
  final RegistrationRecoveryStep step;
  final String phone;
  const CompleteRegistrationArgs({required this.step, required this.phone});
}

/// Cross-restart resume screen for a Phase 3 OTP registration that was
/// interrupted (app killed, network failure, etc.) after the phone
/// number was already verified. Never re-verifies the phone and never
/// creates a second Firebase user — it always operates on the SAME
/// already-authenticated [FirebaseAuth.currentUser].
///
/// Name/password only ever existed in memory before the interruption,
/// so this screen asks for exactly what's still missing: a password
/// (if only the phone provider is linked) or a name (if both providers
/// are linked but no Firestore profile exists yet).
class CompleteRegistrationView extends StatefulWidget {
  final RegistrationRecoveryStep step;
  final String phone;

  const CompleteRegistrationView({
    super.key,
    required this.step,
    required this.phone,
  });

  @override
  State<CompleteRegistrationView> createState() =>
      _CompleteRegistrationViewState();
}

class _CompleteRegistrationViewState extends State<CompleteRegistrationView> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isPasswordObscured = true;
  late RegistrationRecoveryStep _step = widget.step;

  @override
  void dispose() {
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _cancelAndSignOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppNavigator.login,
        (route) => false,
      );
    }
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
    final isPasswordStep = _step == RegistrationRecoveryStep.needsPassword;

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
            } else if (state is AuthPartialRegistration) {
              // Password just linked successfully — advance in place to
              // the profile step without leaving this screen.
              setState(() => _step = state.step);
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
                              isPasswordStep
                                  ? l10n.completeRegistrationSetPasswordTitle
                                  : l10n.completeRegistrationFinishProfileTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xff202936),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isPasswordStep
                                  ? l10n.completeRegistrationSetPasswordSubtitle(
                                      widget.phone,
                                    )
                                  : l10n.completeRegistrationFinishProfileSubtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xff7d8792)),
                            ),
                            const SizedBox(height: 22),
                            if (isPasswordStep)
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
                              )
                            else
                              TextFormField(
                                controller: _nameController,
                                decoration: _fieldDecoration(
                                  hint: l10n.fullNameHint,
                                  icon: Icons.person,
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? l10n.fullNameRequired
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
                                        if (isPasswordStep) {
                                          context
                                              .read<AuthCubit>()
                                              .linkPasswordToCurrentUser(
                                                phone: widget.phone,
                                                password: _passwordController
                                                    .text
                                                    .trim(),
                                              );
                                        } else {
                                          context
                                              .read<AuthCubit>()
                                              .completeProfileForCurrentUser(
                                                name: _nameController.text
                                                    .trim(),
                                                phone: widget.phone,
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
                                        l10n.save,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: state is AuthLoading
                                  ? null
                                  : _cancelAndSignOut,
                              child: Text(
                                l10n.completeRegistrationCancelAndSignOut,
                                style: const TextStyle(
                                  color: Color(0xff7d8792),
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
