import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';

/// Which kind of personal record was broken.
enum PersonalRecordType {
  /// The heaviest weight ever lifted for this exercise, at any rep
  /// count.
  heaviestWeight,

  /// The highest single-set volume (weight × reps) ever logged for
  /// this exercise — catches e.g. "10kg heavier for fewer reps" cases
  /// that [heaviestWeight] alone would miss as a meaningful effort PR.
  highestSetVolume,
}

/// One broken record, produced by [PersonalRecordDetectionService.detect].
class PersonalRecordResult {
  final String exerciseName;
  final PersonalRecordType type;

  /// The newly-logged set that broke the record.
  final ExerciseSet recordSet;

  /// The best value known before [recordSet] — `0` when the user has
  /// never logged this exercise before at all (a legitimate "first
  /// time ever" PR, not an error state).
  final double previousBest;

  final double newBest;

  const PersonalRecordResult({
    required this.exerciseName,
    required this.type,
    required this.recordSet,
    required this.previousBest,
    required this.newBest,
  });

  /// `null` when there was no previous best to compare against (first
  /// time doing this exercise) — showing "+infinity%" would be
  /// meaningless, so the UI should render this case as "first PR"
  /// instead of a percentage.
  double? get improvementPercent => previousBest <= 0 ? null : (newBest - previousBest) / previousBest * 100;
}

/// Detects personal records by comparing newly-logged sets against a
/// user's entire prior history for that exact exercise name.
///
/// Deliberately global across programs/workout templates — unlike
/// [WorkoutProgressComparisonService] (which strictly compares one
/// session only to the immediately-previous session of the SAME
/// program + template, per the app's Push-1-must-never-compare-to-
/// Push-2 rule), a Personal Record is inherently about the exercise
/// itself: "the most I have ever bench pressed", regardless of which
/// program or workout day it happened in. Matching is by exact
/// [ExerciseSet.exerciseName] string (case-sensitive) — the same
/// identity already used everywhere else in this feature (Programs,
/// Templates, Sessions); it does not fold case the way the legacy
/// `hom.dart` analytics view does.
///
/// No Hive/Firestore access of its own — the caller supplies both
/// [newSets] and [historicalSets], keeping this class a pure,
/// trivially-testable comparison, same shape as
/// [WorkoutProgressComparisonService].
class PersonalRecordDetectionService {
  const PersonalRecordDetectionService();

  /// [historicalSets] should be every ExerciseSet the user has ever
  /// logged for the relevant exercise(s) BEFORE [newSets] — the caller
  /// decides the exact source (e.g. every set in Hive except the
  /// current session's), but must not include any of [newSets]
  /// themselves or the comparison would compare a set against itself.
  ///
  /// Returns at most two [PersonalRecordResult]s per distinct exercise
  /// name found in [newSets] (one per [PersonalRecordType]) — only when
  /// a new set strictly exceeds the previous best; a tie is not a
  /// record.
  List<PersonalRecordResult> detect({
    required List<ExerciseSet> newSets,
    required List<ExerciseSet> historicalSets,
  }) {
    final newByExercise = <String, List<ExerciseSet>>{};
    for (final set in newSets) {
      newByExercise.putIfAbsent(set.exerciseName, () => []).add(set);
    }

    final historicalByExercise = <String, List<ExerciseSet>>{};
    for (final set in historicalSets) {
      historicalByExercise.putIfAbsent(set.exerciseName, () => []).add(set);
    }

    final results = <PersonalRecordResult>[];

    for (final entry in newByExercise.entries) {
      final exerciseName = entry.key;
      final candidateSets = entry.value;
      final history = historicalByExercise[exerciseName] ?? const [];

      final previousMaxWeight = history.isEmpty ? 0.0 : history.map((s) => s.weight).reduce(_max);
      final previousMaxSetVolume = history.isEmpty ? 0.0 : history.map(_setVolume).reduce(_max);

      final bestNewWeightSet = candidateSets.reduce((a, b) => a.weight >= b.weight ? a : b);
      if (bestNewWeightSet.weight > previousMaxWeight) {
        results.add(PersonalRecordResult(
          exerciseName: exerciseName,
          type: PersonalRecordType.heaviestWeight,
          recordSet: bestNewWeightSet,
          previousBest: previousMaxWeight,
          newBest: bestNewWeightSet.weight,
        ));
      }

      final bestNewVolumeSet = candidateSets.reduce((a, b) => _setVolume(a) >= _setVolume(b) ? a : b);
      final bestNewVolume = _setVolume(bestNewVolumeSet);
      if (bestNewVolume > previousMaxSetVolume) {
        results.add(PersonalRecordResult(
          exerciseName: exerciseName,
          type: PersonalRecordType.highestSetVolume,
          recordSet: bestNewVolumeSet,
          previousBest: previousMaxSetVolume,
          newBest: bestNewVolume,
        ));
      }
    }

    return results;
  }

  double _setVolume(ExerciseSet set) => set.weight * set.reps;
  double _max(double a, double b) => a > b ? a : b;
}
