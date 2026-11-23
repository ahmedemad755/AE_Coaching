import 'package:ae_coaching/core/bootstrap/startup_destination.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

StartupAuthSnapshot _snap({
  String? uid,
  String email = 'ahmed@example.com',
  bool verified = true,
  bool password = true,
  bool marked = false,
  String markerUid = '',
}) => StartupAuthSnapshot(
  firebaseUid: uid,
  firebaseEmail: email,
  firebaseEmailVerified: verified,
  firebaseUsesPassword: password,
  localSessionMarked: marked,
  localSessionUid: markerUid,
);

void main() {
  group('Startup: no Firebase identity → Login', () {
    test('fresh install', () {
      expect(resolveStartupDestination(_snap()), StartupDestination.login);
    });

    test('a stale local marker is NOT proof of a session', () {
      expect(
        resolveStartupDestination(_snap(marked: true, markerUid: 'uid-1')),
        StartupDestination.login,
      );
    });

    test('blank uid is treated as no identity', () {
      expect(
        resolveStartupDestination(_snap(uid: '  ')),
        StartupDestination.login,
      );
    });
  });

  group('Startup: verified session → Home (offline-capable)', () {
    test('identity + matching marker + verified email', () {
      expect(
        resolveStartupDestination(
          _snap(uid: 'uid-1', marked: true, markerUid: 'uid-1'),
        ),
        StartupDestination.home,
      );
    });

    test('federated (non-password) account needs no app-side verification', () {
      expect(
        resolveStartupDestination(
          _snap(
            uid: 'uid-1',
            password: false,
            verified: false,
            marked: true,
            markerUid: 'uid-1',
          ),
        ),
        StartupDestination.home,
      );
    });
  });

  group('Startup: anything local state cannot prove → session check', () {
    test('UNVERIFIED email never opens Home, even with a matching marker', () {
      expect(
        resolveStartupDestination(
          _snap(
            uid: 'uid-1',
            verified: false,
            marked: true,
            markerUid: 'uid-1',
          ),
        ),
        StartupDestination.sessionCheck,
      );
    });

    test(
      'app killed on Verify Email after registering: identity, no marker',
      () {
        expect(
          resolveStartupDestination(_snap(uid: 'uid-1', verified: false)),
          StartupDestination.sessionCheck,
        );
      },
    );

    test('phone-era test account (synthetic email) never opens Home, even '
        'with the marker an older build wrote', () {
      expect(
        resolveStartupDestination(
          _snap(
            uid: 'legacy',
            email: 'u201012345678@ae-coaching.app',
            marked: true,
            markerUid: 'legacy',
          ),
        ),
        StartupDestination.sessionCheck,
      );
    });

    test("account switch: the marker belongs to another uid, so the previous "
        "user's session is never reused", () {
      expect(
        resolveStartupDestination(
          _snap(uid: 'uid-2', marked: true, markerUid: 'uid-1'),
        ),
        StartupDestination.sessionCheck,
      );
    });

    test('verified identity whose marker was never written (e.g. missing '
        'profile, or a crash right after verifying)', () {
      expect(
        resolveStartupDestination(_snap(uid: 'uid-1')),
        StartupDestination.sessionCheck,
      );
    });
  });

  group('Route guard: verification cannot be bypassed through navigation', () {
    final unverified = _snap(uid: 'uid-1', verified: false);
    final verified = _snap(uid: 'uid-1');
    final legacy = _snap(uid: 'l', email: 'u2010@ae-coaching.app');
    final signedOut = _snap();

    const protectedRoutes = [
      AppNavigator.home,
      AppNavigator.workoutPrograms,
      AppNavigator.measurements,
      AppNavigator.progressPhotos,
      AppNavigator.activeWorkoutSession,
      AppNavigator.completeProfile,
      'some-future-route',
    ];

    for (final route in protectedRoutes) {
      test('"$route" is redirected to startup for unverified, legacy and '
          'signed-out sessions', () {
        for (final s in [unverified, legacy, signedOut]) {
          expect(AppRouter.guardedRouteName(route, s), AppNavigator.initial);
        }
      });

      test('"$route" is allowed for a verified identity', () {
        expect(AppRouter.guardedRouteName(route, verified), route);
      });
    }

    test('auth routes stay reachable without a verified identity', () {
      for (final route in [
        AppNavigator.initial,
        AppNavigator.login,
        AppNavigator.register,
        AppNavigator.forgotPassword,
        AppNavigator.verifyEmail,
        AppNavigator.sessionCheck,
      ]) {
        expect(AppRouter.guardedRouteName(route, unverified), route);
        expect(AppRouter.guardedRouteName(route, signedOut), route);
      }
    });

    test('retired phone-era route names generate nothing', () {
      final original = AppRouter.readAuthSnapshot;
      AppRouter.readAuthSnapshot = () => verified;
      addTearDown(() => AppRouter.readAuthSnapshot = original);
      for (final route in [
        'otp',
        'verify-phone-migration',
        'complete-registration',
        'reset-password',
      ]) {
        expect(
          AppRouter.onGenerateRoute(RouteSettings(name: route)),
          isNull,
          reason: route,
        );
      }
    });
  });
}
