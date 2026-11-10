import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/entities/email_auth_messages.dart';
import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/presentation/view/session_reconciliation_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_app.dart';
import 'support/auth_cubit_builder.dart';

/// Startup session check (Stage 3B, email-first), exercised for every
/// AuthStatus it can resolve to.
void main() {
  late FakeEmailAuthRepository email;
  late PersistedSessions persisted;

  setUp(() => email = FakeEmailAuthRepository());

  Future<void> open(WidgetTester tester) async {
    persisted = recordPersistedSessions();
    await tester.pumpWidget(
      buildAuthTestApp(
        root: (_) => BlocProvider(
          create: (_) => buildAuthCubit(email),
          child: const SessionReconciliationView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('authenticated → marker rebuilt, Home', (tester) async {
    email.sessionResult = const EmailSessionResolution.authenticated(
      AuthUser(uid: 'uid-1', name: 'Ahmed', email: 'ahmed@example.com'),
    );
    await open(tester);
    expect(persisted.uids, ['uid-1']);
    expect(find.text('home-screen'), findsOneWidget);
  });

  testWidgets('app killed on Verify Email → restart resumes Verify Email '
      'without sending another email, never Home', (tester) async {
    email.sessionResult = const EmailSessionResolution.pendingVerification(
      'ahmed@example.com',
    );
    await open(tester);
    expect(
      find.text('verify-email-screen email=ahmed@example.com sent=false'),
      findsOneWidget,
    );
    expect(email.resendCalls, 0);
    expect(persisted.uids, isEmpty);
    expect(find.text('home-screen'), findsNothing);
  });

  testWidgets('incomplete profile → Complete Profile', (tester) async {
    email.sessionResult = const EmailSessionResolution.incompleteProfile(
      'ahmed@example.com',
    );
    await open(tester);
    expect(
      find.text('complete-profile-screen email=ahmed@example.com'),
      findsOneWidget,
    );
  });

  testWidgets('phone-era test account → signed out with an explanation; '
      'nothing deleted', (tester) async {
    email.sessionResult = const EmailSessionResolution.legacyAccount();
    await open(tester);
    expect(email.signOutCalls, 1);
    expect(find.text('login-screen'), findsOneWidget);
    expect(
      find.text(
        'This test account is no longer supported. Please create a new '
        'account with your email.',
      ),
      findsOneWidget,
    );
    expect(persisted.uids, isEmpty);
  });

  testWidgets('nothing usable (or a revoked session) → Login', (tester) async {
    await open(tester);
    expect(find.text('login-screen'), findsOneWidget);
  });

  group('A failed check is not treated as "signed out"', () {
    testWidgets('offline: the session is kept, and Retry re-runs the check', (
      tester,
    ) async {
      email.errorToThrow = Exception(EmailAuthMessages.network);
      await open(tester);
      expect(email.signOutCalls, 0);
      expect(find.text("We couldn't check your account"), findsOneWidget);

      email.errorToThrow = null;
      email.sessionResult = const EmailSessionResolution.pendingVerification(
        'ahmed@example.com',
      );
      await tester.tap(find.byKey(const Key('session_check_retry')));
      await tester.pumpAndSettle();
      expect(email.resolveCalls, 2);
      expect(find.textContaining('verify-email-screen'), findsOneWidget);
    });

    testWidgets('the user can still choose to sign out', (tester) async {
      email.errorToThrow = Exception(EmailAuthMessages.network);
      await open(tester);
      email.errorToThrow = null;
      await tester.tap(find.byKey(const Key('session_check_sign_out')));
      await tester.pumpAndSettle();
      expect(email.signOutCalls, 1);
      expect(find.text('login-screen'), findsOneWidget);
    });
  });

  group('Profile could not be confirmed: real reason, Retry, never Home', () {
    testWidgets('permission denied is shown as such; nothing is persisted', (
      tester,
    ) async {
      email.sessionResult = const EmailSessionResolution.profileUnavailable(
        'ahmed@example.com',
        ProfileFailure.permissionDenied,
      );
      await open(tester);
      expect(
        find.text("We couldn't finish setting up your account"),
        findsOneWidget,
      );
      expect(
        find.text(
          'Access to your account profile was denied. Please try again '
          'later, or contact support if this continues.',
        ),
        findsOneWidget,
      );
      expect(find.text('home-screen'), findsNothing);
      expect(persisted.uids, isEmpty);
      expect(email.signOutCalls, 0);
    });

    testWidgets('Retry after the problem clears enters Home', (tester) async {
      email.sessionResult = const EmailSessionResolution.profileUnavailable(
        'ahmed@example.com',
        ProfileFailure.network,
      );
      await open(tester);
      expect(
        find.text('Check your internet connection and try again.'),
        findsOneWidget,
      );

      email.sessionResult = const EmailSessionResolution.authenticated(
        AuthUser(uid: 'uid-1', name: 'Ahmed', email: 'ahmed@example.com'),
      );
      await tester.tap(find.byKey(const Key('session_check_retry')));
      await tester.pumpAndSettle();
      expect(persisted.uids, ['uid-1']);
      expect(find.text('home-screen'), findsOneWidget);
    });

    testWidgets('a conflicting profile tells the user to contact support', (
      tester,
    ) async {
      email.sessionResult = const EmailSessionResolution.profileUnavailable(
        'ahmed@example.com',
        ProfileFailure.conflicting,
      );
      await open(tester);
      expect(
        find.text(
          'Your account profile needs attention. Please contact support.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Arabic copy for the failure panel', (tester) async {
      email.sessionResult = const EmailSessionResolution.profileUnavailable(
        'ahmed@example.com',
        ProfileFailure.unknown,
      );
      persisted = recordPersistedSessions();
      await tester.pumpWidget(
        buildAuthTestApp(
          locale: const Locale('ar'),
          root: (_) => BlocProvider(
            create: (_) =>
                buildAuthCubit(email),
            child: const SessionReconciliationView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('لم نتمكن من إكمال إعداد حسابك'), findsOneWidget);
    });
  });
}
