import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/domain/services/personal_record_detection_service.dart';

/// The current personal records of one exercise. Either may be missing
/// (e.g. only body-weight sets: no weight record, no volume record).
class ExercisePersonalRecords {
  const ExercisePersonalRecords({
    required this.exerciseName,
    this.heaviestWeight,
    this.bestSetVolume,
  });

  final String exerciseName;

  /// The heaviest weight ever lifted (at any rep count).
  final PersonalRecordResult? heaviestWeight;

  /// The highest weight × reps in a single set.
  final PersonalRecordResult? bestSetVolume;

  List<PersonalRecordResult> get records => [?heaviestWeight, ?bestSetVolume];

  /// When the most recent of these records was set.
  DateTime get latestAt => records
      .map((record) => record.recordSet.date)
      .reduce((a, b) => a.isAfter(b) ? a : b);
}

/// Personal records grouped by exercise, built once from
/// [PersonalRecordDetectionService] results (all-time bests) and shared by
/// the progress dashboard and the personal records screen.
class PersonalRecordBook {
  PersonalRecordBook._(this.exercises);

  /// The all-time bests of every exercise in [sets] (any program or day).
  factory PersonalRecordBook.fromSets(List<ExerciseSet> sets) =>
      PersonalRecordBook.fromResults(
        const PersonalRecordDetectionService().detect(
          newSets: sets,
          historicalSets: const [],
        ),
      );

  factory PersonalRecordBook.fromResults(List<PersonalRecordResult> results) {
    final heaviest = <String, PersonalRecordResult>{};
    final volume = <String, PersonalRecordResult>{};
    for (final result in results) {
      final target = switch (result.type) {
        PersonalRecordType.heaviestWeight => heaviest,
        PersonalRecordType.highestSetVolume => volume,
      };
      final current = target[result.exerciseName];
      if (current == null || result.newBest > current.newBest) {
        target[result.exerciseName] = result;
      }
    }
    final exercises = [
      for (final name in {...heaviest.keys, ...volume.keys})
        ExercisePersonalRecords(
          exerciseName: name,
          heaviestWeight: heaviest[name],
          bestSetVolume: volume[name],
        ),
    ]..sort(_newestFirst);
    return PersonalRecordBook._(List.unmodifiable(exercises));
  }

  static final empty = PersonalRecordBook._(const []);

  /// One entry per exercise, most recently improved first.
  final List<ExercisePersonalRecords> exercises;

  bool get isEmpty => exercises.isEmpty;

  int get recordCount =>
      exercises.fold(0, (sum, exercise) => sum + exercise.records.length);

  /// The [count] most recently set records, newest first. On the same
  /// moment, the heaviest-weight record comes first, then by exercise name
  /// (a stable order).
  List<PersonalRecordResult> latest(int count) {
    final all = [for (final exercise in exercises) ...exercise.records]
      ..sort((a, b) {
        final byDate = b.recordSet.date.compareTo(a.recordSet.date);
        if (byDate != 0) return byDate;
        final byType = a.type.index.compareTo(b.type.index);
        if (byType != 0) return byType;
        return a.exerciseName.compareTo(b.exerciseName);
      });
    return all.take(count).toList(growable: false);
  }

  /// Exercises whose name contains [query], ignoring case, Arabic
  /// diacritics and hamza forms (the same matching as the exercise search).
  List<ExercisePersonalRecords> search(String query) {
    final normalized = normalizeExerciseName(query);
    if (normalized.isEmpty) return exercises;
    return exercises
        .where(
          (exercise) =>
              normalizeExerciseName(exercise.exerciseName).contains(normalized),
        )
        .toList(growable: false);
  }

  static int _newestFirst(
    ExercisePersonalRecords a,
    ExercisePersonalRecords b,
  ) {
    final byDate = b.latestAt.compareTo(a.latestAt);
    if (byDate != 0) return byDate;
    return a.exerciseName.compareTo(b.exerciseName);
  }
}
