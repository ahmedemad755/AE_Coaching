import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/features/progress_photos/data/models/progress_photo.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart'; // تأكد من المسار الصحيح
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart'; // سطر مهم جداً
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:ae_coaching/firebase_options.dart'; // لو بتستخدم flutterfire configure

void main() async {
  // 1. التأكد من تهيئة الـ Widgets
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تهيئة Firebase (هذا السطر هو الحل!)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Phase 5B: the trusted password-reset backend enforces App Check on
  // both callable functions. In debug builds this uses the Android
  // debug provider (prints a token to the console that must be
  // registered in Firebase Console for local testing — not done as
  // part of this stage). Release builds are wired to Play Integrity in
  // CODE, but actually functioning still requires enabling the Play
  // Integrity API and registering the release signing
  // certificate/Play App Signing fingerprint in Firebase Console — a
  // separate, later, human step, not performed here. iOS/Web App Check
  // providers are intentionally left unconfigured in this stage (out
  // of scope).
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
  );

  // 3. تشغيل الـ Service Locator
  initCore(); // SessionStorage — cross-cutting, used by auth views, Hom, and WorkoutCubit
  initAuth();
  initWorkout();
  initMeasurements(); // Body Measurements feature — separate from Workout
  initProgressPhotos(); // Progress Photos feature — separate from both
  initWorkoutPrograms(); // Programs UI (Phase 5) — separate from all of the above
  initWorkoutTemplates(); // Workout Days UI (Phase 6) — separate from all of the above
  initWorkoutCascadeDeletion(); // Cascade delete (Program/Template → Session → Set)
  initWorkoutSessions(); // Active Workout Session (Phase 7) — separate from all of the above
  initSessionExercises(); // Session exercise logging (Phase 8) — separate from all of the above
  initWorkoutHistory(); // Workout History (Phase 14) — separate from all of the above
  initProgramAnalytics(); // Program Analytics (Phase 15) — separate from all of the above
  initProgramOverview(); // Program Overview (Phase 16) — separate from all of the above
  initRestTimer(); // Rest Timer (Phase 17) — separate from all of the above
  initProgramConsistency(); // Program Consistency (Phase 19) — separate from all of the above
  initHomeWorkoutOverview(); // Home Workout Overview redesign — separate from all of the above

  // 4. تهيئة Hive
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ExerciseSetAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(WorkoutProgramAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(BodyMeasurementAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(ProgressPhotoAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(WorkoutTemplateAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(WorkoutSessionAdapter());
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
