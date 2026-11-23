import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';

/// Aggregate, all-time stats for one exercise within one workout day —
/// "how has Bench Press trended across every Push 1 I've ever done",
/// as opposed to [ExerciseProgressResult] (Phase 11), which only ever
/// compares the current session to the single previous one.
class ExerciseAnalyticsSummary {
  final String exerciseName;
  final String normalizedExerciseName;

  /// How many completed sessions (of this one template) included this
  /// exercise at least once.
  final int sessionsLogged;

  final double bestSetVolume;
  final double bestWeight;

  /// This exercise's volume in the most recent completed session that
  /// included it.
  final double latestVolume;

  /// This exercise's volume in the EARLIEST completed session that
  /// included it. Equal to [latestVolume] (and [overallDeltaPercent]
  /// null) when it has only ever appeared in one session so far.
  final double firstVolume;

  final double? overallDeltaPercent;
  final List<ExerciseSessionAnalytics> sessionMetrics;

  const ExerciseAnalyticsSummary({
    required this.exerciseName,
    required this.normalizedExerciseName,
    required this.sessionsLogged,
    required this.bestSetVolume,
    required this.bestWeight,
    required this.latestVolume,
    required this.firstVolume,
    required this.overallDeltaPercent,
    required this.sessionMetrics,
  });

  ExerciseSessionAnalytics? get latestSession =>
      sessionMetrics.isEmpty ? null : sessionMetrics.last;

  ExerciseSessionAnalytics? get previousSession => sessionMetrics.length < 2
      ? null
      : sessionMetrics[sessionMetrics.length - 2];

  double? get weightDelta => latestSession == null || previousSession == null
      ? null
      : latestSession!.maxWeight - previousSession!.maxWeight;

  double? get weightDeltaPercent =>
      _percentChange(previousSession?.maxWeight, latestSession?.maxWeight);

  double? get volumeDelta => latestSession == null || previousSession == null
      ? null
      : latestSession!.volume - previousSession!.volume;

  double? get volumeDeltaPercent =>
      _percentChange(previousSession?.volume, latestSession?.volume);

  /// Reps are compared only at a load present in both the previous and
  /// latest sessions. The heaviest exact shared load is selected.
  double? get comparableRepsWeight {
    final previous = previousSession;
    final latest = latestSession;
    if (previous == null || latest == null) return null;
    final sharedLoads =
        previous.maxRepsByWeight.keys
            .where(latest.maxRepsByWeight.containsKey)
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return sharedLoads.firstOrNull;
  }

  int? get previousComparableReps => comparableRepsWeight == null
      ? null
      : previousSession!.maxRepsByWeight[comparableRepsWeight];

  int? get latestComparableReps => comparableRepsWeight == null
      ? null
      : latestSession!.maxRepsByWeight[comparableRepsWeight];

  double? get repsDelta {
    final previous = previousComparableReps;
    final latest = latestComparableReps;
    return previous == null || latest == null
        ? null
        : (latest - previous).toDouble();
  }

  double? get repsDeltaPercent => _percentChange(
    previousComparableReps?.toDouble(),
    latestComparableReps?.toDouble(),
  );

  List<ExerciseProgressionPoint> get weightProgression => [
    for (final session in sessionMetrics)
      ExerciseProgressionPoint(session.completedAt, session.maxWeight),
  ];

  List<ExerciseProgressionPoint> get volumeProgression => [
    for (final session in sessionMetrics)
      ExerciseProgressionPoint(session.completedAt, session.volume),
  ];

  List<ExerciseProgressionPoint> get repsProgression {
    final weight = comparableRepsWeight;
    if (weight == null) return const [];
    return [
      for (final session in sessionMetrics)
        if (session.maxRepsByWeight.containsKey(weight))
          ExerciseProgressionPoint(
            session.completedAt,
            session.maxRepsByWeight[weight]!.toDouble(),
          ),
    ];
  }
}

