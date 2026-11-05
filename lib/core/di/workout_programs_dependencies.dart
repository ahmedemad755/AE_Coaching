import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/features/workout/data/repositories/active_workout_edit_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/legacy_exercise_migration.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ae_coaching/features/workout/data/repositories/standard_workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/core/notifications/inactivity_reminder_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_cascade_deletion_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_template_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_history_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_analytics_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_overview_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_consistency_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/home_workout_overview_cubit.dart';

/// The Program/Template/Session/SessionExercise stack (Phase 5+) — one
/// cohesive dependency subgraph. Kept in a single file rather than
/// split further because these 11 registrations cross-reference each
/// other's repositories extensively (Program, Template, Session, and
/// SessionExercise repositories are each consumed by 2–5 of the
/// Cubits/services below); splitting further would only add cross-file
/// coupling without a real ownership boundary to show for it.

// Workout Programs feature (Phase 5 UI) — completely separate from
// Workout/Measurements/Progress Photos. Only touches
// `workout_programs_$uid` via WorkoutProgramRepository (already built
// in Phase 1).
void initWorkoutPrograms() {
  sl.registerLazySingleton(
    () => CustomExerciseRepository(storageManager: sl()),
  );
  sl.registerLazySingleton(() => ExerciseCatalogRepository());
  sl.registerLazySingleton(
    () => CombinedExerciseLibraryCatalog(
      builtInCatalog: sl(),
      customExercises: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => WorkoutProgramRepository(storageManager: sl()),
  );

  sl.registerFactory(
    () => WorkoutProgramCubit(repository: sl(), deletionService: sl()),
  );
}

// Workout Days UI (Phase 6) — separate from all of the above. Only
// touches `workout_templates_$uid` via WorkoutTemplateRepository
// (already built in Phase 2).
void initWorkoutTemplates() {
  sl.registerLazySingleton(
    () => WorkoutTemplateRepository(storageManager: sl()),
  );

  sl.registerFactory(
    () => WorkoutTemplateCubit(
      repository: sl(),
      deletionService: sl(),
      migrateCatalogReferences: () async {
        await sl<LegacyExerciseMigration>().migrate();
      },
    ),
  );
  sl.registerLazySingleton(
    () => LegacyExerciseMigration(
      templates: sl(),
      sessions: sl(),
      catalog: sl(),
      currentUserId: () => FirebaseAuth.instance.currentUser?.uid,
    ),
  );
  sl.registerLazySingleton(
    () => StandardWorkoutTemplateRepository(catalog: sl()),
  );
  sl.registerLazySingleton(
    () => WorkoutTemplateImportService(
      programs: sl(),
      templates: sl(),
      catalog: sl(),
      currentUserId: () => FirebaseAuth.instance.currentUser?.uid,
    ),
  );
}

// Cascade delete (Program/Template → Session → ExerciseSet). Shared by
// WorkoutProgramCubit and WorkoutTemplateCubit — one instance,
// composing the same repository singletons those Cubits already use.
void initWorkoutCascadeDeletion() {
  sl.registerLazySingleton(
    () => WorkoutCascadeDeletionService(
      programRepository: sl(),
      templateRepository: sl(),
      sessionRepository: sl(),
      setRepository: sl(),
    ),
  );
}

// Active Workout Session (Phase 7) — separate from all of the above.
// Registered as a Cubit SINGLETON (not a factory): "is a workout
// currently active" is a cross-cutting, app-wide concern shared by the
// Programs hub, Workout Days screen, and the active-session screen —
// they must all observe the exact same instance to stay in sync.
void initWorkoutSessions() {
  sl.registerLazySingleton(
    () => WorkoutSessionRepository(
      storageManager: sl(),
      inactivityReminderRecorder: sl<InactivityReminderService>(),
    ),
  );
  sl.registerLazySingleton(() => WorkoutSessionCubit(repository: sl()));
}

// Session exercise logging (Phase 8) — separate registration since this
// Cubit is screen-scoped (one active-session screen at a time), unlike
// the app-wide WorkoutSessionCubit singleton above.
void initSessionExercises() {
  sl.registerLazySingleton(
    () => SessionExerciseRepository(storageManager: sl()),
  );
  sl.registerFactory(
    () => SessionExerciseCubit(
      repository: sl(),
      sessionRepository: sl(),
      editService: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => ActiveWorkoutEditService(sessions: sl(), templates: sl(), sets: sl()),
  );
}

// Workout History (Phase 14) — screen-scoped, read-only. Reuses the
// already-registered WorkoutSessionRepository/SessionExerciseRepository
// singletons rather than creating new instances.
void initWorkoutHistory() {
  sl.registerFactory(
    () => WorkoutHistoryCubit(sessionRepository: sl(), setRepository: sl()),
  );
}

// Program Analytics (Phase 15) — screen-scoped, read-only. Reuses the
// already-registered Template/Session/Set repository singletons.
void initProgramAnalytics() {
  sl.registerFactory(
    () => ProgramAnalyticsCubit(
      templateRepository: sl(),
      sessionRepository: sl(),
      setRepository: sl(),
    ),
  );
}

// Program Overview (Phase 16) — screen-scoped, read-only "This Week"
// summary. Reuses the already-registered Template/Session repository
// singletons.
void initProgramOverview() {
  sl.registerFactory(
    () =>
        ProgramOverviewCubit(templateRepository: sl(), sessionRepository: sl()),
  );
}

// Rest Timer (Phase 17) — screen-scoped, in-memory only, no storage.
void initRestTimer() {
  sl.registerFactory(() => RestTimerCubit());
}

// Program Consistency (Phase 19) — screen-scoped, read-only. Reuses
// the already-registered WorkoutSessionRepository singleton.
void initProgramConsistency() {
  sl.registerFactory(() => ProgramConsistencyCubit(sessionRepository: sl()));
}

// Home Workout Overview — redesigned Home workout section, reusing
// the already-registered Program/Template/Session/Set repository
// singletons. Screen-scoped factory (Hom is a single long-lived
// screen, but a fresh factory instance is still the established
// pattern for every other screen-scoped Cubit in this feature).
void initHomeWorkoutOverview() {
  sl.registerFactory(
    () => HomeWorkoutOverviewCubit(
      sessionRepository: sl(),
      programRepository: sl(),
      templateRepository: sl(),
      setRepository: sl(),
    ),
  );
}
