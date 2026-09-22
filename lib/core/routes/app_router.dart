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
import 'package:ae_coaching/features/measurements/presentation/cubit/measurement_cubit.dart';
import 'package:ae_coaching/features/measurements/presentation/screens/measurement_analytics_screen.dart';
import 'package:ae_coaching/features/measurements/presentation/screens/measurements_screen.dart';
import 'package:ae_coaching/features/progress_photos/presentation/cubit/progress_photo_cubit.dart';
import 'package:ae_coaching/features/progress_photos/presentation/screens/progress_photos_screen.dart';
import 'package:ae_coaching/features/views/hom.dart';
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
      ],
      child: const Hom(),
    );
  }
}

class _InvalidWorkoutAnalyticsRoute extends StatelessWidget {
  const _InvalidWorkoutAnalyticsRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Workout analytics route requires WorkoutAnalyticsArgs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidWorkoutProgramDetailsRoute extends StatelessWidget {
  const _InvalidWorkoutProgramDetailsRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Workout program details route requires WorkoutProgramDetailsArgs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidVerifyPhoneMigrationRoute extends StatelessWidget {
  const _InvalidVerifyPhoneMigrationRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Verify phone migration route requires VerifyPhoneMigrationArgs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidResetPasswordRoute extends StatelessWidget {
  const _InvalidResetPasswordRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Reset password route requires ResetPasswordArgs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidCompleteRegistrationRoute extends StatelessWidget {
  const _InvalidCompleteRegistrationRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Complete registration route requires CompleteRegistrationArgs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidArchivedWorkoutDaysRoute extends StatelessWidget {
  const _InvalidArchivedWorkoutDaysRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Archived workout days route requires ArchivedWorkoutDaysArgs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidProgramAnalyticsRoute extends StatelessWidget {
  const _InvalidProgramAnalyticsRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Program analytics route requires ProgramAnalyticsArgs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidWorkoutTemplateHistoryRoute extends StatelessWidget {
  const _InvalidWorkoutTemplateHistoryRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Workout history route requires WorkoutTemplateHistoryArgs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidWorkoutCompletionSummaryRoute extends StatelessWidget {
  const _InvalidWorkoutCompletionSummaryRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Workout completion summary route requires WorkoutCompletionSummaryArgs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidActiveWorkoutSessionRoute extends StatelessWidget {
  const _InvalidActiveWorkoutSessionRoute();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Active workout session route requires ActiveWorkoutSessionArgs.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
