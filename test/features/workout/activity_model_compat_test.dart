import 'dart:io';

import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// A second, independent Hive instance plays the OLDER app build.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../support/legacy_hive_adapters.dart';

WorkoutTemplateExerciseAssignment _strength() =>
    WorkoutTemplateExerciseAssignment(
      assignmentId: 'a-bench',
      exerciseId: 'repdb:bench-press',
      exerciseNameSnapshot: 'بنش بار',
      referenceType: 'builtIn',
      workingSets: 3,
      targetRepsMin: 8,
      targetRepsMax: 12,
      restSeconds: 90,
    );

WorkoutTemplateExerciseAssignment _cardio() =>
    WorkoutTemplateExerciseAssignment(
      assignmentId: 'a-run',
      exerciseId: 'cardio:treadmill',
      exerciseNameSnapshot: 'جري على السير',
      referenceType: 'builtIn',
    ).withActivity(
      type: ActivityType.cardio,
      cardio: const CardioPlan(
        mode: CardioMode.countdown,
        durationSeconds: 1200,
        intensity: CardioIntensity.moderate,
        speedKmh: 5.5,
        inclinePercent: 3,
      ),
    );

WorkoutTemplateExerciseAssignment _timed() =>
    WorkoutTemplateExerciseAssignment(
      assignmentId: 'a-plank',
      exerciseId: 'repdb:plank',
      exerciseNameSnapshot: 'بلانك',
      referenceType: 'builtIn',
    ).withActivity(
      type: ActivityType.timed,
      timed: const TimedPlan(sets: 3, durationSeconds: 45, restSeconds: 60),
    );