class ExerciseSessionAnalytics {
  final String sessionId;
  final DateTime completedAt;
  final double maxWeight;
  final double volume;
  final Map<double, int> maxRepsByWeight;

  const ExerciseSessionAnalytics({
    required this.sessionId,
    required this.completedAt,
    required this.maxWeight,
    required this.volume,
    required this.maxRepsByWeight,
  });
}

class ExerciseProgressionPoint {
  final DateTime date;
  final double value;

  const ExerciseProgressionPoint(this.date, this.value);
}

double? _percentChange(double? previous, double? latest) {
  if (previous == null || latest == null || previous == 0) return null;
  return (latest - previous) / previous * 100;
}

/// Aggregate stats for one workout day (template) — every completed
/// session ever recorded for it, broken down per exercise.
class WorkoutDayAnalyticsSummary {
  final String workoutTemplateId;
  final String workoutTemplateName;
  final int completedSessionsCount;

  /// Average of each completed session's own stored `totalVolume` —
  /// trusts the value each session was completed with (Phase 10),
  /// rather than re-summing every ExerciseSet again here.
  final double averageSessionVolume;

  /// One entry per distinct exercise name ever logged in a completed
  /// session of this template, in first-appearance order across those
  /// sessions (oldest session first).
  final List<ExerciseAnalyticsSummary> exercises;

  const WorkoutDayAnalyticsSummary({
    required this.workoutTemplateId,
    required this.workoutTemplateName,
    required this.completedSessionsCount,
    required this.averageSessionVolume,
    required this.exercises,
  });
}

/// The full Program → Day → Exercise hierarchy for one program.
class ProgramAnalyticsSummary {
  final String programId;

  /// One entry per non-archived WorkoutTemplate belonging to the
  /// program, in the same order they were given to
  /// [ProgramAnalyticsService.build] (callers typically pass them
  /// already sorted by `orderIndex`, same as the Workout Days screen).
  final List<WorkoutDayAnalyticsSummary> days;

  const ProgramAnalyticsSummary({required this.programId, required this.days});
}

/// Builds the Program → Day → Exercise analytics hierarchy (Phase 15)
/// from already-fetched data — no Hive/Firestore access of its own,
/// same shape as [WorkoutProgressComparisonService] and
/// [PersonalRecordDetectionService].
///
/// Every aggregation here is scoped to one `workoutTemplateId` at a
/// time: a day's exercises are built ONLY from that day's own completed
/// sessions, via [completedSessionsByTemplate] and [setsBySessionId] —
/// there is no code path by which Push 1 and Push 2 data could end up
/// summed into the same [WorkoutDayAnalyticsSummary].
class ProgramAnalyticsService {
  const ProgramAnalyticsService();

  ProgramAnalyticsSummary build({
    required String programId,
    required List<WorkoutTemplate> templates,
    required Map<String, List<WorkoutSession>> completedSessionsByTemplate,
    required Map<String, List<ExerciseSet>> setsBySessionId,
  }) {
    final days = <WorkoutDayAnalyticsSummary>[];

    for (final template in templates.where(
      (item) => item.programId == programId,
    )) {
      final sessions =
          List<WorkoutSession>.from(
            (completedSessionsByTemplate[template.id] ?? const []).where(
              (session) =>
                  session.isCompleted &&
                  session.programId == programId &&
                  session.workoutTemplateId == template.id,
            ),
          )..sort(
            (a, b) =>
                (a.completedAt ?? a.date).compareTo(b.completedAt ?? b.date),
          );

      final averageVolume = sessions.isEmpty
          ? 0.0
          : sessions.map((s) => s.totalVolume).reduce((a, b) => a + b) /
                sessions.length;

      days.add(
        WorkoutDayAnalyticsSummary(
          workoutTemplateId: template.id,
          workoutTemplateName: template.name,
          completedSessionsCount: sessions.length,
          averageSessionVolume: averageVolume,
          exercises: _buildExerciseSummaries(
            programId,
            template,
            sessions,
            setsBySessionId,
          ),
        ),
      );
    }

    return ProgramAnalyticsSummary(programId: programId, days: days);
  }

