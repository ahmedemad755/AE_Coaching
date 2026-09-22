import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/features/progress_photos/data/models/progress_photo.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/firebase_options.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Centralizes the app's startup sequence, previously inlined directly
/// in `main()`. Every step below is a direct, behavior-preserving
/// extraction — nothing about what each step does, or the order they
/// run in, has changed. `main.dart` now calls only
/// [AppBootstrap.initialize] before `runApp`.
///
/// Order (unchanged from before this stage): Firebase → App Check → DI
/// registrations → Hive init → guarded adapter registration → authBox
/// open. DI registration was already entirely lazy (every
/// `service_locator.dart` registration is `registerLazySingleton`/
/// `registerFactory`, never eager), so running it before Hive is set up
/// was never a live bug — nothing resolves a dependency until a widget
/// does, well after `runApp()`. That's preserved as-is rather than
/// reordered, since there's no verified lifecycle bug to correct.
class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    // Must be the first thing that runs — before any `await`, exactly
    // as it was the first statement in `main()` before this extraction.
    WidgetsFlutterBinding.ensureInitialized();

    await _initializeFirebase();
    _initializeDependencies();
    await _initializeStorage();
  }

  static Future<void> _initializeFirebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

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
  }

  static void _initializeDependencies() {
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
  }

  static Future<void> _initializeStorage() async {
    await Hive.initFlutter();
    registerHiveAdapters();
    await Hive.openBox('authBox');
  }

  /// The 6 guarded `Hive.registerAdapter` calls, extracted on their own
  /// so they can be exercised by a real test against a disposable Hive
  /// instance (no Firebase involved) rather than only proven by reading
  /// source text. Idempotent — safe to call more than once, exactly as
  /// it was inline in `main()` before this extraction (each call is
  /// still guarded by `isAdapterRegistered`).
  @visibleForTesting
  static void registerHiveAdapters() {
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
  }
}
