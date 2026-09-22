import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PHASE 4 RESTART-BYPASS FIX — SOURCE-LEVEL REGRESSION TIER.
///
/// The architecture audit confirmed a real, exploitable control-flow
/// gap: a password-authenticated legacy account that still needs
/// mandatory phone migration could reach Home on app restart without
/// ever completing it, because:
///   1. LoginView wrote a completed Hive session (isLoggedIn=true +
///      identity keys) BEFORE checking needsPhoneVerification, so
///      killing the app on VerifyPhoneMigrationView left Hive saying
///      "fully logged in" even though migration was incomplete.
///   2. SessionReconciliationView (the fallback path AppRouter uses
///      when Hive says logged-out but a real Firebase session exists)
///      routed straight to Home for ANY completed users/{uid} profile,
///      without ever checking needsPhoneVerification — a check
///      inspectCurrentSession() didn't even compute at the time.
///
/// This file proves the fix from the source (LoginView/
/// SessionReconciliationView/AppRouter cannot be exercised with
/// `testWidgets` in this environment — a pre-existing, unrelated
/// limitation also relied on by the other view-regression tests in
/// this suite). `inspectCurrentSession`'s own fix is covered separately
/// in `auth_remote_data_source_regression_test.dart` (it reads
/// `AuthRemoteDataSourceImpl`'s source, not these views').
///
/// STAGE 1 UPDATE: these views no longer touch `Hive.box('authBox')`
/// directly — session persistence is centralized behind
/// `SessionStorage.persistLoggedInSession(...)` (see
/// `session_storage_test.dart` for SessionStorage's own unit tests).
/// The assertions below were updated to look for that call instead of
/// the raw Hive calls it replaced; the underlying property each test
/// proves (persistence happens only after the migration check, never
/// before) is unchanged.
void main() {
  late String loginSource;
  late String reconciliationSource;
  late String migrationSource;
  late String routerSource;
  late String homSource;

  setUpAll(() {
    loginSource = File(
      'lib/auth/presentation/view/loginview.dart',
    ).readAsStringSync();
    reconciliationSource = File(
      'lib/auth/presentation/view/session_reconciliation_view.dart',
    ).readAsStringSync();
    migrationSource = File(
      'lib/auth/presentation/view/verify_phone_migration_view.dart',
    ).readAsStringSync();
    routerSource = File('lib/core/routes/app_router.dart').readAsStringSync();
    homSource = File('lib/features/views/hom.dart').readAsStringSync();
  });

  group('A: LoginView does not persist a completed Hive session before '
      'routing a needsPhoneVerification user to migration', () {
    test('the needsPhoneVerification branch contains no '
        'SessionStorage/Hive write, and returns before reaching the '
        'code that does', () {
      final branchStart = loginSource.indexOf(
        'state.user?.needsPhoneVerification == true',
      );
      expect(branchStart, greaterThan(-1));
      final returnIndex = loginSource.indexOf('return;', branchStart);
      expect(returnIndex, greaterThan(branchStart));

      final needsMigrationBranch = loginSource.substring(
        branchStart,
        returnIndex,
      );
      expect(needsMigrationBranch.contains('Hive.box'), isFalse);
      expect(needsMigrationBranch.contains('persistLoggedInSession'), isFalse);

      // The write DOES still exist in the file — just AFTER the early
      // return, on the non-migration path only.
      final afterReturn = loginSource.substring(returnIndex);
      expect(afterReturn.contains('persistLoggedInSession'), isTrue);
    });

    test('the needsPhoneVerification branch still navigates to '
        'verifyPhoneMigration with the account\'s own uid/name/phone — '
        'never Home', () {
      final branchStart = loginSource.indexOf(
        'state.user?.needsPhoneVerification == true',
      );
      final returnIndex = loginSource.indexOf('return;', branchStart);
      final needsMigrationBranch = loginSource.substring(
        branchStart,
        returnIndex,
      );
      expect(
        needsMigrationBranch.contains('AppNavigator.verifyPhoneMigration'),
        isTrue,
      );
      expect(needsMigrationBranch.contains('AppNavigator.home'), isFalse);
      expect(
        RegExp(
          r'VerifyPhoneMigrationArgs\(\s*uid:\s*state\.user!\.uid',
        ).hasMatch(needsMigrationBranch),
        isTrue,
      );
    });
  });

  group('D: SessionReconciliationView routes a reconciled '
      'needsPhoneVerification user to VerifyPhoneMigrationView, not '
      'Home', () {
    test('the AuthSuccess branch checks needsPhoneVerification BEFORE '
        'any SessionStorage/Hive write, and returns before reaching the '
        'write/Home navigation below it', () {
      final authSuccessStart = reconciliationSource.indexOf('is AuthSuccess');
      final branchStart = reconciliationSource.indexOf(
        'state.user?.needsPhoneVerification == true',
        authSuccessStart,
      );
      expect(branchStart, greaterThan(authSuccessStart));

      final returnIndex = reconciliationSource.indexOf('return;', branchStart);
      expect(returnIndex, greaterThan(branchStart));

      final needsMigrationBranch = reconciliationSource.substring(
        branchStart,
        returnIndex,
      );
      expect(needsMigrationBranch.contains('Hive.box'), isFalse);
      expect(needsMigrationBranch.contains('persistLoggedInSession'), isFalse);
      expect(needsMigrationBranch.contains('AppNavigator.home'), isFalse);
      expect(
        needsMigrationBranch.contains('AppNavigator.verifyPhoneMigration'),
        isTrue,
      );
      expect(
        RegExp(
          r'VerifyPhoneMigrationArgs\(\s*uid:\s*state\.user!\.uid',
        ).hasMatch(needsMigrationBranch),
        isTrue,
      );

      // The write + Home navigation DOES still exist — just after the
      // early return, for the non-migration (already-complete) case
      // only.
      final afterReturn = reconciliationSource.substring(returnIndex);
      expect(afterReturn.contains('persistLoggedInSession'), isTrue);
      expect(afterReturn.contains('AppNavigator.home'), isTrue);
    });
  });

  group('E: the restart control flow cannot use the Hive Home fast-path '
      'after an incomplete migration', () {
    test('AppRouter\'s fast-path to Home is still gated on '
        'SessionStorage.isLoggedIn (unchanged, now read via '
        'SessionStorage instead of a raw Hive.box call) — combined '
        'with A above (LoginView never persists a session before '
        'migration completes), an app killed on '
        'VerifyPhoneMigrationView cannot make this condition true on '
        'restart', () {
      final initialCaseStart = routerSource.indexOf('AppNavigator.initial:');
      expect(initialCaseStart, greaterThan(-1));
      final homeReturnIndex = routerSource.indexOf(
        '_homeWithProviders()',
        initialCaseStart,
      );
      final initialCaseBody = routerSource.substring(
        initialCaseStart,
        homeReturnIndex,
      );
      expect(initialCaseBody.contains('sl<SessionStorage>()'), isTrue);
      expect(initialCaseBody.contains('sessionStorage.isLoggedIn'), isTrue);
      expect(initialCaseBody.contains('sessionStorage.currentUserUid'), isTrue);
      expect(
        initialCaseBody.contains('firebaseUser.uid == currentUserUid'),
        isTrue,
      );
    });

    test('when the Hive fast-path condition is false but a Firebase '
        'session still exists, AppRouter falls through to '
        'SessionReconciliationView (the path D proves now correctly '
        'detects a pending migration) rather than any other route', () {
      final initialCaseStart = routerSource.indexOf('AppNavigator.initial:');
      final nextCaseStart = routerSource.indexOf(
        'case AppNavigator.register:',
        initialCaseStart,
      );
      final initialCaseBody = routerSource.substring(
        initialCaseStart,
        nextCaseStart,
      );
      expect(initialCaseBody.contains('SessionReconciliationView'), isTrue);
      // Ordering: the hasActiveSession fast-path check comes first,
      // the SessionReconciliationView fallback second — never the
      // reverse (which would make the fallback dead code).
      final fastPathIndex = initialCaseBody.indexOf('hasActiveSession');
      final reconciliationIndex = initialCaseBody.indexOf(
        'SessionReconciliationView',
      );
      expect(fastPathIndex, lessThan(reconciliationIndex));
    });
  });

  group('F: successful migration still persists the completed session '
      'and routes Home (unchanged by this fix)', () {
    test('VerifyPhoneMigrationView\'s AuthSuccess branch still calls '
        'SessionStorage.persistLoggedInSession with the account\'s own '
        'uid/name/phone, and still calls _goHome()', () {
      final authSuccessStart = migrationSource.indexOf('is AuthSuccess');
      final authSuccessEnd = migrationSource.indexOf(
        'else if (state is AuthError)',
        authSuccessStart,
      );
      final authSuccessBranch = migrationSource.substring(
        authSuccessStart,
        authSuccessEnd,
      );
      expect(authSuccessBranch.contains('sl<SessionStorage>()'), isTrue);
      expect(authSuccessBranch.contains('persistLoggedInSession'), isTrue);
      expect(
        RegExp(r'uid:\s*state\.user!\.uid').hasMatch(authSuccessBranch),
        isTrue,
      );
      expect(
        RegExp(r'name:\s*state\.user!\.name').hasMatch(authSuccessBranch),
        isTrue,
      );
      expect(
        RegExp(
          r'phone:\s*state\.user!\.phoneNumber',
        ).hasMatch(authSuccessBranch),
        isTrue,
      );
      expect(authSuccessBranch.contains('_goHome()'), isTrue);
    });

    test('VerifyPhoneMigrationView persists ONLY after AuthSuccess — '
        'the AuthOtpSent branch (reached when an OTP is merely sent, '
        'before the user has entered/verified anything) never calls '
        'persistLoggedInSession', () {
      final otpSentStart = migrationSource.indexOf('is AuthOtpSent');
      final otpSentEnd = migrationSource.indexOf(
        'else if (state is AuthSuccess)',
        otpSentStart,
      );
      expect(otpSentStart, greaterThan(-1));
      expect(otpSentEnd, greaterThan(otpSentStart));
      final otpSentBranch = migrationSource.substring(otpSentStart, otpSentEnd);
      expect(otpSentBranch.contains('persistLoggedInSession'), isFalse);
    });
  });

  group('F: normal (non-migration) login still persists a session and '
      'reaches Home — this stage only centralized the write mechanism, '
      'it did not change when persistence happens for an ordinary '
      'Phase 3 login', () {
    test('the code after the needsPhoneVerification early-return still '
        'calls persistLoggedInSession with the account\'s own '
        'uid/name/phone and still navigates to AppNavigator.home', () {
      final branchStart = loginSource.indexOf(
        'state.user?.needsPhoneVerification == true',
      );
      final returnIndex = loginSource.indexOf('return;', branchStart);
      final afterReturn = loginSource.substring(returnIndex);

      expect(afterReturn.contains('sl<SessionStorage>()'), isTrue);
      expect(afterReturn.contains('persistLoggedInSession'), isTrue);
      expect(RegExp(r'uid:\s*state\.user!\.uid').hasMatch(afterReturn), isTrue);
      expect(
        RegExp(r'name:\s*state\.user!\.name').hasMatch(afterReturn),
        isTrue,
      );
      expect(
        RegExp(r'phone:\s*state\.user!\.phoneNumber').hasMatch(afterReturn),
        isTrue,
      );
      expect(afterReturn.contains('AppNavigator.home'), isTrue);
      // Never the migration route on this path.
      expect(
        afterReturn.contains('AppNavigator.verifyPhoneMigration'),
        isFalse,
      );
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
}
