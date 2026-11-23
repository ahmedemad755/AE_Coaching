import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../support/fake_revision_cloud.dart';
import 'support/standard_template_fixtures.dart';

class DaysCloud extends FakeRevisionCloud
    implements WorkoutTemplateRemoteDataSource {}

class SetsRemote implements WorkoutRemoteDataSource {
  @override
  Future<void> syncSet(String key, ExerciseSet set) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// What a strength workout depends on, per activity.
Map<String, Object?> strengthOf(WorkoutTemplateExerciseAssignment a) => {
  'id': a.assignmentId,
  'exerciseId': a.exerciseId,
  'name': a.exerciseNameSnapshot,
  'referenceType': a.referenceType,
  'type': a.type,
  'sets': a.workingSets,
  'repsMin': a.targetRepsMin,
  'repsMax': a.targetRepsMax,
  'rest': a.restSeconds,
};

/// Stage 2 changed how workout days are stored and synced. Strength days,
/// workout sessions and their history must behave exactly as before.
void main() {
  late Directory dir;
  late UserStorageManager storage;
  late DaysCloud cloud;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('strength_regression_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ExerciseSetAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(WorkoutTemplateAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(WorkoutSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
    }
    storage = UserStorageManager();
    cloud = DaysCloud();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  WorkoutTemplateRepository days(String uid) => WorkoutTemplateRepository(
    remoteDataSource: cloud,
    storageManager: storage,
    uidOverride: () => uid,
  );

  Future<void> sync(WorkoutTemplateRepository repository) async =>
      repository.fetchAndSyncFromRemote(await repository.getUserBox());

  test('a strength day synced to another phone runs a full workout there; '
      'history keeps exactly what was done', () async {
    final a = days('phone-a');
    final b = days('phone-b');
    final day = await a.createTemplate(programId: 'p1', name: 'Push');
    await a.addExerciseAssignments(
      templateId: day.id,
      exercises: const [
        ExerciseLibraryItem(
          id: 'repdb:bench',
          nameEn: 'Bench press',
          source: ExerciseLibraryItemSource.builtIn,
        ),
        ExerciseLibraryItem(
          id: 'repdb:ohp',
          nameEn: 'Overhead press',
          source: ExerciseLibraryItemSource.builtIn,
        ),
      ],
      languageCode: 'en',
    );
    final bench = (await a.getUserBox()).get(day.id)!.exerciseAssignments[0];
    final planned = await a.updateExerciseTargets(
      templateId: day.id,
      assignmentId: bench.assignmentId,
      workingSets: 4,
      targetRepsMin: 6,
      targetRepsMax: 8,
      restSeconds: 150,
    );
    await sync(a);
    await sync(b);

    final onB = (await b.getUserBox()).get(day.id)!;
    expect(
      onB.exerciseAssignments.map(strengthOf),
      planned.exerciseAssignments.map(strengthOf),
    );
    expect(onB.exerciseAssignments.first.type, ActivityType.strength);

    // Phone B runs the workout from the synced day.
    final sessions = WorkoutSessionRepository(
      storageManager: storage,
      remoteDataSource: TemplateSessionRemote(),
      uidOverride: () => 'phone-b',
    );
    final sets = SessionExerciseRepository(
      storageManager: storage,
      remoteDataSource: SetsRemote(),
      uidOverride: () => 'phone-b',
    );
    final session = await sessions.startWorkoutSession(
      programId: 'p1',
      workoutTemplateId: day.id,
      workoutNameSnapshot: onB.name,
      templateExerciseAssignments: onB.exerciseAssignments,
    );
    expect(
      session.templateExerciseAssignmentsSnapshot.map(strengthOf),
      onB.exerciseAssignments.map(strengthOf),
    );
    for (final (weight, reps) in [(80.0, 8), (85.0, 6), (85.0, 6)]) {
      await sets.addSet(
        programId: 'p1',
        workoutTemplateId: day.id,
        workoutSessionId: session.id,
        exerciseName: 'Bench press',
        weight: weight,
        reps: reps,
      );
    }
    await sets.addSet(
      programId: 'p1',
      workoutTemplateId: day.id,
      workoutSessionId: session.id,
      exerciseName: 'Overhead press',
      weight: 50,
      reps: 10,
    );
    final volume = 80.0 * 8 + 85 * 6 + 85 * 6 + 50 * 10;
    await sessions.completeWorkoutSession(
      sessionId: session.id,
      totalVolume: volume,
    );

    // The day changes later, on the other phone.
    await a.updateTemplate(templateId: day.id, name: 'Push (new)');
    await a.updateExerciseTargets(
      templateId: day.id,
      assignmentId: bench.assignmentId,
      workingSets: 5,
      targetRepsMin: 3,
      targetRepsMax: 5,
      restSeconds: 180,
    );
    await sync(a);
    await sync(b);
    expect((await b.getUserBox()).get(day.id)!.name, 'Push (new)');

    // History on phone B is exactly what was done.
    final sessionBox = await sessions.getUserBox();
    final history = sessions.getCompletedSessionsForTemplate(
      sessionBox,
      day.id,
    );
    expect(history.map((s) => s.id), [session.id]);
    final done = history.single;
    expect(done.workoutNameSnapshot, 'Push');
    expect(done.totalVolume, volume);
    expect(
      done.templateExerciseAssignmentsSnapshot.map(strengthOf),
      onB.exerciseAssignments.map(strengthOf),
    );
    final setBox = await sets.getUserBox();
    expect(
      sets
          .getSetsForSession(setBox, session.id)
          .map((s) => '${s.exerciseName} ${s.weight}x${s.reps}'),
      [
        'Bench press 80.0x8',
        'Bench press 85.0x6',
        'Bench press 85.0x6',
        'Overhead press 50.0x10',
      ],
    );
    expect(sets.getExerciseNamesForSession(setBox, session.id), [
      'Bench press',
      'Overhead press',
    ]);
  });

  test('a day that has not synced yet (offline, conflict, blocked) still '
      'starts a normal workout', () async {
    cloud.offline = true;
    final a = days('phone-a');
    final day = await a.createTemplate(programId: 'p1', name: 'Legs');
    await a.addExerciseAssignment(
      templateId: day.id,
      exerciseId: 'repdb:squat',
      exerciseNameSnapshot: 'Squat',
      referenceType: WorkoutExerciseReferenceType.builtIn,
    );
    await sync(a); // offline: nothing sent, nothing lost
    final local = (await a.getUserBox()).get(day.id)!;
    expect(local.exerciseAssignments.single.exerciseNameSnapshot, 'Squat');

    final sessions = WorkoutSessionRepository(
      storageManager: storage,
      remoteDataSource: TemplateSessionRemote(),
      uidOverride: () => 'phone-a',
    );
    final session = await sessions.startWorkoutSession(
      programId: 'p1',
      workoutTemplateId: day.id,
      workoutNameSnapshot: local.name,
      templateExerciseAssignments: local.exerciseAssignments,
    );
    expect(
      session.templateExerciseAssignmentsSnapshot.single.exerciseNameSnapshot,
      'Squat',
    );
  });
}