WorkoutTemplate _day() => WorkoutTemplate(
  id: 'day-1',
  programId: 'p-1',
  name: 'يوم الدفع',
  createdAt: DateTime(2026, 11, 1, 10),
  updatedAt: DateTime(2026, 11, 2, 10),
  orderIndex: 0,
  exerciseAssignments: [_strength(), _cardio(), _timed()],
  syncData: const SyncMeta(baseRevision: 3, syncedHash: 'h').toMap(),
);

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('activity_compat_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(WorkoutTemplateAdapter());
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(CustomExerciseAdapter());
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  HiveImpl olderBuild() => HiveImpl()
    ..init(dir.path)
    ..registerAdapter(LegacyWorkoutTemplateAdapter())
    ..registerAdapter(LegacyAssignmentAdapter())
    ..registerAdapter(LegacyCustomExerciseAdapter());

  group('activity format', () {
    test('strength, cardio and timed round-trip through the cloud format', () {
      final day = _day();
      final back = WorkoutTemplate.fromCloudContent(day.toCloudContent());
      expect(back.contentFingerprint, day.contentFingerprint);
      expect(back.exerciseAssignments.map((a) => a.assignmentId), [
        'a-bench',
        'a-run',
        'a-plank',
      ]);
      expect(back.exerciseAssignments[0].type, ActivityType.strength);
      expect(back.exerciseAssignments[0].targetRepsMax, 12);
      final cardio = back.exerciseAssignments[1].cardio!;
      expect(back.exerciseAssignments[1].type, ActivityType.cardio);
      expect(cardio.mode, CardioMode.countdown);
      expect(cardio.durationSeconds, 1200);
      expect(cardio.speedKmh, 5.5);
      expect(back.exerciseAssignments[2].timed!.durationSeconds, 45);
    });

    test('a strength activity keeps only strength fields, and vice versa', () {
      final map = _strength().toActivityMap();
      expect(map.keys, containsAll(['id', 'type', 'exerciseId', 'name', 'strength']));
      expect(map.containsKey('cardio'), isFalse);
      final cardio = _cardio().toActivityMap();
      expect(cardio.containsKey('strength'), isFalse);
      expect(cardio['type'], 'cardio');
    });

    test('plans validate what can actually be executed', () {
      expect(
        () => const CardioPlan(mode: CardioMode.countdown).validate(),
        throwsArgumentError,
      );
      expect(
        () => const CardioPlan(mode: CardioMode.intervals, workSeconds: 40).validate(),
        throwsArgumentError,
      );
      const CardioPlan(
        mode: CardioMode.intervals,
        workSeconds: 40,
        intervalRestSeconds: 20,
        rounds: 8,
        warmupSeconds: 300,
      ).validate();
      expect(
        const CardioPlan(
          mode: CardioMode.intervals,
          workSeconds: 40,
          intervalRestSeconds: 20,
          rounds: 8,
          warmupSeconds: 300,
        ).plannedSeconds,
        300 + 8 * 40 + 7 * 20,
      );
      expect(() => const TimedPlan(sets: 0, durationSeconds: 30).validate(), throwsArgumentError);
    });
  });

  group('Hive: older app builds (downgrade safety)', () {
    test('an older build reads records with activities and sync state without crashing', () async {
      final box = await Hive.openBox<WorkoutTemplate>('workout_templates_u');
      await box.put('day-1', _day());
      await box.close();

      final older = olderBuild();
      final oldBox = await older.openBox<WorkoutTemplate>('workout_templates_u');
      final seen = oldBox.get('day-1')!;
      expect(seen.name, 'يوم الدفع');
      expect(seen.exerciseAssignments.map((a) => a.assignmentId), ['a-bench', 'a-run', 'a-plank']);
      expect(seen.exerciseAssignments.first.targetRepsMax, 12);
      await older.close();

      // Reading does not change anything: the new build still sees it all.
      final again = await Hive.openBox<WorkoutTemplate>('workout_templates_u');
      final day = again.get('day-1')!;
      expect(day.exerciseAssignments[1].cardio!.durationSeconds, 1200);
      expect(day.exerciseAssignments[2].timed!.sets, 3);
      expect(day.syncMeta.baseRevision, 3);
    });

    test('if an older build WRITES the day back, the local record loses what it does not know, '
        'and is no longer marked as synced (the cloud copy decides on re-upgrade)', () async {
      final box = await Hive.openBox<WorkoutTemplate>('workout_templates_u');
      await box.put('day-1', _day());
      await box.close();

      final older = olderBuild();
      final oldBox = await older.openBox<WorkoutTemplate>('workout_templates_u');
      final seen = oldBox.get('day-1')!;
      await oldBox.put('day-1', seen.copyWith(name: 'renamed on old build'));
      await older.close();

      final again = await Hive.openBox<WorkoutTemplate>('workout_templates_u');
      final day = again.get('day-1')!;
      expect(day.name, 'renamed on old build');
      expect(day.exerciseAssignments.map((a) => a.assignmentId), ['a-bench', 'a-run', 'a-plank']);
      // The older build cannot preserve fields it does not know…
      expect(day.exerciseAssignments[1].type, ActivityType.strength);
      // …but it also drops the sync state, so this record reads as never
      // synced: the engine compares it with the cloud copy (which the
      // rules protect from older builds) instead of trusting it.
      expect(day.syncMeta.isMigrated, isFalse);
    });

    test('records written by the current (older) build read as strength, unsynced', () async {
      final older = olderBuild();
      final oldBox = await older.openBox<WorkoutTemplate>('workout_templates_u');
      await oldBox.put(
        'day-1',
        WorkoutTemplate(
          id: 'day-1',
          programId: 'p-1',
          name: 'Legacy',
          createdAt: DateTime(2026),
          exerciseAssignments: [_strength()],
        ),
      );
      await older.close();

      final box = await Hive.openBox<WorkoutTemplate>('workout_templates_u');
      final day = box.get('day-1')!;
      expect(day.exerciseAssignments.single.type, ActivityType.strength);
      expect(day.exerciseAssignments.single.restSeconds, 90);
      expect(day.syncMeta.isMigrated, isFalse);
      expect(day.syncData, isNull);
    });

    test('custom exercises: both directions', () async {
      final box = await Hive.openBox<CustomExercise>('custom_exercises_u');
      await box.put(
        'c1',
        CustomExercise(
          id: 'c1',
          name: 'Sled push',
          createdAt: DateTime(2026),
          activityType: 'cardio',
          syncData: const SyncMeta(baseRevision: 1, syncedHash: 'h').toMap(),
        ),
      );
      await box.close();

      final older = olderBuild();
      final oldBox = await older.openBox<CustomExercise>('custom_exercises_u');
      expect(oldBox.get('c1')!.name, 'Sled push');
      await older.close();

      final again = await Hive.openBox<CustomExercise>('custom_exercises_u');
      expect(again.get('c1')!.activityType, 'cardio');
      expect(again.get('c1')!.syncMeta.baseRevision, 1);
    });
  });
}
