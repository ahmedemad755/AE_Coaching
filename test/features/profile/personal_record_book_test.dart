import 'package:ae_coaching/features/profile/domain/personal_record_book.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/domain/services/personal_record_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseSet _set(String exercise, double weight, int reps, DateTime date) =>
    ExerciseSet(exerciseName: exercise, weight: weight, reps: reps, date: date);

void main() {
  test(
    'one entry per exercise; heaviest weight and best single set kept apart',
    () {
      final book = PersonalRecordBook.fromSets([
        _set('Bench Press', 80, 10, DateTime(2026, 10, 1)), // 800: best set
        _set('Bench Press', 100, 3, DateTime(2026, 10, 8)), // heaviest
        _set('Bench Press', 90, 5, DateTime(2026, 10, 15)),
        _set('Squat', 120, 5, DateTime(2026, 10, 3)),
      ]);

      expect(book.exercises.map((e) => e.exerciseName), [
        'Bench Press',
        'Squat',
      ]);
      final bench = book.exercises.first;
      expect(bench.heaviestWeight!.type, PersonalRecordType.heaviestWeight);
      expect(bench.heaviestWeight!.newBest, 100);
      expect(bench.heaviestWeight!.recordSet.reps, 3);
      expect(bench.heaviestWeight!.recordSet.date, DateTime(2026, 10, 8));
      expect(bench.bestSetVolume!.type, PersonalRecordType.highestSetVolume);
      expect(bench.bestSetVolume!.newBest, 800);
      expect(bench.bestSetVolume!.recordSet.date, DateTime(2026, 10, 1));
      expect(bench.latestAt, DateTime(2026, 10, 8));
      expect(book.recordCount, 4);
    },
  );

  test('body-weight-only exercises have no record (nothing misleading)', () {
    final book = PersonalRecordBook.fromSets([
      _set('Push-up', 0, 20, DateTime(2026, 10, 1)),
    ]);
    expect(book.isEmpty, isTrue);
  });

  test('a tie keeps the first time the record was reached', () {
    final book = PersonalRecordBook.fromSets([
      _set('Row', 60, 8, DateTime(2026, 10, 1)),
      _set('Row', 60, 8, DateTime(2026, 10, 9)),
    ]);
    expect(
      book.exercises.single.heaviestWeight!.recordSet.date,
      DateTime(2026, 10, 1),
    );
  });

  test(
    'latest(3): newest records first, weight before volume on the same set',
    () {
      final book = PersonalRecordBook.fromSets([
        _set('A', 50, 10, DateTime(2026, 10, 1)),
        _set('B', 60, 10, DateTime(2026, 10, 5)),
        _set('C', 70, 10, DateTime(2026, 10, 3)),
      ]);
      final latest = book.latest(3);
      expect(latest, hasLength(3));
      expect(latest.map((r) => r.exerciseName), ['B', 'B', 'C']);
      expect(latest.map((r) => r.type), [
        PersonalRecordType.heaviestWeight,
        PersonalRecordType.highestSetVolume,
        PersonalRecordType.heaviestWeight,
      ]);
      expect(book.latest(99), hasLength(6));
    },
  );

  test('search ignores case, Arabic diacritics and hamza forms', () {
    final book = PersonalRecordBook.fromSets([
      _set('Bench Press', 80, 5, DateTime(2026, 10, 1)),
      _set('ضغط صدر بالبار', 80, 5, DateTime(2026, 10, 2)),
      _set('سحب أمامي', 50, 10, DateTime(2026, 10, 3)),
    ]);
    expect(book.search('bench').map((e) => e.exerciseName), ['Bench Press']);
    expect(book.search('صدر').map((e) => e.exerciseName), ['ضغط صدر بالبار']);
    expect(book.search('امامي').map((e) => e.exerciseName), ['سحب أمامي']);
    expect(book.search('  '), hasLength(3));
    expect(book.search('deadlift'), isEmpty);
  });

  test('hundreds of exercises are grouped quickly and completely', () {
    final sets = [
      for (var i = 0; i < 400; i++)
        for (var s = 0; s < 5; s++)
          _set(
            'Exercise $i',
            20.0 + s,
            10 - s,
            DateTime(2026, 1, 1).add(Duration(days: i, hours: s)),
          ),
    ];
    final watch = Stopwatch()..start();
    final book = PersonalRecordBook.fromSets(sets);
    watch.stop();
    expect(book.exercises, hasLength(400));
    expect(book.exercises.first.exerciseName, 'Exercise 399'); // newest first
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
  });
}
