import 'package:ae_coaching/auth/presentation/auth_flow_navigation.dart';
import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/view/LoginView.dart';
import 'package:ae_coaching/features/analytics/presentation/workout_analytics_screen.dart';
import 'package:ae_coaching/auth/presentation/view/forgot_password_view.dart';
import 'package:ae_coaching/auth/presentation/view/complete_profile_view.dart';
import 'package:ae_coaching/auth/presentation/view/register_view.dart';
import 'package:ae_coaching/auth/presentation/view/verify_email_view.dart';
import 'package:ae_coaching/auth/presentation/view/session_reconciliation_view.dart';
import 'package:ae_coaching/core/bootstrap/startup_destination.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/presentation/screens/standard_workout_templates_screen.dart';
import 'package:ae_coaching/features/measurements/presentation/cubit/measurement_cubit.dart';
import 'package:ae_coaching/features/measurements/presentation/screens/measurement_analytics_screen.dart';
import 'package:ae_coaching/features/measurements/presentation/screens/measurements_screen.dart';
import 'package:ae_coaching/features/progress_photos/presentation/cubit/progress_photo_cubit.dart';
import 'package:ae_coaching/features/progress_photos/presentation/screens/progress_photos_screen.dart';
import 'package:ae_coaching/features/views/hom.dart';
import 'package:ae_coaching/features/profile/presentation/app_settings_screen.dart';
import 'package:ae_coaching/features/profile/presentation/my_progress_screen.dart';
import 'package:ae_coaching/features/profile/presentation/progress/personal_records_screen.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_programs_screen.dart';
import 'package:ae_coaching/features/profile/presentation/progress/workout_history_screen.dart';
import 'package:ae_coaching/features/profile/presentation/personal_hub_screen.dart';
import 'package:ae_coaching/features/profile/presentation/profile_navigation.dart';
import 'package:ae_coaching/features/workout/presentation/bloc/workout_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_template_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_history_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_analytics_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_overview_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_consistency_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/home_workout_overview_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_template_history_screen.dart';
import 'package:ae_coaching/features/account_deletion/presentation/cubit/account_deletion_cubit.dart';
import 'package:ae_coaching/features/account_deletion/presentation/delete_account_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/program_analytics_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/archived_workout_days_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/active_workout_session_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_completion_summary_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_program_details_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_programs_screen.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppNavigator {
  static const String initial = '/';
  static const String login = 'login';
  static const String register = 'register';
  // Signed-out Forgot Password (email reset link since Stage 3B).
  static const String forgotPassword = 'forgot-password';
  static const String home = 'home';
  static const String personalHub = 'personal-hub';
  static const String appSettings = 'app-settings';
  static const String deleteAccount = 'delete-account';
  static const String myProgress = 'my-progress';
  // Progress detail screens, opened from the progress dashboard.
  static const String personalRecords = 'personal-records';
  static const String workoutHistory = 'workout-history';
  static const String progressPrograms = 'progress-programs';

  // Stage 3B: email-first verification gate and missing-profile recovery.
  static const String verifyEmail = 'verify-email';
  static const String completeProfile = 'complete-profile';
  // Account check opened directly (not via the startup fast path), e.g.
  // after a profile read/write failure, so its Retry state is always
  // reached.
  static const String sessionCheck = 'session-check';

  /// Routes reachable without a verified identity. Everything else is
  /// guarded by AppRouter.guardedRouteName. completeProfile is NOT
  /// public: it needs a verified identity (just no profile yet).
  static const Set<String> publicRoutes = {
    initial,
    login,
    register,
    forgotPassword,
    verifyEmail,
    sessionCheck,
  };
  static const String workoutAnalytics = 'workout-analytics';
  // Body Measurements feature — separate from Workout Analytics.
  static const String measurements = 'measurements';
  static const String measurementAnalytics = 'measurement-analytics';
  // Progress Photos feature — separate from both.
  static const String progressPhotos = 'progress-photos';
  // Programs UI (Phase 5) — separate from all of the above. Route
  // structure kept extensible for Programs → Program Details →
  // Workout Days (Phase 6).
  static const String workoutPrograms = 'workout-programs';
  static const String workoutTemplates = 'standard-workout-templates';
  static const String workoutProgramDetails = 'workout-program-details';
  // Active Workout Session (Phase 7).
  static const String activeWorkoutSession = 'active-workout-session';
  // Workout Completion Summary (Phase 13).
  static const String workoutCompletionSummary = 'workout-completion-summary';
  // Workout History (Phase 14).
  static const String workoutTemplateHistory = 'workout-template-history';
  // Program Analytics (Phase 15).
  static const String programAnalytics = 'program-analytics';
  // Archived Workout Days.
  static const String archivedWorkoutDays = 'archived-workout-days';
}

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static bool _pendingNotificationHomeNavigation = false;

  static void openHomeFromNotification() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingNotificationHomeNavigation = true;
      return;
    }
    _pendingNotificationHomeNavigation = false;
    navigator.pushNamedAndRemoveUntil(AppNavigator.home, (route) => false);
  }

  static void flushPendingNotificationNavigation() {
    if (_pendingNotificationHomeNavigation &&
        navigatorKey.currentState != null) {
      openHomeFromNotification();
    }
  }

  /// Reads Firebase Auth's persisted user for the route guard.
  /// Overridable in tests (no Firebase there).
  @visibleForTesting
  static StartupAuthSnapshot Function() readAuthSnapshot = () =>
      StartupAuthSnapshot.read(auth: FirebaseAuth.instance);

  /// Pure guard decision: the route name to actually build. Any route
  /// outside [AppNavigator.publicRoutes] needs a cleared identity
  /// (signed in, email verified, not a phone-era account). Otherwise the
  /// request is redirected to the startup check, which re-derives the
  /// correct destination. This is client-side navigation gating only;
  /// see [canEnterProtectedRoute].
  static String? guardedRouteName(
    String? requested,
    StartupAuthSnapshot snapshot,
  ) {
    if (AppNavigator.publicRoutes.contains(requested)) return requested;
    if (canEnterProtectedRoute(snapshot)) return requested;
    return AppNavigator.initial;
  }

  static Route? onGenerateRoute(RouteSettings settings) {
    final allowedName = guardedRouteName(settings.name, readAuthSnapshot());
    if (allowedName != settings.name) {
      return onGenerateRoute(RouteSettings(name: allowedName));
    }
    switch (settings.name) {
      case AppNavigator.initial:
        // فحص حالة الدخول داخل الراوتر لتحديد الصفحة الأولى
        //
        // SessionStorage wraps the same already-open authBox
        // synchronously (a plain Hive .get() under the hood) — this
        // stays a synchronous, startup-time read exactly as before;
        // nothing here became async.
        //
        // The destination comes from Firebase Auth's persisted identity
        // (authoritative), and the local marker is only a hint. No route
        // is ever restored from storage, so a stale auth screen can't come back
        // after a restart. See resolveStartupDestination for the policy.
        final destination = resolveStartupDestination(
          StartupAuthSnapshot.read(
            auth: FirebaseAuth.instance,
            sessionStorage: sl<SessionStorage>(),
          ),
        );

        switch (destination) {
          case StartupDestination.home:
            return MaterialPageRoute(builder: (_) => _homeWithProviders());
          case StartupDestination.sessionCheck:
            // A real Firebase identity whose status local state can't
            // prove: an unverified email, a missing profile, a phone-era
            // test account, or a session the marker doesn't cover.
            return MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (context) => sl<AuthCubit>(),
                child: const SessionReconciliationView(),
              ),
            );
          case StartupDestination.login:
            return MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (context) => sl<AuthCubit>(),
                child: const LoginView(),
              ),
            );
        }

      case AppNavigator.register:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: const RegisterView(),
          ),
        );

      case AppNavigator.forgotPassword:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: ForgotPasswordView(
              initialEmail: settings.arguments is String
                  ? settings.arguments as String
                  : '',
            ),
          ),
        );

      case AppNavigator.verifyEmail:
        final args = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: VerifyEmailView(
              email: args is VerifyEmailArgs ? args.email : '',
              verificationEmailSent:
                  args is VerifyEmailArgs && args.verificationEmailSent,
            ),
          ),
        );

      case AppNavigator.sessionCheck:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: const SessionReconciliationView(),
          ),
        );

      case AppNavigator.completeProfile:
        final args = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: CompleteProfileView(
              email: args is CompleteProfileArgs ? args.email : '',
            ),
          ),
        );

      case AppNavigator.login:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: const LoginView(),
          ),
        );

      case AppNavigator.home:
        return MaterialPageRoute(builder: (_) => _homeWithProviders());

      case AppNavigator.personalHub:
        final args = settings.arguments;
        if (args is! PersonalHubArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidProfileRoute(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => PersonalHubScreen(onLogout: args.onLogout),
        );

      case AppNavigator.appSettings:
        final args = settings.arguments;
        if (args is! AppSettingsArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidProfileRoute(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => AppSettingsScreen(onLogout: args.onLogout),
        );

      case AppNavigator.deleteAccount:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<AccountDeletionCubit>()..load(),
            child: const DeleteAccountScreen(),
          ),
        );

      case AppNavigator.myProgress:
        return MaterialPageRoute(builder: (_) => const MyProgressScreen());

      case AppNavigator.personalRecords:
        final args = settings.arguments;
        if (args is! PersonalRecordsArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidPersonalRecordsRoute(),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => PersonalRecordsScreen(records: args.records),
        );

      case AppNavigator.workoutHistory:
        final args = settings.arguments;
        if (args is! WorkoutHistoryArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidWorkoutHistoryRoute(),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => WorkoutHistoryScreen(data: args.data),
        );

      case AppNavigator.progressPrograms:
        final args = settings.arguments;
        if (args is! ProgressProgramsArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidProgressProgramsRoute(),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ProgressProgramsScreen(programs: args.programs),
        );

      case AppNavigator.workoutAnalytics:
        final args = settings.arguments;
        if (args is! WorkoutAnalyticsArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidWorkoutAnalyticsRoute(),
          );
        }
        return WorkoutAnalyticsScreen.route(args);

      // Body Measurements feature — independent from Workout routes above.
      case AppNavigator.measurements:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<MeasurementCubit>(),
            child: const MeasurementsScreen(),
          ),
        );

      case AppNavigator.measurementAnalytics:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<MeasurementCubit>()..loadMeasurements(),
            child: const MeasurementAnalyticsScreen(),
          ),
        );

      // Progress Photos feature — independent from Workout/Measurement routes.
      case AppNavigator.progressPhotos:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<ProgressPhotoCubit>(),
            child: const ProgressPhotosScreen(),
          ),
        );

      // Programs UI — independent from Workout/Measurement/Photos routes.
      // Also provides the app-wide WorkoutSessionCubit singleton so the
      // Resume Workout banner reflects whether a session is active.
      case AppNavigator.workoutTemplates:
        // pushNamed<WorkoutTemplateImportResult> expects this concrete route type.
        // Navigator's Future is nullable already: cancelling returns null.
        return MaterialPageRoute<WorkoutTemplateImportResult>(
          settings: settings,
          builder: (_) => StandardWorkoutTemplatesScreen(
            templates: sl(),
            importer: sl(),
            exercises: sl<CombinedExerciseLibraryCatalog>(),
            customExercises: sl(),
          ),
        );
      case AppNavigator.workoutPrograms:
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => sl<WorkoutProgramCubit>()),
              BlocProvider.value(value: sl<WorkoutSessionCubit>()),
            ],
            child: const WorkoutProgramsScreen(),
          ),
        );

      case AppNavigator.workoutProgramDetails:
        final args = settings.arguments;
        if (args is! WorkoutProgramDetailsArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidWorkoutProgramDetailsRoute(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => sl<WorkoutTemplateCubit>()),
              BlocProvider.value(value: sl<WorkoutSessionCubit>()),
              BlocProvider(create: (context) => sl<ProgramOverviewCubit>()),
            ],
            child: WorkoutProgramDetailsScreen(program: args.program),
          ),
        );

      case AppNavigator.activeWorkoutSession:
        final args = settings.arguments;
        if (args is! ActiveWorkoutSessionArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidActiveWorkoutSessionRoute(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: sl<WorkoutSessionCubit>()),
              BlocProvider(create: (context) => sl<SessionExerciseCubit>()),
              BlocProvider(create: (context) => sl<RestTimerCubit>()),
            ],
            child: ActiveWorkoutSessionScreen(session: args.session),
          ),
        );

      case AppNavigator.workoutCompletionSummary:
        final args = settings.arguments;
        if (args is! WorkoutCompletionSummaryArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidWorkoutCompletionSummaryRoute(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => WorkoutCompletionSummaryScreen(args: args),
        );

      case AppNavigator.workoutTemplateHistory:
        final args = settings.arguments;
        if (args is! WorkoutTemplateHistoryArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidWorkoutTemplateHistoryRoute(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<WorkoutHistoryCubit>(),
            child: WorkoutTemplateHistoryScreen(template: args.template),
          ),
        );

      case AppNavigator.programAnalytics:
        final args = settings.arguments;
        if (args is! ProgramAnalyticsArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidProgramAnalyticsRoute(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (context) => sl<ProgramAnalyticsCubit>()),
              BlocProvider(create: (context) => sl<ProgramConsistencyCubit>()),
            ],
            child: ProgramAnalyticsScreen(program: args.program),
          ),
        );

      case AppNavigator.archivedWorkoutDays:
        final args = settings.arguments;
        if (args is! ArchivedWorkoutDaysArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidArchivedWorkoutDaysRoute(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<WorkoutTemplateCubit>(),
            child: ArchivedWorkoutDaysScreen(program: args.program),
          ),
        );

      default:
        return null;
    }
  }

  static Widget _homeWithProviders() {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => sl<AuthCubit>()),
        BlocProvider(create: (context) => sl<WorkoutCubit>()),
        BlocProvider.value(value: sl<WorkoutSessionCubit>()),
        BlocProvider(create: (context) => sl<HomeWorkoutOverviewCubit>()),
        BlocProvider(create: (context) => sl<WorkoutProgramCubit>()),
      ],
      child: const Hom(),
    );
  }
}

