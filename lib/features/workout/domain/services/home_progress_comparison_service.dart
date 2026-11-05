import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';

class HomeExerciseSessionVolume {
  final String sessionId;
  final DateTime completedAt;
  final double volume;

  const HomeExerciseSessionVolume({
    required this.sessionId,
    required this.completedAt,
    required this.volume,
  });
}

class HomeExerciseProgressHistory {
  final String programId;
  final String programName;
  final String workoutTemplateId;
  final String workoutTemplateName;
  final String exerciseKey;
  final String exerciseName;
  final List<HomeExerciseSessionVolume> sessions;

  const HomeExerciseProgressHistory({
    required this.programId,
    required this.programName,
    required this.workoutTemplateId,
    required this.workoutTemplateName,
    required this.exerciseKey,
    required this.exerciseName,
    required this.sessions,
  });

  double get currentVolume => sessions.last.volume;
  double? get previousVolume =>
      sessions.length < 2 ? null : sessions[sessions.length - 2].volume;
}

/// Builds Home's exercise comparisons only from sets linked to completed,
/// valid program/template sessions. Unlinked legacy sets are intentionally
/// excluded because their workout day cannot be inferred reliably.
class HomeProgressComparisonService {
  const HomeProgressComparisonService();

  List<HomeExerciseProgressHistory> build({
    required List<WorkoutProgram> programs,
    required List<WorkoutTemplate> templates,
    required List<WorkoutSession> sessions,
    required List<ExerciseSet> sets,
  }) {
    final programsById = {for (final program in programs) program.id: program};
    final templatesById = {
      for (final template in templates) template.id: template,
    };
    final setsBySession = <String, List<ExerciseSet>>{};
    for (final set in sets) {
      final sessionId = set.workoutSessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        setsBySession.putIfAbsent(sessionId, () => []).add(set);
      }
    }

    final grouped = <String, _HistoryBuilder>{};
    for (final session in sessions.where((item) => item.isCompleted)) {
      final program = programsById[session.programId];
      final template = templatesById[session.workoutTemplateId];
      if (program == null ||
          template == null ||
          template.programId != program.id) {
        continue;
      }

      final byExercise = <String, List<ExerciseSet>>{};
      for (final set in setsBySession[session.id] ?? const <ExerciseSet>[]) {
        if (set.programId != session.programId ||
            set.workoutTemplateId != session.workoutTemplateId ||
            set.workoutSessionId != session.id) {
          continue;
        }
        final exerciseKey = set.exerciseName.trim().toLowerCase();
        if (exerciseKey.isEmpty) continue;
        byExercise.putIfAbsent(exerciseKey, () => []).add(set);
      }

      for (final entry in byExercise.entries) {
        final key =
            '${session.programId}\u0000${session.workoutTemplateId}\u0000${entry.key}';
        final history = grouped.putIfAbsent(
          key,
          () => _HistoryBuilder(
            programId: program.id,
            programName: program.name,
            workoutTemplateId: template.id,
            workoutTemplateName: template.name,
            exerciseKey: entry.key,
            exerciseName: entry.value.first.exerciseName.trim(),
          ),
        );
        final volume = entry.value.fold<double>(
          0,
          (total, set) => total + set.weight * set.reps,
        );
        history.sessions.add(
          HomeExerciseSessionVolume(
            sessionId: session.id,
            completedAt: session.completedAt ?? session.date,
            volume: volume,
          ),
        );
      }
    }

    final result =
        grouped.values.map((history) {
          history.sessions.sort(
            (a, b) => a.completedAt.compareTo(b.completedAt),
          );
          return history.toHistory();
        }).toList()..sort((a, b) {
          final programOrder = a.programName.compareTo(b.programName);
          if (programOrder != 0) return programOrder;
          final templateOrder = a.workoutTemplateName.compareTo(
            b.workoutTemplateName,
          );
          if (templateOrder != 0) return templateOrder;
          return a.exerciseName.compareTo(b.exerciseName);
        });
    return result;
  }
}

class _HistoryBuilder {
  final String programId;
  final String programName;
  final String workoutTemplateId;
  final String workoutTemplateName;
  final String exerciseKey;
  final String exerciseName;
  final List<HomeExerciseSessionVolume> sessions = [];

  _HistoryBuilder({
    required this.programId,
    required this.programName,
    required this.workoutTemplateId,
    required this.workoutTemplateName,
    required this.exerciseKey,
    required this.exerciseName,
  });

  HomeExerciseProgressHistory toHistory() => HomeExerciseProgressHistory(
    programId: programId,
    programName: programName,
    workoutTemplateId: workoutTemplateId,
    workoutTemplateName: workoutTemplateName,
    exerciseKey: exerciseKey,
    exerciseName: exerciseName,
    sessions: List.unmodifiable(sessions),
  );
}
