import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/entities/email_auth_messages.dart';
import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/presentation/view/verify_email_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_app.dart';
import 'support/auth_cubit_builder.dart';

const _check = Key('verify_email_check_button');
const _resend = Key('verify_email_resend_button');
const _change = Key('verify_email_change_button');
const _signOut = Key('verify_email_sign_out_button');

void main() {
  late FakeEmailAuthRepository email;
  late PersistedSessions persisted;

  setUp(() {
    email = FakeEmailAuthRepository();
  });

  Future<void> open(
    WidgetTester tester, {
    bool sent = true,
    Locale locale = const Locale('en'),
  }) async {
    persisted = recordPersistedSessions();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      buildAuthTestApp(
        locale: locale,
        root: (_) => BlocProvider(
          create: (_) => buildAuthCubit(email),
          child: VerifyEmailView(
            email: 'ahmed@example.com',
            verificationEmailSent: sent,
            resendCooldown: const Duration(seconds: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  VoidCallback? onPressed(WidgetTester tester, Key key) =>
      tester.widget<ButtonStyleButton>(find.byKey(key)).onPressed;

  group('The only way to Home is a server-confirmed verification', () {
    testWidgets('"I\'ve verified" while still unverified stays here, says so, '
        'and persists no session', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(_check));
      await tester.pumpAndSettle();

      expect(email.refreshCalls, 1);
      expect(find.byType(VerifyEmailView), findsOneWidget);
      expect(
        find.text(
          "Your email isn't verified yet. Open the link we sent, then try "
          'again.',
        ),
        findsOneWidget,
      );
      expect(find.text('home-screen'), findsNothing);
      expect(persisted.uids, isEmpty);
    });

    testWidgets('once verified, the session is persisted and Home opens', (
      tester,
    ) async {
      await open(tester);
      email.refreshResult = const EmailSessionResolution.authenticated(
        AuthUser(uid: 'uid-1', name: 'Ahmed', email: 'ahmed@example.com'),
      );
      await tester.tap(find.byKey(_check));
      await tester.pumpAndSettle();

      expect(persisted.uids, ['uid-1']);
      expect(find.text('home-screen'), findsOneWidget);
      expect(find.text('Email verified successfully'), findsOneWidget);
    });

    testWidgets('returning to the app re-checks silently and enters Home '
        'when the link was opened', (tester) async {
      await open(tester);
      email.refreshResult = const EmailSessionResolution.authenticated(
        AuthUser(uid: 'uid-1', name: 'Ahmed', email: 'ahmed@example.com'),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(email.refreshCalls, 1);
      expect(find.text('home-screen'), findsOneWidget);
    });

    testWidgets('a silent re-check that is still unverified shows nothing', (
      tester,
    ) async {
      await open(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(email.refreshCalls, 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(VerifyEmailView), findsOneWidget);
    });

    testWidgets('verified but profile missing → Complete Profile, not Home', (
      tester,
    ) async {
      await open(tester);
      email.refreshResult = const EmailSessionResolution.incompleteProfile(
        'ahmed@example.com',
      );
      await tester.tap(find.byKey(_check));
      await tester.pumpAndSettle();
      expect(
        find.text('complete-profile-screen email=ahmed@example.com'),
        findsOneWidget,
      );
      expect(persisted.uids, isEmpty);
    });
  });

  testWidgets('verified but profile unavailable → account check (Retry), '
      'never Home, no session', (tester) async {
    await open(tester);
    email.refreshResult = const EmailSessionResolution.profileUnavailable(
      'ahmed@example.com',
      ProfileFailure.permissionDenied,
    );
    await tester.tap(find.byKey(_check));
    await tester.pumpAndSettle();
    expect(find.text('session-check-screen'), findsOneWidget);
    expect(find.text('home-screen'), findsNothing);
    expect(persisted.uids, isEmpty);
  });

  group('Resend', () {
    testWidgets('cools down after the registration email, then resends', (
      tester,
    ) async {
      await open(tester);
      expect(onPressed(tester, _resend), isNull);
      expect(find.text('Resend in 3s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.tap(find.byKey(_resend));
      await tester.pumpAndSettle();

      expect(email.resendCalls, 1);
      expect(email.lastLanguageCode, 'en');
      expect(find.text('Verification email sent.'), findsOneWidget);
      expect(onPressed(tester, _resend), isNull); // cooling down again
    });

    testWidgets('when the first email failed to send, Resend is available '
        'immediately and the text says so', (tester) async {
      await open(tester, sent: false);
      expect(onPressed(tester, _resend), isNotNull);
      expect(
        find.textContaining("We couldn't send the verification email"),
        findsOneWidget,
      );
    });

    testWidgets('rate limiting is reported, and the screen stays', (
      tester,
    ) async {
      await open(tester, sent: false);
      email.errorToThrow = Exception(EmailAuthMessages.tooManyRequests);
      await tester.tap(find.byKey(_resend));
      await tester.pumpAndSettle();
      expect(find.text(EmailAuthMessages.tooManyRequests), findsOneWidget);
      expect(find.byType(VerifyEmailView), findsOneWidget);
    });
  });

  group('Change email', () {
    testWidgets('validates the new address, then sends the link there', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(_change));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('change_email_field')), 'x');
      await tester.tap(find.byKey(const Key('change_email_submit')));
      await tester.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(email.emailChangeCalls, 0);

      await tester.enterText(
        find.byKey(const Key('change_email_field')),
        ' New@Example.com ',
      );
      await tester.tap(find.byKey(const Key('change_email_submit')));
      await tester.pumpAndSettle();

      expect(email.lastNewEmail, 'new@example.com');
      expect(
        find.text(
          'Verification link sent to new@example.com. Open it to finish '
          'changing your email.',
        ),
        findsOneWidget,
      );
      expect(find.byType(VerifyEmailView), findsOneWidget);
    });

    testWidgets('cancel leaves everything unchanged', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(_change));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(email.emailChangeCalls, 0);
    });
  });

  group('Never a trap: leaving signs out to Login, never Home', () {
    testWidgets('Sign out asks, then signs out and lands on Login', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(_signOut));
      await tester.pumpAndSettle();
      expect(find.text('Leave verification?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('auth_confirm_sign_out')));
      await tester.pumpAndSettle();
      expect(email.signOutCalls, 1);
      expect(find.text('login-screen'), findsOneWidget);
      expect(persisted.uids, isEmpty);
    });

    testWidgets('Android system back asks too; "Stay" keeps the session', (
      tester,
    ) async {
      await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Leave verification?'), findsOneWidget);

      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.byType(VerifyEmailView), findsOneWidget);
      expect(email.signOutCalls, 0);
    });

    testWidgets('an expired session sends the user to Login with the reason', (
      tester,
    ) async {
      await open(tester);
      email.errorToThrow = Exception(EmailAuthMessages.sessionExpired);
      await tester.tap(find.byKey(_check));
      await tester.pumpAndSettle();
      expect(find.text('login-screen'), findsOneWidget);
      expect(find.text(EmailAuthMessages.sessionExpired), findsOneWidget);
    });
  });

  testWidgets('Arabic: RTL, translated copy and errors', (tester) async {
    await open(tester, locale: const Locale('ar'));
    expect(
      Directionality.of(tester.element(find.byType(VerifyEmailView))),
      TextDirection.rtl,
    );
    expect(find.text('تأكيد البريد الإلكتروني'), findsOneWidget);
    await tester.tap(find.byKey(_check));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'لم يتم تأكيد بريدك الإلكتروني بعد. افتح الرابط الذي أرسلناه ثم حاول '
        'مرة أخرى.',
      ),
      findsOneWidget,
    );
  });
}
