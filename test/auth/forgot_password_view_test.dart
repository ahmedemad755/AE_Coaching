import 'package:ae_coaching/auth/domain/entities/email_auth_messages.dart';
import 'package:ae_coaching/auth/presentation/view/forgot_password_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_app.dart';
import 'support/auth_cubit_builder.dart';

void main() {
  late FakeEmailAuthRepository email;

  setUp(() => email = FakeEmailAuthRepository());

  Future<void> open(
    WidgetTester tester, {
    String initialEmail = '',
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      buildAuthTestApp(
        locale: locale,
        root: (_) => BlocProvider(
          create: (_) => buildAuthCubit(email),
          child: ForgotPasswordView(initialEmail: initialEmail),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('forgot_submit_button')));
    await tester.pumpAndSettle();
  }

  testWidgets('sends the reset email in the UI language and shows a neutral '
      'confirmation', (tester) async {
    await open(tester, initialEmail: ' Ahmed@Example.com ');
    await send(tester);

    expect(email.lastResetEmail, 'ahmed@example.com');
    expect(email.lastLanguageCode, 'en');
    expect(
      find.text(
        "If an account exists for ahmed@example.com, we've sent a link to "
        'reset your password.',
      ),
      findsOneWidget,
    );
    // No password is ever asked for or handled in the app.
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('the confirmation is identical for an unknown address (no '
      'account enumeration)', (tester) async {
    // The data source swallows user-not-found, so the repository simply
    // completes, exactly as for a real account.
    await open(tester, initialEmail: 'nobody@example.com');
    await send(tester);
    expect(find.textContaining('If an account exists for'), findsOneWidget);
  });

  testWidgets('an invalid address is rejected before anything is sent', (
    tester,
  ) async {
    await open(tester, initialEmail: 'nope');
    await send(tester);
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(email.passwordResetCalls, 0);
  });

  testWidgets('network failure keeps the form for a retry', (tester) async {
    email.errorToThrow = Exception(EmailAuthMessages.network);
    await open(tester, initialEmail: 'a@example.com');
    await send(tester);
    expect(find.text(EmailAuthMessages.network), findsOneWidget);
    expect(find.byKey(const Key('forgot_submit_button')), findsOneWidget);
  });

  testWidgets('Arabic copy and Arabic email language', (tester) async {
    await open(
      tester,
      initialEmail: 'a@example.com',
      locale: const Locale('ar'),
    );
    await send(tester);
    expect(email.lastLanguageCode, 'ar');
    expect(find.text('تحقق من بريدك الإلكتروني'), findsOneWidget);
  });
}
