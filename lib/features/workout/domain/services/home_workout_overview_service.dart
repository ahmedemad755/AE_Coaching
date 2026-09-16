import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/domain/services/week_boundary_util.dart';

/// One completed session as shown on the Home overview — never built
/// from legacy (unlinked) ExerciseSets, only from a real
/// [WorkoutSession].
class HomeSessionSummary {
  final WorkoutSession session;

  /// The workout day this session belongs to — used for navigation
  /// ("View Session" opens the existing per-day history screen). Null
  /// only if the template record is somehow missing (it is archived,
  /// never deleted, so this should not happen in practice).
  final WorkoutTemplate? template;

  final int exerciseCount;
  final int setCount;

  /// Distinct exercise names, first-appearance order — for the
  /// optional "preview exercises" expansion.
  final List<String> exerciseNames;

  const HomeSessionSummary({
    required this.session,
    required this.template,
    required this.exerciseCount,
    required this.setCount,
    required this.exerciseNames,
  });
}

/// The active program's identity plus a real, counted "this week"
/// figure — no fabricated adherence percentage, same rule as
/// [ProgramWeeklyOverviewService]/[ProgramConsistencyService].
class HomeActiveProgramSummary {
  final WorkoutProgram program;
  final int sessionsCompletedThisWeek;

  const HomeActiveProgramSummary({required this.program, required this.sessionsCompletedThisWeek});
}

/// Everything the Home screen's workout section needs, prepared ahead
/// of time so the widget layer only ever renders already-computed
/// data (see `HomeWorkoutOverviewCubit`'s class docs for why no
/// business logic lives in `hom.dart`).
class HomeWorkoutOverview {
  /// The single in-progress session, if any — takes priority over
  /// everything else in the UI.
  final WorkoutSession? activeSession;

  final HomeActiveProgramSummary? activeProgram;

  /// The most recent completed sessions, newest first, already limited
  /// to [HomeWorkoutOverviewService]'s recent-count — across the WHOLE
  /// account, every program, every workout day (a global activity
  /// feed, not scoped to the active program).
  final List<HomeSessionSummary> recentSessions;

  const HomeWorkoutOverview({
    required this.activeSession,
    required this.activeProgram,
    required this.recentSessions,
  });

  static const empty = HomeWorkoutOverview(activeSession: null, activeProgram: null, recentSessions: []);
}

/// Builds [HomeWorkoutOverview] from already-fetched data — no
/// Hive/Firestore access of its own, same shape as every other domain
/// service in this feature.
///
/// Never fabricates a session from legacy ExerciseSets: every
/// [HomeSessionSummary] wraps a real, completed [WorkoutSession] the
/// caller fetched from [WorkoutSessionRepository] — legacy (unlinked)
/// history stays exactly where it has always lived, reachable through
/// the dedicated Legacy History screen (Phase 20), never mixed in here.
class HomeWorkoutOverviewService {
  const HomeWorkoutOverviewService();

  static const int defaultRecentLimit = 5;

  HomeWorkoutOverview build({
    required DateTime now,
    WorkoutSession? activeSession,
    WorkoutProgram? activeProgram,
    List<WorkoutSession> activeProgramCompletedSessions = const [],
    required List<WorkoutSession> allCompletedSessions,
    required Map<String, WorkoutTemplate> templatesByTemplateId,
    required Map<String, List<ExerciseSet>> setsBySessionId,
    int recentLimit = defaultRecentLimit,
  }) {
    HomeActiveProgramSummary? programSummary;
    if (activeProgram != null) {
      final weekStart = startOfWeek(now);
      final weekEnd = weekStart.add(const Duration(days: 7));
      final countThisWeek = activeProgramCompletedSessions.where((s) {
        final at = s.completedAt ?? s.date;
        return !at.isBefore(weekStart) && at.isBefore(weekEnd);
      }).length;
      programSummary = HomeActiveProgramSummary(program: activeProgram, sessionsCompletedThisWeek: countThisWeek);
    }

    final sorted = List<WorkoutSession>.from(allCompletedSessions)
      ..sort((a, b) => (b.completedAt ?? b.date).compareTo(a.completedAt ?? a.date));
    final recent = sorted.take(recentLimit);

    final summaries = <HomeSessionSummary>[
      for (final session in recent)
        _buildSummary(session, templatesByTemplateId[session.workoutTemplateId], setsBySessionId[session.id]),
    ];

    return HomeWorkoutOverview(
      activeSession: activeSession,
      activeProgram: programSummary,
      recentSessions: summaries,
    );
  }

  HomeSessionSummary _buildSummary(WorkoutSession session, WorkoutTemplate? template, List<ExerciseSet>? sets) {
    final sessionSets = sets ?? const <ExerciseSet>[];
    final exerciseNames = <String>[];
    final seen = <String>{};
    for (final set in sessionSets) {
      if (seen.add(set.exerciseName)) exerciseNames.add(set.exerciseName);
    }

    return HomeSessionSummary(
      session: session,
      template: template,
      exerciseCount: exerciseNames.length,
      setCount: sessionSets.length,
      exerciseNames: exerciseNames,
    );
  }
}
