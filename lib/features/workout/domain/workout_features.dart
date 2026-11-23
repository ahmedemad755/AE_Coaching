import 'package:flutter/foundation.dart';

/// Workout features built in stages and not released yet.
abstract final class WorkoutFeatures {
  /// The cardio paths added in Stage 3: "Add activity" with Cardio and My
  /// library's cardio, and cardio timers in a workout (Stage 6). Off in
  /// release builds until approved for release; on in debug and profile
  /// builds. Whatever this says,
  /// cardio activities already saved (e.g. synced from a development build)
  /// are always read and shown safely.
  static bool get cardioActivities => debugCardioOverride ?? !kReleaseMode;

  /// Tests only: forces [cardioActivities].
  @visibleForTesting
  static bool? debugCardioOverride;
}
