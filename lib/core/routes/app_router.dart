import 'package:ae_coaching/auth/presentation/cubit/auth_cubit.dart';
import 'package:ae_coaching/auth/presentation/view/LoginView.dart';
import 'package:ae_coaching/features/analytics/presentation/workout_analytics_screen.dart';
import 'package:ae_coaching/auth/presentation/view/otp_view.dart';
import 'package:ae_coaching/auth/presentation/view/register_view.dart';
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
import 'package:hive_flutter/hive_flutter.dart';

class AppNavigator {
  static const String initial = '/';
  static const String otp = 'otp';
  static const String login = 'login';
  static const String register = 'register';
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
        final authBox = Hive.box('authBox');
        final bool isLoggedIn = authBox.get('isLoggedIn', defaultValue: false);
        final String currentUserUid =
            authBox.get('currentUserUid', defaultValue: '');
        final firebaseUser = FirebaseAuth.instance.currentUser;
        final bool hasActiveSession = isLoggedIn &&
            currentUserUid.trim().isNotEmpty &&
            firebaseUser != null &&
            firebaseUser.uid == currentUserUid.trim();
        return MaterialPageRoute(
          builder: (_) => hasActiveSession
              ? _homeWithProviders()
              : BlocProvider(
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
        return MaterialPageRoute(
          builder: (_) => _homeWithProviders(),
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
