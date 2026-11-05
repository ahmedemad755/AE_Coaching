import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/view/LoginView.dart';
import 'package:ae_coaching/features/analytics/presentation/workout_analytics_screen.dart';
import 'package:ae_coaching/auth/presentation/view/complete_registration_view.dart';
import 'package:ae_coaching/auth/presentation/view/forgot_password_view.dart';
import 'package:ae_coaching/auth/presentation/view/otp_view.dart';
import 'package:ae_coaching/auth/presentation/view/register_view.dart';
import 'package:ae_coaching/auth/presentation/view/reset_password_view.dart';
import 'package:ae_coaching/auth/presentation/view/session_reconciliation_view.dart';
import 'package:ae_coaching/auth/presentation/view/verify_phone_migration_view.dart';
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
  static const String otp = 'otp';
  static const String login = 'login';
  static const String register = 'register';
  // Phase 3: cross-restart resume for an interrupted OTP registration.
  static const String completeRegistration = 'complete-registration';
  // Phase 4: legacy user phone-provider migration, shown after a
  // successful password login when no phone provider is linked yet.
  static const String verifyPhoneMigration = 'verify-phone-migration';
  // Phase 5: signed-out Forgot Password (phone OTP based).
  static const String forgotPassword = 'forgot-password';
  static const String resetPassword = 'reset-password';
  static const String home = 'home';
  static const String personalHub = 'personal-hub';
  static const String appSettings = 'app-settings';
  static const String myProgress = 'my-progress';
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

  static Route? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppNavigator.initial:
        // فحص حالة الدخول داخل الراوتر لتحديد الصفحة الأولى
        //
        // SessionStorage wraps the same already-open authBox
        // synchronously (a plain Hive .get() under the hood) — this
        // stays a synchronous, startup-time read exactly as before;
        // nothing here became async.
        final sessionStorage = sl<SessionStorage>();
        final bool isLoggedIn = sessionStorage.isLoggedIn;
        final String currentUserUid = sessionStorage.currentUserUid;
        final firebaseUser = FirebaseAuth.instance.currentUser;
        final bool hasActiveSession =
            isLoggedIn &&
            currentUserUid.trim().isNotEmpty &&
            firebaseUser != null &&
            firebaseUser.uid == currentUserUid.trim();

        if (hasActiveSession) {
          return MaterialPageRoute(builder: (_) => _homeWithProviders());
        }

        if (firebaseUser != null) {
          // Hive says logged out, but a real Firebase session exists
          // underneath — a stray or partially-completed Phase 3 OTP
          // registration. Reconcile it before deciding where to route,
          // instead of silently leaving it under a logged-out UI.
          return MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (context) => sl<AuthCubit>(),
              child: const SessionReconciliationView(),
            ),
          );
        }

        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: const LoginView(),
          ),
        );

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
            child: const ForgotPasswordView(),
          ),
        );

      case AppNavigator.resetPassword:
        final args = settings.arguments;
        if (args is! ResetPasswordArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidResetPasswordRoute(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: ResetPasswordView(
              phone: args.phone,
              challengeId: args.challengeId,
            ),
          ),
        );

      case AppNavigator.completeRegistration:
        final args = settings.arguments;
        if (args is! CompleteRegistrationArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidCompleteRegistrationRoute(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: CompleteRegistrationView(step: args.step, phone: args.phone),
          ),
        );

      case AppNavigator.verifyPhoneMigration:
        final args = settings.arguments;
        if (args is! VerifyPhoneMigrationArgs) {
          return MaterialPageRoute(
            builder: (_) => const _InvalidVerifyPhoneMigrationRoute(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: VerifyPhoneMigrationView(
              uid: args.uid,
              name: args.name,
              phone: args.phone,
            ),
          ),
        );

      case AppNavigator.otp:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (context) => sl<AuthCubit>(),
            child: OtpView(
              phoneNumber: args['phone'],
              password: args['password'],
              verificationId: args['verificationId'],
              name: args['name'], // 🔥 ضفنا استقبال الاسم هنا
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

      case AppNavigator.myProgress:
        return MaterialPageRoute(builder: (_) => const MyProgressScreen());

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

class _InvalidVerifyPhoneMigrationRoute extends _InvalidRouteScreen {
  const _InvalidVerifyPhoneMigrationRoute()
    : super('Verify phone migration route requires VerifyPhoneMigrationArgs.');
}

class _InvalidResetPasswordRoute extends _InvalidRouteScreen {
  const _InvalidResetPasswordRoute()
    : super('Reset password route requires ResetPasswordArgs.');
}

class _InvalidCompleteRegistrationRoute extends _InvalidRouteScreen {
  const _InvalidCompleteRegistrationRoute()
    : super('Complete registration route requires CompleteRegistrationArgs.');
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
