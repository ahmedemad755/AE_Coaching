import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/domain/services/personal_record_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseSet _set(String exerciseName, double weight, int reps, {DateTime? date}) {
  return ExerciseSet(exerciseName: exerciseName, weight: weight, reps: reps, date: date ?? DateTime(2025, 1, 1));
}

void main() {
  const service = PersonalRecordDetectionService();

  test('the very first time an exercise is ever logged counts as a PR (previousBest is 0)', () {
    final results = service.detect(
      newSets: [_set('Bench Press', 60, 8)],
      historicalSets: const [],
    );

    expect(results, hasLength(2)); // heaviestWeight + highestSetVolume, both first-time
    expect(results.every((r) => r.previousBest == 0), isTrue);
    expect(results.every((r) => r.improvementPercent == null), isTrue);
  });

  test('a heavier weight than ever before is a heaviestWeight PR', () {
    final results = service.detect(
      newSets: [_set('Bench Press', 65, 5)],
      historicalSets: [_set('Bench Press', 60, 8), _set('Bench Press', 55, 10)],
    );

    final weightPr = results.firstWhere((r) => r.type == PersonalRecordType.heaviestWeight);
    expect(weightPr.previousBest, equals(60));
    expect(weightPr.newBest, equals(65));
    expect(weightPr.improvementPercent, closeTo(8.33, 0.01));
  });

  test('matching (not exceeding) the previous best weight is NOT a PR', () {
    final results = service.detect(
      newSets: [_set('Bench Press', 60, 8)],
      historicalSets: [_set('Bench Press', 60, 10)], // same weight, higher previous volume too
    );

    expect(results.where((r) => r.type == PersonalRecordType.heaviestWeight), isEmpty);
    expect(results.where((r) => r.type == PersonalRecordType.highestSetVolume), isEmpty);
  });

  test('a lighter weight but higher single-set volume is a highestSetVolume PR without a weight PR', () {
    final results = service.detect(
      newSets: [_set('Bench Press', 50, 12)], // volume 600
      historicalSets: [_set('Bench Press', 60, 8)], // weight PR = 60, volume PR = 480
    );

    expect(results.where((r) => r.type == PersonalRecordType.heaviestWeight), isEmpty);
    final volumePr = results.singleWhere((r) => r.type == PersonalRecordType.highestSetVolume);
    expect(volumePr.previousBest, equals(480));
    expect(volumePr.newBest, equals(600));
  });

  test('when multiple new sets are logged for the same exercise, only the single best counts', () {
    final results = service.detect(
      newSets: [
        _set('Bench Press', 60, 8),
        _set('Bench Press', 65, 5), // heaviest of the batch
        _set('Bench Press', 62.5, 6),
      ],
      historicalSets: [_set('Bench Press', 60, 8)],
    );

    final weightPr = results.singleWhere((r) => r.type == PersonalRecordType.heaviestWeight);
    expect(weightPr.newBest, equals(65));
  });

  test(
    'PR detection is global across programs/templates by design — the same exercise name '
    'anywhere in history counts, unlike WorkoutProgressComparisonService',
    () {
      // historicalSets simulates sets logged under a completely
      // different program/template than the caller is about to log
      // newSets for — the service itself takes no programId/
      // workoutTemplateId at all, so there is nothing to accidentally
      // scope incorrectly.
      final results = service.detect(
        newSets: [_set('Bench Press', 70, 5)],
        historicalSets: [_set('Bench Press', 60, 8)],
      );

      expect(results.any((r) => r.type == PersonalRecordType.heaviestWeight), isTrue);
    },
  );

  test('an unrelated exercise\'s history never affects a different exercise\'s PR check', () {
    final results = service.detect(
      newSets: [_set('Squat', 100, 5)],
      historicalSets: [_set('Bench Press', 200, 10)], // much higher numbers, different exercise
    );

    final squatResult = results.firstWhere((r) => r.exerciseName == 'Squat');
    expect(squatResult.previousBest, equals(0)); // Squat has no history of its own
  });
}
