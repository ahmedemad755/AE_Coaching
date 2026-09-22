import 'package:ae_coaching/core/bootstrap/app_bootstrap.dart';
import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  await AppBootstrap.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // LocaleCubit sits above MaterialApp so every pushed route (including
    // ones outside this file) can reach it via context.read<LocaleCubit>()
    // to toggle Arabic/English at any time.
    return BlocProvider(
      create: (_) => LocaleCubit(),
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'AE Coaching',
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            // الراوتر هو اللي هيقرر يفتح Login ولا Home بناءً على الـ Hive
            initialRoute: AppNavigator.initial,
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}
