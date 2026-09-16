import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';

/// Aggregate, all-time stats for one exercise within one workout day —
/// "how has Bench Press trended across every Push 1 I've ever done",
/// as opposed to [ExerciseProgressResult] (Phase 11), which only ever
/// compares the current session to the single previous one.
class ExerciseAnalyticsSummary {
  final String exerciseName;

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

  const ExerciseAnalyticsSummary({
    required this.exerciseName,
    required this.sessionsLogged,
    required this.bestSetVolume,
    required this.bestWeight,
    required this.latestVolume,
    required this.firstVolume,
    required this.overallDeltaPercent,
  });
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

    for (final template in templates) {
      final sessions = List<WorkoutSession>.from(completedSessionsByTemplate[template.id] ?? const [])
        ..sort((a, b) => (a.completedAt ?? a.date).compareTo(b.completedAt ?? b.date)); // oldest first

      final averageVolume =
          sessions.isEmpty ? 0.0 : sessions.map((s) => s.totalVolume).reduce((a, b) => a + b) / sessions.length;

      days.add(WorkoutDayAnalyticsSummary(
        workoutTemplateId: template.id,
        workoutTemplateName: template.name,
        completedSessionsCount: sessions.length,
        averageSessionVolume: averageVolume,
        exercises: _buildExerciseSummaries(sessions, setsBySessionId),
      ));
    }

    return ProgramAnalyticsSummary(programId: programId, days: days);
  }

  List<ExerciseAnalyticsSummary> _buildExerciseSummaries(
    List<WorkoutSession> sessionsOldestFirst,
    Map<String, List<ExerciseSet>> setsBySessionId,
  ) {
    // exerciseName -> ordered list of (session, sets-for-that-exercise)
    final bySessionForExercise = <String, List<MapEntry<WorkoutSession, List<ExerciseSet>>>>{};
    final firstSeenOrder = <String>[];

    for (final session in sessionsOldestFirst) {
      final sets = setsBySessionId[session.id] ?? const <ExerciseSet>[];
      final byExerciseInSession = <String, List<ExerciseSet>>{};
      for (final set in sets) {
        byExerciseInSession.putIfAbsent(set.exerciseName, () => []).add(set);
      }
      for (final entry in byExerciseInSession.entries) {
        if (!bySessionForExercise.containsKey(entry.key)) {
          firstSeenOrder.add(entry.key);
        }
        bySessionForExercise.putIfAbsent(entry.key, () => []).add(MapEntry(session, entry.value));
      }
    }

    return [
      for (final exerciseName in firstSeenOrder)
        _summarizeExercise(exerciseName, bySessionForExercise[exerciseName]!),
    ];
  }

  ExerciseAnalyticsSummary _summarizeExercise(
    String exerciseName,
    List<MapEntry<WorkoutSession, List<ExerciseSet>>> occurrencesOldestFirst,
  ) {
    final allSets = occurrencesOldestFirst.expand((e) => e.value).toList();

    final bestSetVolume = allSets.map(_setVolume).reduce(_max);
    final bestWeight = allSets.map((s) => s.weight).reduce(_max);

    final firstVolume = _volumeOf(occurrencesOldestFirst.first.value);
    final latestVolume = _volumeOf(occurrencesOldestFirst.last.value);

    final isSingleOccurrence = occurrencesOldestFirst.length == 1;
    final overallDeltaPercent =
        isSingleOccurrence || firstVolume == 0 ? null : (latestVolume - firstVolume) / firstVolume * 100;

    return ExerciseAnalyticsSummary(
      exerciseName: exerciseName,
      sessionsLogged: occurrencesOldestFirst.length,
      bestSetVolume: bestSetVolume,
      bestWeight: bestWeight,
      latestVolume: latestVolume,
      firstVolume: firstVolume,
      overallDeltaPercent: overallDeltaPercent,
    );
  }

  double _setVolume(ExerciseSet set) => set.weight * set.reps;
  double _volumeOf(List<ExerciseSet> sets) => sets.fold(0.0, (sum, s) => sum + s.weight * s.reps);
  double _max(double a, double b) => a > b ? a : b;
}
