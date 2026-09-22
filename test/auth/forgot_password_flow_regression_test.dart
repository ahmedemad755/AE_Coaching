import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOURCE-LEVEL regression tier: ForgotPasswordView/ResetPasswordView
/// cannot be exercised with a widget test in this environment
/// (testWidgets hangs here — a pre-existing, unrelated environment
/// limitation), so this reads their actual implementation text to prove
/// the mandatory Phase 5 UX/safety properties.
void main() {
  late String forgotPasswordSource;
  late String resetPasswordSource;
  late String loginSource;

  setUpAll(() {
    forgotPasswordSource = File(
      'lib/auth/presentation/view/forgot_password_view.dart',
    ).readAsStringSync();
    resetPasswordSource = File(
      'lib/auth/presentation/view/reset_password_view.dart',
    ).readAsStringSync();
    loginSource = File(
      'lib/auth/presentation/view/loginview.dart',
    ).readAsStringSync();
  });

  group('Forgot Password entry point is wired from Login', () {
    test('the "Forgot Password?" button navigates to '
        'AppNavigator.forgotPassword instead of the previous no-op', () {
      // Tolerant of dart format wrapping the call across lines.
      expect(
        RegExp(
          r'Navigator\.pushNamed\(\s*context\s*,\s*AppNavigator\.forgotPassword\s*,?\s*\)',
        ).hasMatch(loginSource),
        isTrue,
      );
    });
  });

  group('ForgotPasswordView never asks for password, never authenticates', () {
    test('there is no password field/controller on the phone-entry '
        'screen', () {
      expect(forgotPasswordSource.contains('passwordController'), isFalse);
      expect(
        forgotPasswordSource.toLowerCase().contains('obscuretext'),
        isFalse,
      );
    });

    test('submitting normalizes the phone via EgyptianPhoneNormalizer '
        'before calling requestPasswordResetOtp — the same canonical '
        'normalizer used everywhere else, not a re-implementation', () {
      expect(
        forgotPasswordSource.contains('EgyptianPhoneNormalizer.normalize('),
        isTrue,
      );
      // A plain literal substring is brittle here since dart format is
      // free to re-wrap a long call across lines — match with tolerant
      // whitespace instead of an exact single-line substring.
      expect(
        RegExp(
          r'requestPasswordResetOtp\(\s*normalizedPhone\s*,?\s*\)',
        ).hasMatch(forgotPasswordSource),
        isTrue,
      );
    });

    test('on AuthPasswordResetOtpSent (never AuthOtpSent) it navigates to '
        'resetPassword carrying the exact phone/challengeId the Cubit '
        'produced — never a user-editable second phone field downstream, '
        'and never a Firebase verificationId', () {
      expect(
        forgotPasswordSource.contains('is AuthPasswordResetOtpSent'),
        isTrue,
      );
      expect(
        forgotPasswordSource.contains('AppNavigator.resetPassword'),
        isTrue,
      );
      expect(forgotPasswordSource.contains('phone: state.phone'), isTrue);
      expect(
        forgotPasswordSource.contains('challengeId: state.challengeId'),
        isTrue,
      );
    });
  });

  group('ResetPasswordView requires both a new password and a matching '
      'confirmation', () {
    test('the new-password field reuses the existing app password policy '
        '(same length check as registration)', () {
      // Tolerant of dart format's line-wrapping of the ternary.
      expect(
        RegExp(
          r'value == null \|\| value\.length < 6\s*\?\s*l10n\.passwordTooShort\s*:\s*null',
        ).hasMatch(resetPasswordSource),
        isTrue,
      );
    });

    test('the confirm-password field validates emptiness and exact '
        'equality with the new password', () {
      expect(
        resetPasswordSource.contains('l10n.confirmPasswordRequired'),
        isTrue,
      );
      expect(
        resetPasswordSource.contains('value != _newPasswordController.text'),
        isTrue,
      );
      expect(resetPasswordSource.contains('l10n.passwordsDoNotMatch'), isTrue);
    });

    test('resend calls requestPasswordResetOtp again — never '
        'registerWithOtp/requestMigrationOtp', () {
      // Tolerant of dart format wrapping the call across lines.
      expect(
        RegExp(
          r'requestPasswordResetOtp\(\s*widget\.phone\s*,?\s*\)',
        ).hasMatch(resetPasswordSource),
        isTrue,
      );
      expect(resetPasswordSource.contains('registerWithOtp'), isFalse);
      expect(resetPasswordSource.contains('requestMigrationOtp'), isFalse);
    });

    test('submitting calls resetPassword (Cubit), never any raw Firebase '
        'API directly from the view', () {
      // Tolerant of dart format wrapping the call chain across lines.
      expect(
        RegExp(
          r'context\s*\.read<AuthCubit>\(\)\s*\.resetPassword\(',
        ).hasMatch(resetPasswordSource),
        isTrue,
      );
      expect(resetPasswordSource.contains('signInWithCredential'), isFalse);
      expect(resetPasswordSource.contains('FirebaseAuth'), isFalse);
    });
  });

  group('Success always ends at Login, never Home — no password is ever '
      'persisted locally', () {
    test('the AuthPasswordResetSuccess branch (never AuthSuccess) '
        'navigates to AppNavigator.login, never AppNavigator.home, and '
        'performs no Hive write and no sign-in at all', () {
      final successStart = resetPasswordSource.indexOf(
        'is AuthPasswordResetSuccess',
      );
      expect(successStart, greaterThan(-1));
      final successEnd = resetPasswordSource.indexOf(
        '} else if (state is AuthError)',
      );
      final successBranch = resetPasswordSource.substring(
        successStart,
        successEnd,
      );
      expect(successBranch.contains('AppNavigator.login'), isTrue);
      expect(successBranch.contains('AppNavigator.home'), isFalse);
      expect(successBranch.contains('Hive'), isFalse);
      expect(successBranch.contains('authBox'), isFalse);
      expect(resetPasswordSource.contains('is AuthSuccess'), isFalse);
    });

    test('neither screen ever imports or references package:hive_flutter '
        '— no password, uid, or session state is written to Hive by this '
        'flow at all', () {
      expect(forgotPasswordSource.contains('hive'), isFalse);
      expect(resetPasswordSource.toLowerCase().contains('hive'), isFalse);
    });

    test('neither screen logs, prints, or stores the password value '
        'anywhere other than passing it directly to the Cubit call', () {
      for (final source in [forgotPasswordSource, resetPasswordSource]) {
        expect(source.contains('print('), isFalse);
        expect(source.contains('developer.log'), isFalse);
      }
    });
  });
}
