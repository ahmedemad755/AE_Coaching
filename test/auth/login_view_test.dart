import 'dart:async';

import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/entities/email_auth_messages.dart';
import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/presentation/view/loginview.dart';
import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/layout/keyboard_phone.dart';
import 'support/auth_test_app.dart';
import 'support/auth_cubit_builder.dart';

const _email = Key('login_email_field');
const _password = Key('login_password_field');
const _submit = Key('login_submit_button');

void main() {
  late FakeEmailAuthRepository email;
  late PersistedSessions persisted;

  setUp(() => email = FakeEmailAuthRepository());

  Future<void> open(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    persisted = recordPersistedSessions();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider(
        // Safe in tests: falls back to Arabic when Hive isn't open.
        create: (_) => LocaleCubit(),
        child: buildAuthTestApp(
          locale: locale,
          root: (_) => BlocProvider(
            create: (_) =>
                buildAuthCubit(email),
            child: const LoginView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> login(
    WidgetTester tester, {
    String address = 'ahmed@example.com',
    String password = 'secret1',
  }) async {
    await tester.enterText(find.byKey(_email), address);
    await tester.enterText(find.byKey(_password), password);
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
  }

  testWidgets('verified account → session persisted, Home', (tester) async {
    await open(tester);
    await login(tester);
    expect(email.lastLoginEmail, 'ahmed@example.com');
    expect(persisted.uids, ['uid-1']);
    expect(find.text('home-screen'), findsOneWidget);
  });

  testWidgets('UNVERIFIED account → Verify Email, no session persisted, no '
      'Home', (tester) async {
    email.loginResult = const EmailSessionResolution.pendingVerification(
      'ahmed@example.com',
    );
    await open(tester);
    await login(tester);
    expect(
      find.text('verify-email-screen email=ahmed@example.com sent=false'),
      findsOneWidget,
    );
    expect(persisted.uids, isEmpty);
    expect(find.text('home-screen'), findsNothing);
  });

  testWidgets('profile unavailable → account check, never Home', (
    tester,
  ) async {
    email.loginResult = const EmailSessionResolution.profileUnavailable(
      'ahmed@example.com',
      ProfileFailure.network,
    );
    await open(tester);
    await login(tester);
    expect(find.text('session-check-screen'), findsOneWidget);
    expect(persisted.uids, isEmpty);
  });

  testWidgets('missing profile → Complete Profile', (tester) async {
    email.loginResult = const EmailSessionResolution.incompleteProfile(
      'ahmed@example.com',
    );
    await open(tester);
    await login(tester);
    expect(
      find.text('complete-profile-screen email=ahmed@example.com'),
      findsOneWidget,
    );
    expect(persisted.uids, isEmpty);
  });

  testWidgets('wrong credentials: one neutral, localized message; the form '
      'stays for a retry', (tester) async {
    email.errorToThrow = Exception(EmailAuthMessages.incorrectCredentials);
    await open(tester, locale: const Locale('ar'));
    await login(tester);
    expect(
      find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة.'),
      findsOneWidget,
    );
    expect(find.byType(LoginView), findsOneWidget);
  });

  testWidgets('validation: email format; password only required (no new-'
      'password policy at sign-in)', (tester) async {
    await open(tester);
    await login(tester, address: 'nope', password: '');
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(email.loginCalls, 0);

    await login(tester, address: 'a@example.com', password: '12');
    expect(email.loginCalls, 1);
  });

  testWidgets('double-tap signs in once; fields lock while signing in', (
    tester,
  ) async {
    await open(tester);
    email.hold = Completer<void>();
    await tester.enterText(find.byKey(_email), 'ahmed@example.com');
    await tester.enterText(find.byKey(_password), 'secret1');
    await tester.tap(find.byKey(_submit));
    await tester.tap(find.byKey(_submit), warnIfMissed: false);
    await tester.pump();
    expect(email.loginCalls, 1);
    final field = tester.widget<TextField>(
      find.descendant(of: find.byKey(_email), matching: find.byType(TextField)),
    );
    expect(field.enabled, isFalse);
    email.hold!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Forgot Password carries the typed email', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(_email), 'ahmed@example.com');
    await tester.tap(find.byKey(const Key('login_forgot_button')));
    await tester.pumpAndSettle();
    expect(find.text('forgot-screen email=ahmed@example.com'), findsOneWidget);
  });

  testWidgets('email field stays LTR in Arabic and offers email autofill', (
    tester,
  ) async {
    await open(tester, locale: const Locale('ar'));
    final field = tester.widget<TextField>(
      find.descendant(of: find.byKey(_email), matching: find.byType(TextField)),
    );
    expect(field.textDirection, TextDirection.ltr);
    expect(field.keyboardType, TextInputType.emailAddress);
    expect(field.autofillHints, contains(AutofillHints.email));
  });

  testWidgets('authenticated users always carry their email into the '
      'session marker path', (tester) async {
    email.loginResult = const EmailSessionResolution.authenticated(
      AuthUser(uid: 'uid-9', name: 'N', email: 'n@example.com'),
    );
    await open(tester);
    await login(tester);
    expect(persisted.uids, ['uid-9']);
  });

  for (final language in ['en', 'ar']) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        '$language · text ×$scale: small phone, keyboard open on the password',
        (tester) async {
          await open(tester, locale: Locale(language));
          useSmallPhone(tester, textScale: scale);
          await tester.pumpAndSettle();
          expectNoOverflow(tester);
          await tester.ensureVisible(find.byKey(_password));
          await tester.showKeyboard(
            find.descendant(
              of: find.byKey(_password),
              matching: find.byType(EditableText),
            ),
          );
          await setKeyboard(tester, open: true);
          expectNoOverflow(tester);
          expect(
            tester.getRect(find.byKey(_password)).bottom,
            lessThanOrEqualTo(smallPhone.height - keyboardHeight),
          );
          // The sign-in button is reachable without closing the keyboard.
          await tester.ensureVisible(find.byKey(_submit));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(_submit)).bottom,
            lessThanOrEqualTo(smallPhone.height - keyboardHeight),
          );
          await setKeyboard(tester, open: false);
          expectNoOverflow(tester);
        },
      );
    }
  }
}