abstract class _InvalidRouteScreen extends StatelessWidget {
  final String message;

  const _InvalidRouteScreen(this.message);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _InvalidWorkoutAnalyticsRoute extends _InvalidRouteScreen {
  const _InvalidWorkoutAnalyticsRoute()
    : super('Workout analytics route requires WorkoutAnalyticsArgs.');
}

class _InvalidProfileRoute extends _InvalidRouteScreen {
  const _InvalidProfileRoute()
    : super('Profile route requires valid arguments.');
}

class _InvalidWorkoutProgramDetailsRoute extends _InvalidRouteScreen {
  const _InvalidWorkoutProgramDetailsRoute()
    : super(
        'Workout program details route requires WorkoutProgramDetailsArgs.',
      );
}

class _InvalidArchivedWorkoutDaysRoute extends _InvalidRouteScreen {
  const _InvalidArchivedWorkoutDaysRoute()
    : super('Archived workout days route requires ArchivedWorkoutDaysArgs.');
}

class _InvalidProgramAnalyticsRoute extends _InvalidRouteScreen {
  const _InvalidProgramAnalyticsRoute()
    : super('Program analytics route requires ProgramAnalyticsArgs.');
}

class _InvalidWorkoutTemplateHistoryRoute extends _InvalidRouteScreen {
  const _InvalidWorkoutTemplateHistoryRoute()
    : super('Workout history route requires WorkoutTemplateHistoryArgs.');
}

class _InvalidWorkoutCompletionSummaryRoute extends _InvalidRouteScreen {
  const _InvalidWorkoutCompletionSummaryRoute()
    : super(
        'Workout completion summary route requires WorkoutCompletionSummaryArgs.',
      );
}

class _InvalidActiveWorkoutSessionRoute extends _InvalidRouteScreen {
  const _InvalidActiveWorkoutSessionRoute()
    : super('Active workout session route requires ActiveWorkoutSessionArgs.');
}

class _InvalidPersonalRecordsRoute extends _InvalidRouteScreen {
  const _InvalidPersonalRecordsRoute()
    : super('Personal records route requires PersonalRecordsArgs.');
}

class _InvalidWorkoutHistoryRoute extends _InvalidRouteScreen {
  const _InvalidWorkoutHistoryRoute()
    : super('Workout history route requires WorkoutHistoryArgs.');
}

class _InvalidProgressProgramsRoute extends _InvalidRouteScreen {
  const _InvalidProgressProgramsRoute()
    : super('Progress programs route requires ProgressProgramsArgs.');
}
