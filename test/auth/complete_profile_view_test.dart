import 'package:ae_coaching/auth/domain/entities/email_auth_messages.dart';
import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/presentation/view/complete_profile_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_test_app.dart';
import 'support/auth_cubit_builder.dart';

/// Missing-profile recovery: the name step for a verified account whose
/// `users/{uid}` was never written.
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
          child: const CompleteProfileView(email: 'ahmed@example.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a valid name creates the profile and enters Home', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const Key('complete_profile_name_field')),
      '  Ahmed   Emad ',
    );
    await tester.tap(find.byKey(const Key('complete_profile_save_button')));
    await tester.pumpAndSettle();

    expect(email.lastProfileName, 'Ahmed Emad');
    expect(persisted.uids, ['uid-1']);
    expect(find.text('home-screen'), findsOneWidget);
  });

  testWidgets('the shared name rule applies', (tester) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const Key('complete_profile_name_field')),
      '123',
    );
    await tester.tap(find.byKey(const Key('complete_profile_save_button')));
    await tester.pumpAndSettle();
    expect(find.text('Name must include letters'), findsOneWidget);
    expect(email.completeProfileCalls, 0);
  });

  testWidgets('system back asks before signing out to Login', (tester) async {
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auth_confirm_sign_out')));
    await tester.pumpAndSettle();
    expect(email.signOutCalls, 1);
    expect(find.text('login-screen'), findsOneWidget);
  });

  testWidgets('a rejected profile save shows the permission error and stays '
      'for a retry; nothing is persisted', (tester) async {
    await open(tester);
    email.errorToThrow = Exception(EmailAuthMessages.profilePermissionDenied);
    await tester.enterText(
      find.byKey(const Key('complete_profile_name_field')),
      'Ahmed',
    );
    await tester.tap(find.byKey(const Key('complete_profile_save_button')));
    await tester.pumpAndSettle();
    expect(
      find.text(EmailAuthMessages.profilePermissionDenied),
      findsOneWidget,
    );
    expect(find.byType(CompleteProfileView), findsOneWidget);
    expect(persisted.uids, isEmpty);

    email.errorToThrow = null;
    await tester.tap(find.byKey(const Key('complete_profile_save_button')));
    await tester.pumpAndSettle();
    expect(find.text('home-screen'), findsOneWidget);
  });

  testWidgets('saved, but the profile still cannot be confirmed → account '
      'check', (tester) async {
    email.completeProfileResult =
        const EmailSessionResolution.profileUnavailable(
          'ahmed@example.com',
          ProfileFailure.unknown,
        );
    await open(tester);
    await tester.enterText(
      find.byKey(const Key('complete_profile_name_field')),
      'Ahmed',
    );
    await tester.tap(find.byKey(const Key('complete_profile_save_button')));
    await tester.pumpAndSettle();
    expect(find.text('session-check-screen'), findsOneWidget);
    expect(persisted.uids, isEmpty);
  });
}
