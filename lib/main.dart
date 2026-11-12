import 'package:ae_coaching/core/bootstrap/app_bootstrap.dart';
import 'package:ae_coaching/core/feedback/feedback_host.dart';
import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/theme/theme_cubit.dart';
import 'package:ae_coaching/core/theme/theme_preference_store.dart';
import 'package:ae_coaching/features/notification_settings/application/notification_preferences_sync.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  await AppBootstrap.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LocaleCubit(
        onLanguageChanged: (languageCode) => sl<NotificationPreferencesSync>()
            .syncCurrentAccount(languageCode: languageCode),
      ),
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          final auth = FirebaseAuth.instance;
          return BlocProvider(
            create: (_) => ThemeCubit(
              store: HiveThemePreferenceStore(Hive.box('authBox')),
              userChanges: auth.authStateChanges().map((user) => user?.uid),
              initialUid: auth.currentUser?.uid,
            ),
            child: BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, themeMode) => MaterialApp(
                navigatorKey: AppRouter.navigatorKey,
                debugShowCheckedModeBanner: false,
                title: 'AE Coaching',
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: themeMode,
                themeAnimationDuration: const Duration(milliseconds: 220),
                initialRoute: AppNavigator.initial,
                onGenerateRoute: AppRouter.onGenerateRoute,
                builder: (context, child) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    AppRouter.flushPendingNotificationNavigation();
                  });
                  final brightness = Theme.of(context).brightness;
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: AppTheme.systemUiOverlayStyle(brightness),
                    // Root-level transient feedback, above the Navigator so
                    // it survives route changes and covers every route.
                    child: AppFeedbackHost(
                      currentUser: () => auth.currentUser?.uid,
                      userChanges: auth.authStateChanges().map(
                        (user) => user?.uid,
                      ),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
