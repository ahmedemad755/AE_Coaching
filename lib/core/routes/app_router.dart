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

      default:
        return null;
    }
  }

  static Widget _homeWithProviders() {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => sl<AuthCubit>()),
        BlocProvider(create: (context) => sl<WorkoutCubit>()),
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
