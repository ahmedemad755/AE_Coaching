import 'package:ae_coaching/features/workout/data/workout_id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('1,000 rapidly generated program ids are all unique', () {
    final ids = List.generate(1000, (_) => WorkoutIdGenerator.generate('program'));
    expect(ids.toSet().length, equals(1000));
  });

  test('1,000 rapidly generated template ids are all unique', () {
    final ids = List.generate(1000, (_) => WorkoutIdGenerator.generate('template'));
    expect(ids.toSet().length, equals(1000));
  });

  test('1,000 rapidly generated session ids are all unique', () {
    final ids = List.generate(1000, (_) => WorkoutIdGenerator.generate('session'));
    expect(ids.toSet().length, equals(1000));
  });

  test('10,000 generated ids (mixed prefixes) are all unique', () {
    final ids = <String>[
      ...List.generate(4000, (_) => WorkoutIdGenerator.generate('program')),
      ...List.generate(3000, (_) => WorkoutIdGenerator.generate('template')),
      ...List.generate(3000, (_) => WorkoutIdGenerator.generate('session')),
    ];
    expect(ids.length, equals(10000));
    expect(ids.toSet().length, equals(10000));
  });

  test('generated ids are safe as Hive keys and Firestore document ids '
      '(no slashes, dots-only, or other reserved characters)', () {
    final id = WorkoutIdGenerator.generate('program');
    expect(id, matches(RegExp(r'^[a-z0-9_]+$')));
    expect(id.contains('/'), isFalse);
    expect(id, isNot(equals('.')));
    expect(id, isNot(equals('..')));
  });

  test('reproduces the original practical failure: creating several '
      'WorkoutTemplates back-to-back never overwrites another', () async {
    // This mirrors exactly what the Phase 6 reorder test does — the
    // scenario that originally lost a template.
    final ids = <String>{};
    for (var i = 0; i < 50; i++) {
      final id = WorkoutIdGenerator.generate('template');
      expect(ids.contains(id), isFalse, reason: 'id collided on iteration $i');
      ids.add(id);
    }
    expect(ids.length, equals(50));
  });
}
