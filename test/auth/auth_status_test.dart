import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:ae_coaching/auth/domain/entities/email_session_resolution.dart';
import 'package:flutter_test/flutter_test.dart';

/// The state machine's vocabulary. Every login, registration, startup and
/// refresh produces one of these, and AuthCubit maps each one to exactly
/// one state (email_auth_cubit_test.dart).
void main() {
  test('AuthStatus is exactly the email-first set (no phone-era states)', () {
    expect(AuthStatus.values.toSet(), {
      AuthStatus.unauthenticated,
      AuthStatus.authenticated,
      AuthStatus.pendingEmailVerification,
      AuthStatus.incompleteProfile,
      AuthStatus.unsupportedLegacyAccount,
      AuthStatus.profileUnavailable,
    });
  });

  group('EmailSessionResolution carries only what its status needs', () {
    test('authenticated carries the user, never a failure', () {
      const r = EmailSessionResolution.authenticated(
        AuthUser(uid: 'u', name: 'Ahmed', email: 'a@example.com'),
      );
      expect(r.status, AuthStatus.authenticated);
      expect(r.user!.uid, 'u');
      expect(r.profileFailure, isNull);
    });

    test('pending verification carries the email and whether it was sent, '
        'but no user', () {
      const r = EmailSessionResolution.pendingVerification(
        'a@example.com',
        verificationEmailSent: true,
      );
      expect(r.status, AuthStatus.pendingEmailVerification);
      expect(r.email, 'a@example.com');
      expect(r.verificationEmailSent, isTrue);
      expect(r.user, isNull);
    });

    test('incomplete profile carries the email, no user', () {
      const r = EmailSessionResolution.incompleteProfile('a@example.com');
      expect(r.status, AuthStatus.incompleteProfile);
      expect(r.user, isNull);
    });

    test('profile unavailable carries the real reason, no user', () {
      for (final failure in ProfileFailure.values) {
        final r = EmailSessionResolution.profileUnavailable(
          'a@example.com',
          failure,
        );
        expect(r.status, AuthStatus.profileUnavailable);
        expect(r.profileFailure, failure);
        expect(r.user, isNull);
      }
    });

    test('legacy and unauthenticated carry no user', () {
      expect(
        const EmailSessionResolution.legacyAccount().status,
        AuthStatus.unsupportedLegacyAccount,
      );
      expect(const EmailSessionResolution.legacyAccount().user, isNull);
      expect(
        const EmailSessionResolution.unauthenticated().status,
        AuthStatus.unauthenticated,
      );
    });
  });
}
