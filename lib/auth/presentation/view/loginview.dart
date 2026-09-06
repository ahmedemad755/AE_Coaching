import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:ae_coaching/core/localization/auth_message_localizer.dart';
import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController = TextEditingController(); // بيستقبل رقم الهاتف
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isPasswordObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🔥 ضفنا دالة التنسيق هنا عشان نوحد شكل الرقم قبل ما نبحث عنه في الداتا بيز
  String formatPhoneNumber(String phone) {
    String formatted = phone.trim();
    if (formatted.startsWith('01')) {
      formatted = '+20${formatted.substring(1)}';
    } else if (!formatted.startsWith('+')) {
      formatted = '+20$formatted';
    }
    return formatted;
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
        child: Stack(
          children: [
            BlocConsumer<AuthCubit, AuthState>(
              listener: (context, state) async {
                if (state is AuthSuccess) {
                  final authBox = Hive.box('authBox');
                  await authBox.put('isLoggedIn', true);

                  if (state.user != null) {
                    await authBox.put('currentUserUid', state.user!.uid);
                    await authBox.put('currentUserName', state.user!.name);
                    await authBox.put('currentUserPhone', state.user!.phoneNumber);
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(localizeAuthMessage(l10n, state.message))),
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
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
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
                                  style: const TextStyle(
                                    color: Color(0xff2f80ed),
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.appBrandFull,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xff202936),
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.loginSubtitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xff7d8792)),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.phone, // خليناها أرقام عشان تجربة المستخدم
                                  decoration: _fieldDecoration(
                                    hint: l10n.phoneNumberHint,
                                    icon: Icons.phone,
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty ? l10n.phoneNumberRequired : null,
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
                                      value == null || value.isEmpty ? l10n.passwordRequired : null,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: state is AuthLoading
                                        ? null
                                        : () {
                                            if (_formKey.currentState!.validate()) {
                                              // 🔥 هنا بنستخدم دالة الـ Format قبل ما نبعت الرقم للكيوبيت
                                              String formattedPhone = formatPhoneNumber(_emailController.text);

                                              context.read<AuthCubit>().login(
                                                    formattedPhone,
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
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            l10n.loginButton,
                                            style: const TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {},
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xff2f80ed),
                                          side: const BorderSide(color: Color(0xff2f80ed)),
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
                                        onPressed: () {
                                          Navigator.pushNamed(context, AppNavigator.register);
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: const Color(0xffeef2f5),
                                          foregroundColor: const Color(0xff2f80ed),
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
                    color: const Color(0xff2f80ed),
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
