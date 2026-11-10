import 'dart:async';

import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/auth_cubit_builder.dart';

void main() {
  late FakeEmailAuthRepository email;
  late AuthCubit cubit;

  setUp(() {
    email = FakeEmailAuthRepository();
    cubit = buildAuthCubit(email);
  });

  tearDown(() => cubit.close());

  Future<List<AuthState>> record(Future<void> Function() action) async {
    final states = <AuthState>[];
    final sub = cubit.stream.listen(states.add);
    await action();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return states;
  }

  const verifiedUser = AuthUser(
    uid: 'uid-1',
    name: 'Ahmed',
    email: 'ahmed@example.com',
  );

  group('Every resolution maps to exactly one state', () {
    test('authenticated → AuthSuccess carrying the user', () async {
      email.loginResult = const EmailSessionResolution.authenticated(
        verifiedUser,
      );
      await cubit.loginWithEmail(email: 'ahmed@example.com', password: 'p');
      final state = cubit.state as AuthSuccess;
      expect(state.user!.uid, 'uid-1');
      expect(state.message, 'Logged in successfully');
    });

    test('pending verification → AuthEmailVerificationRequired, never '
        'AuthSuccess', () async {
      email.loginResult = const EmailSessionResolution.pendingVerification(
        'ahmed@example.com',
      );
      final states = await record(
        () => cubit.loginWithEmail(email: 'ahmed@example.com', password: 'p'),
      );
      expect(states.whereType<AuthSuccess>(), isEmpty);
      expect(
        (cubit.state as AuthEmailVerificationRequired).email,
        'ahmed@example.com',
      );
    });

    test('incomplete profile → AuthProfileIncomplete', () async {
      email.sessionResult = const EmailSessionResolution.incompleteProfile(
        'ahmed@example.com',
      );
      await cubit.resolveEmailSession();
      expect(cubit.state, isA<AuthProfileIncomplete>());
    });

    test(
      'phone-era account → signed out (nothing deleted) and reported',
      () async {
        email.sessionResult = const EmailSessionResolution.legacyAccount();
        await cubit.resolveEmailSession();
        expect(email.signOutCalls, 1);
        expect(cubit.state, isA<AuthLegacyAccountSignedOut>());
      },
    );

    test('profile unavailable → AuthProfileUnavailable with the real '
        'reason, never AuthSuccess', () async {
      email.refreshResult = const EmailSessionResolution.profileUnavailable(
        'ahmed@example.com',
        ProfileFailure.permissionDenied,
      );
      final states = await record(() => cubit.refreshEmailVerification());
      expect(states.whereType<AuthSuccess>(), isEmpty);
      final state = cubit.state as AuthProfileUnavailable;
      expect(state.failure, ProfileFailure.permissionDenied);
      expect(state.email, 'ahmed@example.com');
    });

    test('a silent check that finds the profile unavailable still reports it '
        '(it is no longer just "pending")', () async {
      email.refreshResult = const EmailSessionResolution.profileUnavailable(
        'ahmed@example.com',
        ProfileFailure.network,
      );
      await cubit.refreshEmailVerification(silent: true);
      expect(cubit.state, isA<AuthProfileUnavailable>());
    });

    test('no session → AuthSignedOut', () async {
      await cubit.resolveEmailSession();
      expect(cubit.state, isA<AuthSignedOut>());
    });

    test('registration always continues to verification and reports whether '
        'the first email was sent', () async {
      email.registerResult = const EmailSessionResolution.pendingVerification(
        'new@example.com',
        verificationEmailSent: false,
      );
      await cubit.registerWithEmail(
        name: 'Ahmed',
        email: 'new@example.com',
        password: 'secret1',
      );
      final state = cubit.state as AuthEmailVerificationRequired;
      expect(state.verificationEmailSent, isFalse);
    });
  });

  group('Domain-boundary validation (never only in the UI)', () {
    test(
      'register normalizes inputs and keeps the password byte-for-byte',
      () async {
        await cubit.registerWithEmail(
          name: '  Ahmed   Emad ',
          email: '  Ahmed@Example.COM ',
          password: 'my pass phrase',
          languageCode: 'ar',
        );
        expect(email.lastRegisterName, 'Ahmed Emad');
        expect(email.lastRegisterEmail, 'ahmed@example.com');
        expect(email.lastRegisterPassword, 'my pass phrase');
        expect(email.lastLanguageCode, 'ar');
      },
    );

    test('invalid email, weak password, blank name are rejected before the '
        'repository is called', () async {
      await cubit.registerWithEmail(
        name: 'A',
        email: 'not-an-email',
        password: 'secret1',
      );
      await cubit.registerWithEmail(
        name: 'A',
        email: 'a@example.com',
        password: '123',
      );
      await cubit.registerWithEmail(
        name: '  ',
        email: 'a@example.com',
        password: 'secret1',
      );
      expect(email.registerCalls, 0);
      expect(cubit.state, isA<AuthError>());
    });

    test('the reserved phone-era domain can be used neither to register nor '
        'to sign in', () async {
      await cubit.registerWithEmail(
        name: 'A',
        email: 'u201012345678@ae-coaching.app',
        password: 'secret1',
      );
      await cubit.loginWithEmail(
        email: 'u201012345678@ae-coaching.app',
        password: 'secret1',
      );
      expect(email.registerCalls, 0);
      expect(email.loginCalls, 0);
    });

    test('login trims the password for existing accounts, and the new '
        'password policy does not apply to sign-in', () async {
      await cubit.loginWithEmail(email: 'a@example.com', password: ' 12 ');
      expect(email.lastLoginPassword, '12');
    });

    test('password reset and email change validate the address', () async {
      await cubit.sendPasswordResetEmail(email: 'bad');
      await cubit.requestEmailChange(newEmail: 'bad');
      expect(email.passwordResetCalls, 0);
      expect(email.emailChangeCalls, 0);
    });
  });

  group('Verification refresh', () {
    test('explicit refresh still unverified → AuthEmailVerificationRequired '
        '(the screen reports "not verified yet")', () async {
      await cubit.refreshEmailVerification();
      expect(cubit.state, isA<AuthEmailVerificationRequired>());
    });

    test('explicit refresh verified → AuthSuccess', () async {
      email.refreshResult = const EmailSessionResolution.authenticated(
        verifiedUser,
      );
      await cubit.refreshEmailVerification();
      expect(
        (cubit.state as AuthSuccess).message,
        'Email verified successfully',
      );
    });

    test('silent refresh (app resumed) emits nothing while unverified and '
        'swallows errors', () async {
      final quiet = await record(
        () => cubit.refreshEmailVerification(silent: true),
      );
      expect(quiet, isEmpty);

      email.errorToThrow = Exception('Network error.');
      final failed = await record(
        () => cubit.refreshEmailVerification(silent: true),
      );
      expect(failed, isEmpty);
    });

    test(
      'silent refresh that finds the email verified enters the app',
      () async {
        email.refreshResult = const EmailSessionResolution.authenticated(
          verifiedUser,
        );
        await cubit.refreshEmailVerification(silent: true);
        expect(cubit.state, isA<AuthSuccess>());
      },
    );

    test('a silent check never interrupts an explicit one in flight', () async {
      email.hold = Completer<void>();
      final explicit = cubit.refreshEmailVerification();
      await cubit.refreshEmailVerification(silent: true);
      email.hold!.complete();
      await explicit;
      expect(email.refreshCalls, 1);
    });
  });

  group('Duplicate taps and lifecycle safety', () {
    test('double-tapping Create Account creates one account', () async {
      email.hold = Completer<void>();
      final a = cubit.registerWithEmail(
        name: 'A',
        email: 'a@example.com',
        password: 'secret1',
      );
      final b = cubit.registerWithEmail(
        name: 'A',
        email: 'a@example.com',
        password: 'secret1',
      );
      email.hold!.complete();
      await Future.wait([a, b]);
      expect(email.registerCalls, 1);
    });

    test('double-tapping Resend sends one email', () async {
      email.hold = Completer<void>();
      final a = cubit.resendVerificationEmail();
      final b = cubit.resendVerificationEmail();
      email.hold!.complete();
      await Future.wait([a, b]);
      expect(email.resendCalls, 1);
      expect(cubit.state, isA<AuthVerificationEmailSent>());
    });

    test('a result arriving after the screen closed is dropped', () async {
      final local = buildAuthCubit(email);
      email.hold = Completer<void>();
      final pending = local.loginWithEmail(
        email: 'a@example.com',
        password: 'p',
      );
      await local.close();
      email.hold!.complete();
      await expectLater(pending, completes);
    });

    test('sign out ends the session through the email repository', () async {
      await cubit.signOut();
      expect(email.signOutCalls, 1);
      expect(cubit.state, isA<AuthSignedOut>());
    });
  });

  test('password reset reports the normalized address for the neutral '
      'confirmation', () async {
    await cubit.sendPasswordResetEmail(email: ' Someone@Example.com ');
    expect(
      (cubit.state as AuthPasswordResetEmailSent).email,
      'someone@example.com',
    );
  });

  test('email change reports where the link went', () async {
    await cubit.requestEmailChange(newEmail: 'New@Example.com');
    expect(
      (cubit.state as AuthEmailChangeRequested).newEmail,
      'new@example.com',
    );
  });
}
