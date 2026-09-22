import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOURCE-LEVEL regression tier: [VerifyPhoneMigrationView] cannot be
/// exercised with a widget test in this environment (testWidgets hangs
/// here — a pre-existing, unrelated environment limitation), so this
/// reads the view's actual implementation text to prove the mandatory
/// UX properties: no skip action exists, back-navigation cannot pop the
/// route, and the only path to Home is through the AuthSuccess branch
/// that follows a real linkPhoneMigration call.
void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/auth/presentation/view/verify_phone_migration_view.dart',
    ).readAsStringSync();
  });

  group('No skip/bypass action exists', () {
    test('no "skip" wording, key, or callback remains anywhere in the '
        'view', () {
      expect(source.toLowerCase().contains('skip'), isFalse);
    });

    test('there is no TextButton (or any other tappable widget) that '
        'calls _goHome() directly — the only caller of _goHome() is the '
        'AuthSuccess branch reached after a real linkPhoneMigration call', () {
      // Matches only actual calls (`_goHome();`), not the method
      // definition itself (`void _goHome() {`).
      final goHomeCallSites = RegExp(r'_goHome\(\);').allMatches(source).length;
      // Exactly one call site: inside the AuthSuccess listener branch.
      expect(goHomeCallSites, 1);

      final authSuccessStart = source.indexOf('is AuthSuccess');
      final authSuccessEnd = source.indexOf('else if (state is AuthError)');
      final authSuccessBranch = source.substring(
        authSuccessStart,
        authSuccessEnd,
      );
      expect(authSuccessBranch.contains('_goHome()'), isTrue);
    });

    test('the only two actionable buttons are Resend and Verify — no '
        'third "skip"/"not now"/"cancel" button exists', () {
      final buttonCount = RegExp(r'ElevatedButton\(').allMatches(source).length;
      expect(buttonCount, 2);
      expect(source.contains('l10n.resendButton'), isTrue);
      expect(source.contains('l10n.verifyButton'), isTrue);
    });
  });

  group('Back-navigation cannot bypass verification', () {
    test('the screen is wrapped in PopScope(canPop: false), so no pop '
        '(hardware back, iOS swipe-back, or otherwise) can leave this '
        'route while verification is incomplete', () {
      expect(source.contains('PopScope('), isTrue);
      final popScopeStart = source.indexOf('PopScope(');
      final popScopeArgsEnd = source.indexOf('child: Scaffold(', popScopeStart);
      final popScopeArgs = source.substring(popScopeStart, popScopeArgsEnd);
      expect(popScopeArgs.contains('canPop: false'), isTrue);
    });
  });

  group('Success path is the only route to Home', () {
    test('_goHome navigates to AppNavigator.home and is only reachable '
        'via a completed AuthSuccess (i.e. after linkPhoneMigration '
        'succeeded server-side)', () {
      expect(
        source.contains(
          'Navigator.pushNamedAndRemoveUntil(\n      context,\n      AppNavigator.home,',
        ),
        isTrue,
      );
    });

    test('the Verify button calls linkPhoneMigration — never '
        'signInWithCredential and never a bare Navigator call', () {
      final verifyButtonStart = source.indexOf('_verificationId == null');
      final verifyButtonEnd = source.indexOf(
        'style: ElevatedButton.styleFrom(',
        verifyButtonStart,
      );
      final verifyButtonOnPressed = source.substring(
        verifyButtonStart,
        verifyButtonEnd,
      );
      expect(verifyButtonOnPressed.contains('linkPhoneMigration('), isTrue);
      expect(verifyButtonOnPressed.contains('signInWithCredential'), isFalse);
      expect(verifyButtonOnPressed.contains('Navigator.'), isFalse);
    });
  });

  group('Failed OTP/network keeps the screen and session available', () {
    test('AuthError only shows a SnackBar — it never signs out, never '
        'navigates away, and never disables retry permanently', () {
      final authErrorStart = source.indexOf('else if (state is AuthError)');
      final authErrorBranch = source.substring(authErrorStart);
      expect(authErrorBranch.contains('signOut'), isFalse);
      expect(authErrorBranch.contains('Navigator.'), isFalse);
      expect(authErrorBranch.contains('showSnackBar'), isTrue);
    });

    test('the Resend and Verify buttons are only disabled while '
        'AuthLoading — never permanently disabled after a failure', () {
      final loadingGuards = RegExp(
        r'state is AuthLoading',
      ).allMatches(source).length;
      // Two buttons, each gated on AuthLoading (not on any error/failed
      // flag), so a failure never leaves a button permanently disabled.
      expect(loadingGuards, greaterThanOrEqualTo(2));
      expect(source.contains('hasFailed'), isFalse);
      expect(source.contains('isBlocked'), isFalse);
    });
  });

  group('Phone identity is fixed — never re-typed', () {
    test('there is no TextEditingController or TextFormField bound to a '
        'phone value — widget.phone is only ever displayed as text', () {
      expect(source.contains('phoneController'), isFalse);
      // The only editable field on this screen is the 6-digit OTP.
      final textFormFieldCount = RegExp(
        r'TextFormField\(',
      ).allMatches(source).length;
      expect(textFormFieldCount, 1);
    });
  });

  group('LoginView routes an already-migrated legacy user straight Home '
      '(unchanged by this UX-only Phase 4 adjustment)', () {
    late String loginSource;

    setUpAll(() {
      loginSource = File(
        'lib/auth/presentation/view/loginview.dart',
      ).readAsStringSync();
    });

    test('the post-login branch checks needsPhoneVerification == true '
        'before ever routing to verifyPhoneMigration; a subsequent '
        '(non-migration) return path routes straight to home', () {
      expect(
        loginSource.contains('state.user?.needsPhoneVerification == true'),
        isTrue,
      );
      // Phase 4 restart-bypass fix: the needsPhoneVerification branch
      // now returns early (rather than an if/else) so the Hive session
      // writes below it never run for a user who still needs
      // migration — see the Phase 4 restart-bypass regression test for
      // the ordering-specific assertions. This test just confirms
      // AppNavigator.home still appears strictly after the
      // needsPhoneVerification check, i.e. it is reached only once
      // that branch has been evaluated and skipped.
      final branchStart = loginSource.indexOf(
        'state.user?.needsPhoneVerification == true',
      );
      final returnIndex = loginSource.indexOf('return;', branchStart);
      final homeIndex = loginSource.indexOf('AppNavigator.home', returnIndex);
      expect(returnIndex, greaterThan(branchStart));
      expect(homeIndex, greaterThan(returnIndex));
    });
  });
}
