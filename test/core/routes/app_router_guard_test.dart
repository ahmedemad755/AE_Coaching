import 'package:ae_coaching/core/bootstrap/startup_destination.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

/// The email-auth route guard must cover every route of the integrated
/// app (RepDB, programs, templates, active workout, Personal Hub, My
/// Progress, Settings, measurements, photos, history), not only the
/// routes the auth branch knew about.
void main() {
  const protectedRoutes = [
    AppNavigator.home,
    AppNavigator.personalHub,
    AppNavigator.appSettings,
    AppNavigator.myProgress,
    AppNavigator.completeProfile,
    AppNavigator.workoutAnalytics,
    AppNavigator.measurements,
    AppNavigator.measurementAnalytics,
    AppNavigator.progressPhotos,
    AppNavigator.workoutPrograms,
    AppNavigator.workoutTemplates,
    AppNavigator.workoutProgramDetails,
    AppNavigator.activeWorkoutSession,
    AppNavigator.workoutCompletionSummary,
    AppNavigator.workoutTemplateHistory,
    AppNavigator.programAnalytics,
    AppNavigator.archivedWorkoutDays,
  ];

  const signedOut = StartupAuthSnapshot(firebaseUid: null);
  const unverified = StartupAuthSnapshot(
    firebaseUid: 'u1',
    firebaseEmail: 'user@example.com',
    firebaseEmailVerified: false,
  );
  const phoneEra = StartupAuthSnapshot(
    firebaseUid: 'legacy',
    firebaseEmail: '201012345678@ae-coaching.app',
    firebaseEmailVerified: true,
  );
  const verified = StartupAuthSnapshot(
    firebaseUid: 'u1',
    firebaseEmail: 'user@example.com',
    firebaseEmailVerified: true,
  );

  test('no protected route is accidentally public', () {
    for (final route in protectedRoutes) {
      expect(AppNavigator.publicRoutes.contains(route), isFalse, reason: route);
    }
  });

  for (final entry in {
    'signed-out': signedOut,
    'unverified': unverified,
    'phone-era': phoneEra,
  }.entries) {
    test('a ${entry.key} user is redirected to the startup check from every '
        'protected route', () {
      for (final route in protectedRoutes) {
        expect(
          AppRouter.guardedRouteName(route, entry.value),
          AppNavigator.initial,
          reason: route,
        );
      }
    });
  }

  test('a verified user reaches every protected route unchanged', () {
    for (final route in protectedRoutes) {
      expect(AppRouter.guardedRouteName(route, verified), route);
    }
  });

  test('public auth routes stay reachable for an unverified user', () {
    for (final route in AppNavigator.publicRoutes) {
      expect(AppRouter.guardedRouteName(route, unverified), route);
    }
  });
}