  List<ExerciseAnalyticsSummary> _buildExerciseSummaries(
    String programId,
    WorkoutTemplate template,
    List<WorkoutSession> sessionsOldestFirst,
    Map<String, List<ExerciseSet>> setsBySessionId,
  ) {
    final byExercise = <String, _ExerciseHistory>{};

    for (final session in sessionsOldestFirst) {
      final sets = setsBySessionId[session.id] ?? const <ExerciseSet>[];
      final byExerciseInSession = <String, List<ExerciseSet>>{};
      for (final set in sets) {
        if (set.workoutSessionId != session.id ||
            set.programId != programId ||
            set.workoutTemplateId != template.id) {
          continue;
        }
        final normalizedName = set.exerciseName.trim().toLowerCase();
        if (normalizedName.isEmpty) continue;
        byExerciseInSession.putIfAbsent(normalizedName, () => []).add(set);
      }
      for (final entry in byExerciseInSession.entries) {
        final history = byExercise.putIfAbsent(
          entry.key,
          () => _ExerciseHistory(entry.value.first.exerciseName.trim()),
        );
        history.sessions.add(
          _SessionHistory(_sessionMetrics(session, entry.value), entry.value),
        );
      }
    }

    return byExercise.entries
        .map((entry) => _summarizeExercise(entry.key, entry.value))
        .toList();
  }

  ExerciseSessionAnalytics _sessionMetrics(
    WorkoutSession session,
    List<ExerciseSet> sets,
  ) {
    final maxRepsByWeight = <double, int>{};
    for (final set in sets) {
      final current = maxRepsByWeight[set.weight] ?? 0;
      if (set.reps > current) maxRepsByWeight[set.weight] = set.reps;
    }
    return ExerciseSessionAnalytics(
      sessionId: session.id,
      completedAt: session.completedAt ?? session.date,
      maxWeight: sets.map((set) => set.weight).reduce(_max),
      volume: _volumeOf(sets),
      maxRepsByWeight: Map.unmodifiable(maxRepsByWeight),
    );
  }

  ExerciseAnalyticsSummary _summarizeExercise(
    String normalizedName,
    _ExerciseHistory history,
  ) {
    final allSets = history.sessions.expand((session) => session.sets).toList();

    final bestSetVolume = allSets.map(_setVolume).reduce(_max);
    final bestWeight = allSets.map((s) => s.weight).reduce(_max);

    final firstVolume = history.sessions.first.analytics.volume;
    final latestVolume = history.sessions.last.analytics.volume;

    final isSingleOccurrence = history.sessions.length == 1;
    final overallDeltaPercent = isSingleOccurrence || firstVolume == 0
        ? null
        : (latestVolume - firstVolume) / firstVolume * 100;

    return ExerciseAnalyticsSummary(
      exerciseName: history.displayName,
      normalizedExerciseName: normalizedName,
      sessionsLogged: history.sessions.length,
      bestSetVolume: bestSetVolume,
      bestWeight: bestWeight,
      latestVolume: latestVolume,
      firstVolume: firstVolume,
      overallDeltaPercent: overallDeltaPercent,
      sessionMetrics: [
        for (final session in history.sessions) session.analytics,
      ],
    );
  }

  double _setVolume(ExerciseSet set) => set.weight * set.reps;
  double _volumeOf(List<ExerciseSet> sets) =>
      sets.fold(0.0, (sum, s) => sum + s.weight * s.reps);
  double _max(double a, double b) => a > b ? a : b;
}

class _ExerciseHistory {
  final String displayName;
  final List<_SessionHistory> sessions = [];

  _ExerciseHistory(this.displayName);
}

class _SessionHistory {
  final ExerciseSessionAnalytics analytics;
  final List<ExerciseSet> sets;

  const _SessionHistory(this.analytics, this.sets);
}
