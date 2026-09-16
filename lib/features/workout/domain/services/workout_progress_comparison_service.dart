import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';

/// How one exercise's volume this session compares to the previous
/// same-template session.
enum PerformanceTrend {
  /// No previous data for this exact exercise — nothing to compare
  /// against yet, not a positive or negative signal.
  newExercise,
  improved,
  maintained,
  declined,
}

/// One exercise's comparison for the currently-active/just-finished
/// session against the previous COMPLETED session of the SAME
/// program + workout template.
class ExerciseProgressResult {
  final String exerciseName;
  final List<ExerciseSet> currentSets;
  final List<ExerciseSet> previousSets;

  final double currentVolume;
  final double? previousVolume;
  final double? currentMaxWeight;
  final double? previousMaxWeight;
  final PerformanceTrend trend;

  /// Percentage change in volume vs. last time, e.g. `12.5` for a
  /// +12.5% increase. Null when there is no previous volume to divide
  /// by (new exercise, or a previous volume of exactly 0).
  final double? volumeDeltaPercent;

  const ExerciseProgressResult({
    required this.exerciseName,
    required this.currentSets,
    required this.previousSets,
    required this.currentVolume,
    required this.previousVolume,
    required this.currentMaxWeight,
    required this.previousMaxWeight,
    required this.trend,
    required this.volumeDeltaPercent,
  });
}

/// Whole-workout comparison: "Since Latest" (this session vs. the one
/// immediately before it, same program + template) plus a per-exercise
/// breakdown. "Overall" trend across every session for this template
/// is deliberately out of scope here — see Phase 15/16's analytics
/// work for longer-range aggregation; this service only ever looks at
/// exactly one previous session at a time.
class WorkoutProgressSummary {
  final String sessionId;
  final String? previousSessionId;

  final double currentTotalVolume;
  final double? previousTotalVolume;
  final double? volumeDeltaPercent;

  /// Only exercises actually logged in the CURRENT session — a
  /// suggested-but-never-logged reference exercise has no current data
  /// to compare, so it never appears here.
  final List<ExerciseProgressResult> exerciseResults;

  const WorkoutProgressSummary({
    required this.sessionId,
    required this.previousSessionId,
    required this.currentTotalVolume,
    required this.previousTotalVolume,
    required this.volumeDeltaPercent,
    required this.exerciseResults,
  });

  bool get hasPreviousSession => previousSessionId != null;
}

/// Pure comparison logic — no Hive/Firestore access of its own. The
/// caller (a future Cubit/screen) is responsible for fetching
/// [currentSession]/[currentSets] and the previous completed session's
/// data (typically via [WorkoutSessionRepository.getPreviousCompletedSession]
/// + [SessionExerciseRepository]); keeping data access out of this
/// class is what makes the comparison math trivially unit-testable and
/// reusable from both the in-progress screen (Phase 9) and the
/// completion summary (Phase 13).
///
/// Defends the one rule that must never break — Push 1 must never be
/// compared to Push 2 — in two ways: [previousSession], if given, MUST
/// share [currentSession]'s programId + workoutTemplateId (an
/// [ArgumentError] otherwise, since that would be a caller bug, not a
/// normal "no previous data" case); and every input set list is
/// filtered down to sets that actually belong to the session they were
/// passed for, so a caller accidentally handing over an entire user's
/// sets box still produces a correct, isolated comparison.
class WorkoutProgressComparisonService {
  const WorkoutProgressComparisonService();

  WorkoutProgressSummary compare({
    required WorkoutSession currentSession,
    required List<ExerciseSet> currentSets,
    WorkoutSession? previousSession,
    List<ExerciseSet> previousSets = const [],
  }) {
    if (previousSession != null &&
        (previousSession.programId != currentSession.programId ||
            previousSession.workoutTemplateId != currentSession.workoutTemplateId)) {
      throw ArgumentError(
        'WorkoutProgressComparisonService.compare was given a previousSession '
        '(programId=${previousSession.programId}, workoutTemplateId=${previousSession.workoutTemplateId}) '
        "that doesn't match currentSession (programId=${currentSession.programId}, "
        'workoutTemplateId=${currentSession.workoutTemplateId}). Comparing across different '
        'workout days is never allowed.',
      );
    }

    final currentScoped = currentSets.where((s) => s.workoutSessionId == currentSession.id).toList();
    final previousScoped = previousSession == null
        ? const <ExerciseSet>[]
        : previousSets.where((s) => s.workoutSessionId == previousSession.id).toList();

    final currentByExercise = _groupByExercise(currentScoped);
    final previousByExercise = _groupByExercise(previousScoped);

    final exerciseResults = <ExerciseProgressResult>[
      for (final entry in currentByExercise.entries)
        _compareExercise(entry.key, entry.value, previousByExercise[entry.key] ?? const []),
    ];

    final currentTotalVolume = _volumeOf(currentScoped);
    final previousTotalVolume = previousSession == null ? null : _volumeOf(previousScoped);

    return WorkoutProgressSummary(
      sessionId: currentSession.id,
      previousSessionId: previousSession?.id,
      currentTotalVolume: currentTotalVolume,
      previousTotalVolume: previousTotalVolume,
      volumeDeltaPercent: _deltaPercent(currentTotalVolume, previousTotalVolume),
      exerciseResults: exerciseResults,
    );
  }

  ExerciseProgressResult _compareExercise(
    String exerciseName,
    List<ExerciseSet> currentSets,
    List<ExerciseSet> previousSets,
  ) {
    final currentVolume = _volumeOf(currentSets);
    final previousVolume = previousSets.isEmpty ? null : _volumeOf(previousSets);
    final currentMaxWeight = currentSets.isEmpty ? null : currentSets.map((s) => s.weight).reduce(_max);
    final previousMaxWeight = previousSets.isEmpty ? null : previousSets.map((s) => s.weight).reduce(_max);

    PerformanceTrend trend;
    if (previousVolume == null) {
      trend = PerformanceTrend.newExercise;
    } else if (currentVolume > previousVolume) {
      trend = PerformanceTrend.improved;
    } else if (currentVolume == previousVolume) {
      trend = PerformanceTrend.maintained;
    } else {
      trend = PerformanceTrend.declined;
    }

    return ExerciseProgressResult(
      exerciseName: exerciseName,
      currentSets: currentSets,
      previousSets: previousSets,
      currentVolume: currentVolume,
      previousVolume: previousVolume,
      currentMaxWeight: currentMaxWeight,
      previousMaxWeight: previousMaxWeight,
      trend: trend,
      volumeDeltaPercent: _deltaPercent(currentVolume, previousVolume),
    );
  }

  /// Groups by exercise name preserving first-appearance order — same
  /// convention as [SessionExerciseRepository.getExerciseNamesForSession].
  Map<String, List<ExerciseSet>> _groupByExercise(List<ExerciseSet> sets) {
    final grouped = <String, List<ExerciseSet>>{};
    for (final set in sets) {
      grouped.putIfAbsent(set.exerciseName, () => []).add(set);
    }
    return grouped;
  }

  double _volumeOf(List<ExerciseSet> sets) {
    return sets.fold(0.0, (sum, s) => sum + s.weight * s.reps);
  }

  double _max(double a, double b) => a > b ? a : b;

  double? _deltaPercent(double current, double? previous) {
    if (previous == null || previous == 0) return null;
    return (current - previous) / previous * 100;
  }
}
