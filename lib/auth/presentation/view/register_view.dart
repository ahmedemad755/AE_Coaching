import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

  // دالة لتعديل رقم الهاتف بإضافة كود الدولة تلقائياً
  String formatPhoneNumber(String phone) {
    String formatted = phone.trim();
    if (formatted.startsWith('01')) {
      formatted = '+20${formatted.substring(1)}';
    } else if (!formatted.startsWith('+')) {
      formatted = '+20$formatted';
    }
    return formatted;
  }

  InputDecoration _fieldDecoration(String hint, IconData icon, {Widget? suffixIcon}) {
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
          listener: (context, state) async {
            if (state is AuthSuccess) {
              final authBox = Hive.box('authBox');
              await authBox.put('isLoggedIn', true);

              if (state.user != null) {
                await authBox.put('currentUserUid', state.user!.uid);
                await authBox.put('currentUserName', state.user!.name);
                await authBox.put('currentUserPhone', state.user!.phoneNumber);
              }

              if (!mounted) return;
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
            } else if (state is AuthOtpSent) {
              Navigator.pushNamed(
                context,
                AppNavigator.otp,
                arguments: {
                  'phone': formatPhoneNumber(_phoneController.text),
                  'password': _passwordController.text.trim(),
                  'name': _nameController.text.trim(),
                  'verificationId': state.verificationId,
                },
              );
            } else if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.red),
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
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back_ios_new),
                                color: const Color(0xff2f80ed),
                              ),
                            ),
                            Text(
                              l10n.createAccountTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xff202936),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.startJourneySubtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xff7d8792)),
                            ),
                            const SizedBox(height: 22),
                            TextFormField(
                              controller: _nameController,
                              decoration: _fieldDecoration(l10n.fullNameHint, Icons.person),
                              validator: (value) =>
                                  value == null || value.isEmpty ? l10n.fullNameRequired : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _fieldDecoration(l10n.phoneNumberFieldHint, Icons.phone),
                              validator: (value) =>
                                  value == null || value.isEmpty ? l10n.phoneNumberRequiredRegister : null,
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
                                    _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordObscured = !_isPasswordObscured;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.length < 6 ? l10n.passwordTooShort : null,
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: state is AuthLoading
                                    ? null
                                    : () {
                                        if (_formKey.currentState!.validate()) {
                                          context
                                              .read<AuthCubit>()
                                              .registerWithPhonePassword(
                                                name: _nameController.text.trim(),
                                                phone: formatPhoneNumber(
                                                  _phoneController.text,
                                                ),
                                                password:
                                                    _passwordController.text.trim(),
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
                                  shadowColor: const Color(0xff2f80ed).withValues(alpha: 0.35),
                                ),
                                child: state is AuthLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.4,
                                        ),
                                      )
                                    : Text(
                                        l10n.createAccountButton,
                                        style: const TextStyle(fontWeight: FontWeight.w800),
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
