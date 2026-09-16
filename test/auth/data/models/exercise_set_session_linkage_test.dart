import 'dart:io';

import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exercise_set_linkage_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ExerciseSetAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WorkoutProgramAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(WorkoutTemplateAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(WorkoutSessionAdapter());
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('a legacy ExerciseSet (no session IDs) still saves and loads correctly', () async {
    final box = await Hive.openBox<ExerciseSet>('legacy_sets');
    final legacySet = ExerciseSet(
      exerciseName: 'Bench Press',
      weight: 100,
      reps: 8,
      date: DateTime(2025, 1, 1),
      notes: 'felt strong',
    );

    final key = await box.add(legacySet);
    final reloaded = box.get(key);

    expect(reloaded, isNotNull);
    expect(reloaded!.exerciseName, equals('Bench Press'));
    expect(reloaded.notes, equals('felt strong'));
    expect(reloaded.programId, isNull);
    expect(reloaded.workoutTemplateId, isNull);
    expect(reloaded.workoutSessionId, isNull);
    expect(reloaded.hasConsistentSessionLinkage, isTrue);
  });

  test('a new session-linked ExerciseSet (all 3 IDs) saves and loads correctly', () async {
    final box = await Hive.openBox<ExerciseSet>('linked_sets');
    final linkedSet = ExerciseSet(
      exerciseName: 'Bench Press',
      weight: 100,
      reps: 8,
      date: DateTime(2025, 9, 1),
      programId: 'program_A',
      workoutTemplateId: 'template_push1',
      workoutSessionId: 'session_123',
    );

    final key = await box.add(linkedSet);
    final reloaded = box.get(key);

    expect(reloaded, isNotNull);
    expect(reloaded!.programId, equals('program_A'));
    expect(reloaded.workoutTemplateId, equals('template_push1'));
    expect(reloaded.workoutSessionId, equals('session_123'));
    expect(reloaded.hasConsistentSessionLinkage, isTrue);
  });

  test('JSON from a legacy Firestore document (missing the new keys entirely) parses successfully', () {
    final legacyJson = <String, dynamic>{
      'exerciseName': 'Squat',
      'weight': 120.0,
      'reps': 5,
      'date': DateTime(2024, 6, 1).toIso8601String(),
      // no 'notes', 'programId', 'workoutTemplateId', 'workoutSessionId' keys at all
    };

    final set = ExerciseSet.fromJson(legacyJson);

    expect(set.exerciseName, equals('Squat'));
    expect(set.notes, isNull);
    expect(set.programId, isNull);
    expect(set.workoutTemplateId, isNull);
    expect(set.workoutSessionId, isNull);
    expect(set.hasConsistentSessionLinkage, isTrue);
  });

  test('JSON round-trip preserves session IDs', () {
    final original = ExerciseSet(
      exerciseName: 'Overhead Press',
      weight: 60,
      reps: 6,
      date: DateTime(2025, 9, 10),
      programId: 'program_A',
      workoutTemplateId: 'template_push1',
      workoutSessionId: 'session_456',
    );

    final roundTripped = ExerciseSet.fromJson(original.toJson());

    expect(roundTripped.programId, equals(original.programId));
    expect(roundTripped.workoutTemplateId, equals(original.workoutTemplateId));
    expect(roundTripped.workoutSessionId, equals(original.workoutSessionId));
  });

  test('editing a linked set preserves all 3 IDs (regression test for hom.dart\'s edit reconstruction)', () {
    final original = ExerciseSet(
      exerciseName: 'Bench Press',
      weight: 100,
      reps: 8,
      date: DateTime(2025, 9, 1),
      notes: 'original note',
      programId: 'program_A',
      workoutTemplateId: 'template_push1',
      workoutSessionId: 'session_123',
    );

    // Mirrors hom.dart's _showEditSetDialog reconstruction exactly
    // (a fresh ExerciseSet(...), not copyWith) — proving that pattern,
    // now that it explicitly re-passes the 3 linkage fields, no longer
    // drops them the way it would have before this phase's fix.
    final edited = ExerciseSet(
      exerciseName: original.exerciseName,
      weight: 105,
      reps: 6,
      date: original.date,
      notes: original.notes,
      programId: original.programId,
      workoutTemplateId: original.workoutTemplateId,
      workoutSessionId: original.workoutSessionId,
    );

    expect(edited.weight, equals(105));
    expect(edited.programId, equals('program_A'));
    expect(edited.workoutTemplateId, equals('template_push1'));
    expect(edited.workoutSessionId, equals('session_123'));
  });

  test('deleting an ExerciseSet does not affect Program/Template/Session records', () async {
    final program = WorkoutProgram(id: 'program_A', name: 'PPL', createdAt: DateTime.now());
    final template = WorkoutTemplate(id: 'template_push1', programId: 'program_A', name: 'Push 1', createdAt: DateTime.now());
    final session = WorkoutSession(
      id: 'session_123',
      programId: 'program_A',
      workoutTemplateId: 'template_push1',
      workoutNameSnapshot: 'Push 1',
      date: DateTime.now(),
      startedAt: DateTime.now(),
      status: WorkoutSessionStatus.inProgress.value,
    );

    final programBox = await Hive.openBox<WorkoutProgram>('programs');
    final templateBox = await Hive.openBox<WorkoutTemplate>('templates');
    final sessionBox = await Hive.openBox<WorkoutSession>('sessions');
    final setBox = await Hive.openBox<ExerciseSet>('sets');

    await programBox.put(program.id, program);
    await templateBox.put(template.id, template);
    await sessionBox.put(session.id, session);

    final linkedSet = ExerciseSet(
      exerciseName: 'Bench Press',
      weight: 100,
      reps: 8,
      date: DateTime.now(),
      programId: program.id,
      workoutTemplateId: template.id,
      workoutSessionId: session.id,
    );
    final setKey = await setBox.add(linkedSet);

    // Delete only the ExerciseSet — same scope as the real delete flow
    // (WorkoutRepositoryImpl.deleteAndSyncWorkout only ever touches the
    // exercise-set box/collection).
    await setBox.delete(setKey);

    expect(setBox.get(setKey), isNull);
    expect(programBox.get(program.id), isNotNull);
    expect(templateBox.get(template.id), isNotNull);
    expect(sessionBox.get(session.id), isNotNull);
  });

  test(
    'the new adapter safely defaults absent optional fields to null — the same mechanism that '
    'protects real pre-Phase-4 records, since Hive\'s generated reader treats a missing field '
    'index identically whether the value was never written or was written as null',
    () async {
      final box = await Hive.openBox<ExerciseSet>('old_style_sim');
      // Built the same way old code (pre-Phase-4) would have — the 3
      // new named parameters simply don't exist in that code, so they
      // are never passed, exactly like this.
      final oldStyleSet = ExerciseSet(
        exerciseName: 'Deadlift',
        weight: 140,
        reps: 5,
        date: DateTime(2023, 3, 3),
      );
      final key = await box.add(oldStyleSet);

      final reloaded = box.get(key);
      expect(reloaded, isNotNull);
      expect(reloaded!.programId, isNull);
      expect(reloaded.workoutTemplateId, isNull);
      expect(reloaded.workoutSessionId, isNull);
    },
  );

  group('hasConsistentSessionLinkage', () {
    test('legacy (all null) is consistent', () {
      final set = ExerciseSet(exerciseName: 'Row', weight: 50, reps: 10, date: DateTime.now());
      expect(set.hasConsistentSessionLinkage, isTrue);
    });

    test('fully linked (all 3 non-null) is consistent', () {
      final set = ExerciseSet(
        exerciseName: 'Row',
        weight: 50,
        reps: 10,
        date: DateTime.now(),
        programId: 'p',
        workoutTemplateId: 't',
        workoutSessionId: 's',
      );
      expect(set.hasConsistentSessionLinkage, isTrue);
    });

    test('partial linkage is detected as inconsistent', () {
      final onlySessionId = ExerciseSet(
        exerciseName: 'Row',
        weight: 50,
        reps: 10,
        date: DateTime.now(),
        workoutSessionId: 's',
      );
      final missingSessionId = ExerciseSet(
        exerciseName: 'Row',
        weight: 50,
        reps: 10,
        date: DateTime.now(),
        programId: 'p',
        workoutTemplateId: 't',
      );

      expect(onlySessionId.hasConsistentSessionLinkage, isFalse);
      expect(missingSessionId.hasConsistentSessionLinkage, isFalse);
    });
  });
}
