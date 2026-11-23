import 'package:ae_coaching/features/profile/domain/workout_history_groups.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession _session(
  String id,
  DateTime completedAt, {
  String program = 'p1',
}) => WorkoutSession(
  id: id,
  programId: program,
  workoutTemplateId: 't',
  workoutNameSnapshot: id,
  date: completedAt,
  startedAt: completedAt.subtract(const Duration(hours: 1)),
  completedAt: completedAt,
  status: 'completed',
  totalVolume: 0,
);

void main() {
  final sessions = [
    _session('oct-early', DateTime(2026, 10, 2)),
    _session('nov-late', DateTime(2026, 11, 28), program: 'p2'),
    _session('nov-early', DateTime(2026, 11, 1)),
    _session('dec-2025', DateTime(2025, 12, 31, 23, 59)),
    _session('oct-late', DateTime(2026, 10, 31, 23, 59), program: 'p2'),
  ];

  test('months newest first, workouts newest first inside each month', () {
    final months = groupWorkoutHistoryByMonth(sessions);
    expect(months.map((m) => m.month), [
      DateTime(2026, 11),
      DateTime(2026, 10),
      DateTime(2025, 12),
    ]);
    expect(months[0].sessions.map((s) => s.id), ['nov-late', 'nov-early']);
    expect(months[1].sessions.map((s) => s.id), ['oct-late', 'oct-early']);
    expect(months[2].sessions.single.id, 'dec-2025');
  });

  test('program filter keeps only that program and drops empty months', () {
    final months = groupWorkoutHistoryByMonth(sessions, programId: 'p2');
    expect(months.map((m) => m.month), [
      DateTime(2026, 11),
      DateTime(2026, 10),
    ]);
    expect(months.expand((m) => m.sessions).map((s) => s.id), [
      'nov-late',
      'oct-late',
    ]);
    expect(groupWorkoutHistoryByMonth(sessions, programId: 'none'), isEmpty);
  });

  test('no workouts: no months', () {
    expect(groupWorkoutHistoryByMonth(const []), isEmpty);
  });
}
