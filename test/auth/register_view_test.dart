import 'dart:async';

import 'package:ae_coaching/auth/domain/entities/email_auth_messages.dart';
import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/presentation/view/register_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_app.dart';
import 'support/auth_cubit_builder.dart';

const _name = Key('register_name_field');
const _email = Key('register_email_field');
const _password = Key('register_password_field');
const _confirm = Key('register_confirm_field');
const _submit = Key('register_submit_button');

/// Email-first registration (Stage 3B), with all Stage 2 validation and
/// UX guarantees carried over.
void main() {
  late FakeEmailAuthRepository email;
  late PersistedSessions persisted;

  setUp(() => email = FakeEmailAuthRepository());

  Future<void> open(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    persisted = recordPersistedSessions();
    // A tall surface so the whole form (with helper/error lines) is on
    // screen and every field can be tapped.
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      buildAuthTestApp(
        locale: locale,
        root: (_) => BlocProvider(
          create: (_) => buildAuthCubit(email),
          child: const RegisterView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String name = 'Ahmed Emad',
    String address = 'ahmed@example.com',
    String password = 'secret1',
    String? confirm,
  }) async {
    await tester.enterText(find.byKey(_name), name);
    await tester.enterText(find.byKey(_email), address);
    await tester.enterText(find.byKey(_password), password);
    await tester.enterText(find.byKey(_confirm), confirm ?? password);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byKey(_submit));
    await tester.pumpAndSettle();
  }

  group('Validation', () {
    testWidgets('an empty form shows every required error and creates '
        'nothing', (tester) async {
      await open(tester);
      await submit(tester);

      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
      expect(email.registerCalls, 0);
    });

    testWidgets('mismatched confirmation blocks submission', (tester) async {
      await open(tester);
      await fill(tester, confirm: 'secret2');
      await submit(tester);

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(email.registerCalls, 0);
    });

    testWidgets('after a failed attempt, editing Password re-checks Confirm '
        'live', (tester) async {
      await open(tester);
      await fill(tester, password: 'secret1', confirm: 'secret12');
      await submit(tester);
      expect(find.text('Passwords do not match'), findsOneWidget);

      await tester.enterText(find.byKey(_password), 'secret12');
      await tester.pump();
      expect(find.text('Passwords do not match'), findsNothing);
    });

    testWidgets('short and edge-whitespace passwords are explained', (
      tester,
    ) async {
      await open(tester);
      await fill(tester, password: '12345');
      await submit(tester);
      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );

      await fill(tester, password: 'secret1 ');
      await submit(tester);
      expect(
        find.text("Password can't start or end with a space"),
        findsOneWidget,
      );
      expect(email.registerCalls, 0);
    });

    testWidgets('invalid and reserved email addresses are explained', (
      tester,
    ) async {
      await open(tester);
      await fill(tester, address: 'ahmed@');
      await submit(tester);
      expect(find.text('Enter a valid email address'), findsOneWidget);

      await tester.enterText(
        find.byKey(_email),
        'u201012345678@ae-coaching.app',
      );
      await tester.pump();
      expect(find.text("This email address can't be used"), findsOneWidget);
      expect(email.registerCalls, 0);
    });

    testWidgets('a name with no letters is rejected; single letters and '
        'Arabic names are fine', (tester) async {
      await open(tester);
      await fill(tester, name: '12345');
      await submit(tester);
      expect(find.text('Name must include letters'), findsOneWidget);

      await tester.enterText(find.byKey(_name), 'أ');
      await tester.pump();
      expect(find.text('Name must include letters'), findsNothing);
    });

    testWidgets('errors are not shown before the first submit attempt', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(find.byKey(_password), '1');
      await tester.pump();
      expect(find.text('Password must be at least 6 characters'), findsNothing);
    });
  });

  group('Submission', () {
    testWidgets('valid input creates the account with normalized name/email '
        'and the exact password, then goes to Verify Email — never Home, and '
        'no local session', (tester) async {
      await open(tester);
      await fill(
        tester,
        name: '  Ahmed   Emad ',
        address: '  Ahmed@Example.COM ',
        password: 'my pass phrase',
      );
      await submit(tester);

      expect(email.registerCalls, 1);
      expect(email.lastRegisterName, 'Ahmed Emad');
      expect(email.lastRegisterEmail, 'ahmed@example.com');
      expect(email.lastRegisterPassword, 'my pass phrase');
      expect(email.lastLanguageCode, 'en');
      expect(
        find.text('verify-email-screen email=new@example.com sent=true'),
        findsOneWidget,
      );
      expect(find.text('home-screen'), findsNothing);
      expect(persisted.uids, isEmpty);
    });

    testWidgets('if the verification email could not be sent, Verify Email '
        'is told so', (tester) async {
      email.registerResult = const EmailSessionResolution.pendingVerification(
        'ahmed@example.com',
      );
      await open(tester);
      await fill(tester);
      await submit(tester);
      expect(
        find.text('verify-email-screen email=ahmed@example.com sent=false'),
        findsOneWidget,
      );
    });

    testWidgets('double-tapping Create Account creates one account, and '
        'fields are locked while it runs', (tester) async {
      await open(tester);
      await fill(tester);
      email.hold = Completer<void>();
      await tester.tap(find.byKey(_submit));
      await tester.tap(find.byKey(_submit), warnIfMissed: false);
      await tester.pump();

      expect(email.registerCalls, 1);
      final nameField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(_name),
          matching: find.byType(TextField),
        ),
      );
      expect(nameField.enabled, isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      email.hold!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('an existing email gets "log in instead" and the form stays '
        'filled in', (tester) async {
      await open(tester);
      await fill(tester);
      email.errorToThrow = Exception(EmailAuthMessages.emailInUse);
      await submit(tester);

      expect(find.text(EmailAuthMessages.emailInUse), findsOneWidget);
      expect(find.text('Ahmed Emad'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byKey(_submit));
      expect(button.onPressed, isNotNull);
    });
  });

  group('Keyboard and accessibility', () {
    testWidgets('Next moves focus name → email → password → confirm, and Done '
        'on confirm submits', (tester) async {
      await open(tester);
      await fill(tester);

      bool focused(Key key) => tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus;

      await tester.tap(find.byKey(_name));
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(focused(_email), isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(focused(_password), isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(focused(_confirm), isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(email.registerCalls, 1);
    });

    testWidgets('each password field has its own labelled visibility toggle; '
        'passwords are never suggested or autocorrected', (tester) async {
      await open(tester);
      expect(find.byTooltip('Show password'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('register_password_toggle')));
      await tester.pump();
      expect(find.byTooltip('Hide password'), findsOneWidget);
      expect(find.byTooltip('Show password'), findsOneWidget);

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(_password),
          matching: find.byType(TextField),
        ),
      );
      expect(field.enableSuggestions, isFalse);
      expect(field.autocorrect, isFalse);
      expect(field.obscureText, isFalse); // toggled visible
      expect(field.autofillHints, contains(AutofillHints.newPassword));
    });

    testWidgets('the email field uses the email keyboard and autofill', (
      tester,
    ) async {
      await open(tester);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(_email),
          matching: find.byType(TextField),
        ),
      );
      expect(field.keyboardType, TextInputType.emailAddress);
      expect(field.autofillHints, contains(AutofillHints.email));
      expect(field.autocorrect, isFalse);
    });
  });

  testWidgets('Arabic: RTL layout, Arabic messages, email stays LTR', (
    tester,
  ) async {
    await open(tester, locale: const Locale('ar'));
    expect(
      Directionality.of(tester.element(find.byType(RegisterView))),
      TextDirection.rtl,
    );
    await fill(tester, confirm: 'different1');
    await submit(tester);
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);

    final emailField = tester.widget<TextField>(
      find.descendant(of: find.byKey(_email), matching: find.byType(TextField)),
    );
    expect(emailField.textDirection, TextDirection.ltr);
  });
}
