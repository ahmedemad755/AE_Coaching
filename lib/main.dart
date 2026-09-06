import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/features/progress_photos/data/models/progress_photo.dart';
import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart'; // تأكد من المسار الصحيح
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:firebase_core/firebase_core.dart'; // سطر مهم جداً
import 'package:ae_coaching/firebase_options.dart'; // لو بتستخدم flutterfire configure

void main() async {
  // 1. التأكد من تهيئة الـ Widgets
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. تهيئة Firebase (هذا السطر هو الحل!)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. تشغيل الـ Service Locator
  initAuth();
  initWorkout();
  initMeasurements(); // Body Measurements feature — separate from Workout
  initProgressPhotos(); // Progress Photos feature — separate from both

  // 4. تهيئة Hive
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ExerciseSetAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(BodyMeasurementAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(ProgressPhotoAdapter());
  }

  await Hive.openBox('authBox');

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
