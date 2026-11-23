import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOURCE-LEVEL session regression tier (renamed from
/// phase4_restart_bypass_regression_test.dart in Stage 3C, when the
/// phone-migration groups were removed with the phone flow).
///
/// Pins the structural guarantees behind restart, verification and logout:
/// - only an authenticated (verified, confirmed-profile) result ever
///   persists the local session, and pending verification always routes to
///   Verify Email;
/// - startup derives its destination from Firebase Auth + SessionStorage
///   via resolveStartupDestination (behavior covered in
///   startup_destination_test.dart);
/// - logout clears the session, resets the workout session and signs out.
String _initialCase(String routerSource) {
  final start = routerSource.indexOf('AppNavigator.initial:');
  final end = routerSource.indexOf('case AppNavigator.register:', start);
  expect(start, greaterThan(-1));
  expect(end, greaterThan(start));
  return routerSource.substring(start, end);
}

void main() {
  late String routerSource;
  late String homSource;

  setUpAll(() {
    routerSource = File(
      'lib/core/routes/app_router.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    homSource = File(
      'lib/features/views/hom.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
  });

  group('Stage 3B: a local session is persisted ONLY for an authenticated '
      '(verified) result, never before verification', () {
    // No "logged in" marker before verification completes, for every
    // email-first screen. Checked here structurally and in the widget
    // tests behaviorally.
    final emailScreens = {
      'login': 'lib/auth/presentation/view/loginview.dart',
      'reconciliation':
          'lib/auth/presentation/view/session_reconciliation_view.dart',
      'register': 'lib/auth/presentation/view/register_view.dart',
      'verifyEmail': 'lib/auth/presentation/view/verify_email_view.dart',
      'completeProfile':
          'lib/auth/presentation/view/complete_profile_view.dart',
    };

    for (final entry in emailScreens.entries) {
      test('${entry.key}: never writes SessionStorage itself, and only '
          'enters the app from an AuthSuccess branch', () {
        final source = File(
          entry.value,
        ).readAsStringSync().replaceAll('\r\n', '\n');
        expect(source.contains('persistLoggedInSession'), isFalse);
        expect(source.contains('sl<SessionStorage>()'), isFalse);
        expect(source.contains('AppNavigator.home'), isFalse);

        var from = 0;
        while (true) {
          final call = source.indexOf('AuthFlowNavigation.enterApp(', from);
          if (call == -1) break;
          final branch = source.lastIndexOf('if (state is ', call);
          expect(branch, greaterThan(-1));
          expect(
            source
                .substring(branch, call)
                .startsWith('if (state is AuthSuccess'),
            isTrue,
            reason: '${entry.key}: enterApp outside an AuthSuccess branch',
          );
          from = call + 1;
        }
      });
    }

    test('the single persistence point writes only after it is handed an '
        'authenticated user', () {
      final nav = File(
        'lib/auth/presentation/auth_flow_navigation.dart',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final enter = nav.indexOf('static Future<void> enterApp(');
      final persist = nav.indexOf('await persistAuthenticatedSession(user)');
      final home = nav.indexOf('AppNavigator.home', enter);
      expect(enter, greaterThan(-1));
      expect(persist, greaterThan(enter));
      expect(home, greaterThan(persist));
    });

    test('pending verification always routes to Verify Email, never Home', () {
      for (final path in [
        emailScreens['login']!,
        emailScreens['reconciliation']!,
        emailScreens['register']!,
      ]) {
        final source = File(path).readAsStringSync().replaceAll('\r\n', '\n');
        final start = source.indexOf('state is AuthEmailVerificationRequired');
        expect(start, greaterThan(-1), reason: path);
        final end = source.indexOf('} else if', start);
        final branch = source.substring(start, end);
        expect(branch.contains('toVerifyEmail('), isTrue, reason: path);
        expect(branch.contains('enterApp'), isFalse, reason: path);
      }
    });
  });

  group('E: the restart control flow cannot use the Hive Home fast-path '
      'for an unverified account', () {
    // The fast-path condition lives in the pure
    // resolveStartupDestination(), covered exhaustively by behavioral unit
    // tests in test/core/bootstrap/startup_destination_test.dart. Home
    // needs a matching marker (only written for an authenticated result,
    // see the group above) AND a verified email, so an unverified account
    // can never reach Home on restart. These source checks only pin that
    // AppRouter actually delegates to it.
    test("AppRouter's initial route derives its destination from "
        'resolveStartupDestination over Firebase Auth + SessionStorage', () {
      final initialCaseBody = _initialCase(routerSource);
      expect(initialCaseBody.contains('resolveStartupDestination('), isTrue);
      expect(initialCaseBody.contains('StartupAuthSnapshot.read('), isTrue);
      expect(initialCaseBody.contains('FirebaseAuth.instance'), isTrue);
      expect(initialCaseBody.contains('sl<SessionStorage>()'), isTrue);
    });

    test('StartupDestination.sessionCheck routes to '
        'SessionReconciliationView, and only .home routes to Home', () {
      final initialCaseBody = _initialCase(routerSource);
      final sessionCheck = initialCaseBody.substring(
        initialCaseBody.indexOf('case StartupDestination.sessionCheck:'),
        initialCaseBody.indexOf('case StartupDestination.login:'),
      );
      expect(sessionCheck.contains('SessionReconciliationView'), isTrue);
      expect(sessionCheck.contains('_homeWithProviders'), isFalse);
      final home = initialCaseBody.substring(
        initialCaseBody.indexOf('case StartupDestination.home:'),
        initialCaseBody.indexOf('case StartupDestination.sessionCheck:'),
      );
      expect(home.contains('_homeWithProviders'), isTrue);
    });
  });

  group('G: logout still clears the session and resets '
      'WorkoutSessionCubit', () {
    test("hom.dart's logout action calls SessionStorage.clearSession(), "
        'still resets the WorkoutSessionCubit singleton (Phase 21 fix — '
        'unchanged by this stage), and still calls '
        'FirebaseAuth.instance.signOut()', () {
      final logoutStart = homSource.indexOf('Future<void> _logout()');
      expect(logoutStart, greaterThan(-1));
      final onPressedStart = homSource.indexOf(
        'onPressed: () async {',
        logoutStart,
      );
      final dialogEnd = homSource.indexOf(
        'style: ElevatedButton.styleFrom(',
        onPressedStart,
      );
      final logoutAction = homSource.substring(onPressedStart, dialogEnd);

      expect(logoutAction.contains('sl<SessionStorage>()'), isTrue);
      expect(logoutAction.contains('clearSession()'), isTrue);
      // The raw 4-key Hive writes this replaced are gone from this
      // call site.
      expect(logoutAction.contains("authBox.put('isLoggedIn'"), isFalse);
      expect(logoutAction.contains("authBox.delete("), isFalse);

      expect(
        logoutAction.contains('sl<WorkoutSessionCubit>().reset()'),
        isTrue,
      );
      expect(logoutAction.contains('FirebaseAuth.instance.signOut()'), isTrue);

      // Ordering: session cleared before Firebase sign-out, matching
      // the pre-existing sequence (unchanged by this stage).
      final clearIndex = logoutAction.indexOf('clearSession()');
      final signOutIndex = logoutAction.indexOf(
        'FirebaseAuth.instance.signOut()',
      );
      expect(clearIndex, lessThan(signOutIndex));
    });
  });

  // Device crash (2026-11): signing out rebuilt Hom (its auth listener and
  // the per-user ThemeCubit) after logout had nulled/closed its exercise
  // box but before navigating away, so `exerciseBox!` threw in
  // _buildVolumePanel and the framework's element-tree assertion followed.
  group('H: logout never rebuilds per-user UI over closed boxes', () {
    late String logoutAction;

    setUp(() {
      final logoutStart = homSource.indexOf('Future<void> _logout()');
      final onPressedStart = homSource.indexOf('onPressed: () async {', logoutStart);
      final actionEnd = homSource.indexOf('style: ElevatedButton.styleFrom(', onPressedStart);
      logoutAction = homSource.substring(onPressedStart, actionEnd);
    });

    test('Home switches to its placeholder BEFORE boxes close and before sign-out', () {
      final flagIndex = logoutAction.indexOf('setState(() => _signingOut = true)');
      expect(flagIndex, greaterThan(-1));
      for (final step in [
        'closeForUser(outgoingUid)',
        'exerciseBox = null',
        'clearSession()',
        'FirebaseAuth.instance.signOut()',
        'pushNamedAndRemoveUntil(',
      ]) {
        final stepIndex = logoutAction.indexOf(step);
        expect(stepIndex, greaterThan(flagIndex), reason: '$step must come after the flag');
      }
    });

    test('build shows only the placeholder while signing out or without a box', () {
      final buildStart = homSource.indexOf('Widget build(BuildContext context) {');
      final guard = homSource.indexOf('if (_isLoading || _signingOut || exerciseBox == null) {', buildStart);
      final dataUi = homSource.indexOf('HomeDashboard(', buildStart);
      final volume = homSource.indexOf('_buildVolumePanel()', buildStart);
      expect(guard, greaterThan(buildStart));
      expect(guard, lessThan(dataUi));
      expect(guard, lessThan(volume));
    });

    test('a failed logout reopens the boxes before per-user UI returns', () {
      expect(logoutAction.contains('unawaited(_restoreAfterFailedLogout())'), isTrue);
      final restoreStart = homSource.indexOf('Future<void> _restoreAfterFailedLogout() async {');
      final restoreEnd = homSource.indexOf('Future<void> _openPersonalHub()', restoreStart);
      final restore = homSource.substring(restoreStart, restoreEnd);
      final reopen = restore.indexOf('await _initUserBox()');
      final unflag = restore.indexOf('setState(() => _signingOut = false)');
      expect(reopen, greaterThan(-1));
      expect(unflag, greaterThan(reopen));
    });
  });

}
