import 'package:ae_coaching/auth/presentation/auth_flow_navigation.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal app shell for auth widget tests. Destination routes are
/// replaced by labelled stubs, so a test can assert WHERE a screen
/// navigated without building Home (which needs Firebase and Hive).
Widget buildAuthTestApp({
  required WidgetBuilder root,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    onGenerateRoute: (settings) {
      Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
      switch (settings.name) {
        case '/':
          return MaterialPageRoute(builder: root, settings: settings);
        case AppNavigator.login:
          return MaterialPageRoute(builder: (_) => stub('login-screen'));
        case AppNavigator.home:
          return MaterialPageRoute(builder: (_) => stub('home-screen'));
        case AppNavigator.verifyEmail:
          final args = settings.arguments as VerifyEmailArgs;
          return MaterialPageRoute(
            builder: (_) => stub(
              'verify-email-screen email=${args.email} '
              'sent=${args.verificationEmailSent}',
            ),
          );
        case AppNavigator.completeProfile:
          final args = settings.arguments as CompleteProfileArgs;
          return MaterialPageRoute(
            builder: (_) => stub('complete-profile-screen email=${args.email}'),
          );
        case AppNavigator.forgotPassword:
          return MaterialPageRoute(
            builder: (_) => stub('forgot-screen email=${settings.arguments}'),
          );
        case AppNavigator.sessionCheck:
          return MaterialPageRoute(
            builder: (_) => stub('session-check-screen'),
          );
        case AppNavigator.register:
          return MaterialPageRoute(builder: (_) => stub('register-screen'));
      }
      return null;
    },
  );
}

/// Records sessions that would have been persisted, instead of writing
/// to Hive (real Hive I/O never completes inside testWidgets).
class PersistedSessions {
  final List<String> uids = [];
}

PersistedSessions recordPersistedSessions() {
  final recorder = PersistedSessions();
  final original = persistAuthenticatedSession;
  persistAuthenticatedSession = (user) async => recorder.uids.add(user.uid);
  addTearDown(() => persistAuthenticatedSession = original);
  return recorder;
}
