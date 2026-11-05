import 'dart:convert';

import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/active_workout_edit_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'support/standard_template_fixtures.dart';

class ActiveEditSetsRemote implements WorkoutRemoteDataSource {
  @override
  Future<void> syncSet(String key, ExerciseSet set) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FaultBox<T> implements Box<T> {
  final Box<T> delegate;
  final bool Function(T) fails;
  FaultBox(this.delegate, this.fails);
  @override
  String get name => delegate.name;
  @override
  bool get isOpen => delegate.isOpen;
  @override
  T? get(dynamic key, {T? defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Iterable<T> get values => delegate.values;
  @override
  Stream<BoxEvent> watch({dynamic key}) => delegate.watch(key: key);
  @override
  Future<void> put(dynamic key, T value) async {
    if (fails(value)) throw StateError('Simulated local write failure');
    await delegate.put(key, value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FaultDays extends WorkoutTemplateRepository {
  bool fail = false;
  FaultDays(StandardTemplateFixture f)
    : super(
        storageManager: f.storage,
        remoteDataSource: f.dayRemote,
        uidOverride: () => f.uid,
      );
  @override
  Future<Box<WorkoutTemplate>> getUserBox() async =>
      FaultBox(await super.getUserBox(), (_) => fail);
}

class FaultSessions extends WorkoutSessionRepository {
  bool fail = false;
  bool failCommit = false;
  FaultSessions(StandardTemplateFixture f)
    : super(
        storageManager: f.storage,
        remoteDataSource: TemplateSessionRemote(),
        uidOverride: () => f.uid,
      );
  @override
  Future<Box<WorkoutSession>> getUserBox() async => FaultBox(
    await super.getUserBox(),
    (session) =>
        fail || (failCommit && session.pendingProgramExerciseEdit == null),
  );
}

class LegacySessionAdapter extends WorkoutSessionAdapter {
  @override
  void write(BinaryWriter writer, WorkoutSession value) {
    final fields = [
      value.id,
      value.programId,
      value.workoutTemplateId,
      value.workoutNameSnapshot,
      value.date,
      value.startedAt,
      value.completedAt,
      value.status,
      value.totalVolume,
      value.previousSessionId,
      value.workoutNote,
      value.templateExerciseAssignmentsSnapshot,
      value.sessionExerciseNames,
      value.hiddenExerciseNames,
      value.exerciseOrder,
    ];
    writer.writeByte(fields.length);
    for (var i = 0; i < fields.length; i++) {
      writer
        ..writeByte(i)
        ..write(fields[i]);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StandardTemplateFixture f;
  late FaultDays days;
  late FaultSessions sessions;
  late SessionExerciseRepository sets;
  late ActiveWorkoutEditService service;
  late WorkoutSession session;
  late WorkoutTemplate day;
  late List<ExerciseLibraryItem> catalog;
  late SessionExerciseCubit cubit;
  WorkoutSession current() => (Hive.box<WorkoutSession>(
    'workout_sessions_${f.uid.toLowerCase()}',
  )).get(session.id)!;
  WorkoutTemplate source() => Hive.box<WorkoutTemplate>(
    'workout_templates_${f.uid.toLowerCase()}',
  ).get(day.id)!;
  List<String> ids(WorkoutSession value) => value
      .templateExerciseAssignmentsSnapshot
      .map((a) => a.exerciseId)
      .toList();
  Matcher failure(ActiveWorkoutEditFailure reason) =>
      isA<ActiveWorkoutEditException>().having(
        (e) => e.reason,
        'reason',
        reason,
      );

  setUp(() async {
    f = StandardTemplateFixture();
    await f.open();
    days = FaultDays(f);
    sessions = FaultSessions(f);
    sets = SessionExerciseRepository(
      storageManager: f.storage,
      remoteDataSource: ActiveEditSetsRemote(),
      uidOverride: () => f.uid,
    );
    final draft = await f.draft();
    await f.importer.save(draft);
    day = draft.days.first;
    // Real original catalog IDs, names and reference types from the preset.
    final assignments = day.exerciseAssignments.take(2).toList();
    day = day.copyWith(exerciseAssignments: assignments);
    await (await days.getUserBox()).put(day.id, day);
    catalog = draft.days
        .expand((d) => d.exerciseAssignments)
        .map(
          (a) => ExerciseLibraryItem(
            id: a.exerciseId,
            nameEn: a.exerciseNameSnapshot,
            source: ExerciseLibraryItemSource.builtIn,
          ),
        )
        .toList();
    final unique = <String, ExerciseLibraryItem>{
      for (final item in catalog) item.id: item,
    };
    catalog = unique.values
        .where((item) => !assignments.any((a) => a.exerciseId == item.id))
        .toList();
    service = ActiveWorkoutEditService(
      sessions: sessions,
      templates: days,
      sets: sets,
    );
    session = await sessions.startWorkoutSession(
      programId: day.programId,
      workoutTemplateId: day.id,
      workoutNameSnapshot: day.name,
      templateExerciseAssignments: assignments,
    );
    cubit = SessionExerciseCubit(
      repository: sets,
      sessionRepository: sessions,
      editService: service,
    );
    await cubit.loadForSession(session);
  });
  tearDown(() async {
    await cubit.close();
    await f.close();
  });

  test(
    'mounted session views observe one persisted layout and logged-set state',
    () async {
      final other = SessionExerciseCubit(
        repository: sets,
        sessionRepository: sessions,
        editService: service,
      );
      addTearDown(other.close);
      await other.loadForSession(session);
      await cubit.editActiveExercises(
        session: session,
        action: ActiveWorkoutEditAction.add,
        exercises: [catalog.first],
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((other.state as SessionExerciseLoaded).rows, hasLength(3));
      await sets.addSet(
        programId: day.programId,
        workoutTemplateId: day.id,
        workoutSessionId: session.id,
        exerciseName: catalog.first.nameEn,
        weight: 20,
        reps: 10,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((other.state as SessionExerciseLoaded).totalVolume, 200);
      expect((cubit.state as SessionExerciseLoaded).totalVolume, 200);
    },
  );

  test(
    'legacy fifteen-field Hive records reopen without a migration',
    () async {
      Hive.registerAdapter(LegacySessionAdapter(), override: true);
      final oldBox = await Hive.openBox<WorkoutSession>('legacy_session');
      await oldBox.put(session.id, session.copyWith());
      await oldBox.close();
      Hive.registerAdapter(WorkoutSessionAdapter(), override: true);
      final reopened = await Hive.openBox<WorkoutSession>('legacy_session');
      expect(reopened.get(session.id)!.pendingProgramExerciseEdit, isNull);
      expect(ids(reopened.get(session.id)!), ids(session));
      expect(
        reopened.get(session.id)!.startedAt.millisecondsSinceEpoch,
        session.startedAt.millisecondsSinceEpoch,
      );
    },
  );

  test(
    'legacy hidden logged rows remain visible with their original sets',
    () async {
      final name = day.exerciseAssignments.first.exerciseNameSnapshot;
      await sets.addSet(
        programId: day.programId,
        workoutTemplateId: day.id,
        workoutSessionId: session.id,
        exerciseName: name,
        weight: 40,
        reps: 10,
      );
      await (await sessions.getUserBox()).put(
        session.id,
        session.copyWith(hiddenExerciseNames: [name]),
      );
      await cubit.loadForSession(session);
      final loaded = cubit.state as SessionExerciseLoaded;
      expect(loaded.rows.first.exerciseName, name);
      expect(loaded.rows.first.sets, hasLength(1));
      expect(loaded.totalVolume, 400);
    },
  );

  for (final scope in ActiveWorkoutEditScope.values) {
    for (final action in [
      ActiveWorkoutEditAction.add,
      ActiveWorkoutEditAction.replace,
      ActiveWorkoutEditAction.remove,
      ActiveWorkoutEditAction.reorder,
      ActiveWorkoutEditAction.targets,
    ]) {
      test(
        '${scope.name}: ${action.name} updates session immediately and preserves scope',
        () async {
          final before = jsonEncode(
            source().exerciseAssignments.map((a) => a.toJson()).toList(),
          );
          final first = session.templateExerciseAssignmentsSnapshot.first;
          await cubit.editActiveExercises(
            session: session,
            action: action,
            scope: scope,
            exerciseName: first.exerciseNameSnapshot,
            exercises: [catalog.first],
            orderedNames: session.templateExerciseAssignmentsSnapshot.reversed
                .map((a) => a.exerciseNameSnapshot)
                .toList(),
            targets: first.copyWith(
              workingSets: 4,
              targetRepsMin: 5,
              targetRepsMax: 7,
              restSeconds: 120,
            ),
          );
          final loaded = cubit.state as SessionExerciseLoaded;
          expect(loaded.session!.pendingProgramExerciseEdit, isNull);
          expect(
            loaded.rows.map((r) => r.exerciseName),
            current().exerciseOrder,
          );
          switch (action) {
            case ActiveWorkoutEditAction.add:
              expect(ids(current()), contains(catalog.first.id));
            case ActiveWorkoutEditAction.replace:
              expect(ids(current()).first, catalog.first.id);
              expect(
                current()
                    .templateExerciseAssignmentsSnapshot
                    .first
                    .assignmentId,
                first.assignmentId,
              );
            case ActiveWorkoutEditAction.remove:
              expect(ids(current()), isNot(contains(first.exerciseId)));
            case ActiveWorkoutEditAction.reorder:
              expect(ids(current()), ids(session).reversed);
            case ActiveWorkoutEditAction.targets:
              expect(loaded.rows.first.assignment!.workingSets, 4);
              expect(loaded.rows.first.assignment!.restSeconds, 120);
            case ActiveWorkoutEditAction.applyProgram:
              break;
          }
          final after = jsonEncode(
            source().exerciseAssignments.map((a) => a.toJson()).toList(),
          );
          if (scope == ActiveWorkoutEditScope.sessionOnly) {
            expect(after, before);
          } else {
            expect(
              after,
              jsonEncode(
                current().templateExerciseAssignmentsSnapshot
                    .map((a) => a.toJson())
                    .toList(),
              ),
            );
          }
          expect(await cubit.getValidSetsForSession(session), isEmpty);
          await cubit.loadForSession(
            session,
          ); // deliberately stale route argument
          expect(
            ids((cubit.state as SessionExerciseLoaded).session!),
            ids(current()),
          );
        },
      );
    }
  }

  test(
    'logged sets and historical sessions survive all protected operations',
    () async {
      final name = session
          .templateExerciseAssignmentsSnapshot
          .first
          .exerciseNameSnapshot;
      final set = await sets.addSet(
        programId: day.programId,
        workoutTemplateId: day.id,
        workoutSessionId: session.id,
        exerciseName: name,
        weight: 80,
        reps: 8,
      );
      final history = WorkoutSession(
        id: 'completed-history',
        programId: day.programId,
        workoutTemplateId: day.id,
        workoutNameSnapshot: 'Old name',
        date: DateTime(2025),
        startedAt: DateTime(2025),
        status: WorkoutSessionStatus.completed.value,
        templateExerciseAssignmentsSnapshot: day.exerciseAssignments,
        totalVolume: 640,
      );
      await (await sessions.getUserBox()).put(history.id, history);
      for (final scope in ActiveWorkoutEditScope.values) {
        for (final action in [
          ActiveWorkoutEditAction.remove,
          ActiveWorkoutEditAction.replace,
        ]) {
          await expectLater(
            service.edit(
              sessionId: session.id,
              action: action,
              scope: scope,
              exerciseName: name,
              exercises: [catalog.first],
            ),
            throwsA(failure(ActiveWorkoutEditFailure.loggedSets)),
          );
        }
      }
      expect((await sets.getUserBox()).get(set.key), same(set));
      expect((await sessions.getUserBox()).get(history.id)!.totalVolume, 640);
      expect(ids(current()), ids(session));
      expect((await cubit.getValidSetsForSession(session)).single.weight, 80);
      expect((await sets.getUserBox()).length, 1);
    },
  );

  test(
    'failed first write changes neither session nor program and can retry',
    () async {
      sessions.fail = true;
      await expectLater(
        service.edit(
          sessionId: session.id,
          action: ActiveWorkoutEditAction.add,
          scope: ActiveWorkoutEditScope.sessionAndProgram,
          exercises: [catalog.first],
        ),
        throwsStateError,
      );
      expect(ids(current()), ids(session));
      expect(source().exerciseAssignments.length, 2);
      sessions.fail = false;
      await service.edit(
        sessionId: session.id,
        action: ActiveWorkoutEditAction.add,
        scope: ActiveWorkoutEditScope.sessionAndProgram,
        exercises: [catalog.first],
      );
      expect(ids(current()), hasLength(3));
    },
  );

  test(
    'second-box failure persists pending intent, retries once after restart',
    () async {
      days.fail = true;
      await expectLater(
        service.edit(
          sessionId: session.id,
          action: ActiveWorkoutEditAction.add,
          scope: ActiveWorkoutEditScope.sessionAndProgram,
          exercises: [catalog.first],
        ),
        throwsA(failure(ActiveWorkoutEditFailure.pending)),
      );
      expect(ids(current()), hasLength(3));
      expect(source().exerciseAssignments, hasLength(2));
      expect(current().pendingProgramExerciseEdit, isNotNull);
      await expectLater(
        sessions.completeWorkoutSession(sessionId: session.id, totalVolume: 0),
        throwsStateError,
      );
      await Hive.close(); // actual disk close/reopen, no data deletion
      days.fail = false;
      await cubit.loadForSession(session);
      expect(
        (cubit.state as SessionExerciseLoaded)
            .session!
            .pendingProgramExerciseEdit,
        isNull,
      );
      expect(source().exerciseAssignments, hasLength(3));
      await service.recover(session.id);
      expect(source().exerciseAssignments, hasLength(3));
    },
  );

  test(
    'failure clearing intent recognizes already-written program without duplicates',
    () async {
      sessions.failCommit = true;
      await expectLater(
        service.edit(
          sessionId: session.id,
          action: ActiveWorkoutEditAction.add,
          scope: ActiveWorkoutEditScope.sessionAndProgram,
          exercises: [catalog.first],
        ),
        throwsA(failure(ActiveWorkoutEditFailure.pending)),
      );
      expect(source().exerciseAssignments, hasLength(3));
      sessions.failCommit = false;
      await service.recover(session.id);
      expect(current().pendingProgramExerciseEdit, isNull);
      expect(source().exerciseAssignments, hasLength(3));
    },
  );

  test(
    'pending recovery refuses a later program edit and can stop retrying safely',
    () async {
      days.fail = true;
      await expectLater(
        service.edit(
          sessionId: session.id,
          action: ActiveWorkoutEditAction.add,
          scope: ActiveWorkoutEditScope.sessionAndProgram,
          exercises: [catalog.first],
        ),
        throwsA(isA<ActiveWorkoutEditException>()),
      );
      days.fail = false;
      final changed = source().copyWith(
        exerciseAssignments: source().exerciseAssignments.reversed.toList(),
      );
      await (await days.getUserBox()).put(day.id, changed);
      await expectLater(
        service.recover(session.id),
        throwsA(failure(ActiveWorkoutEditFailure.conflict)),
      );
      expect(
        source().exerciseAssignments.first.exerciseId,
        changed.exerciseAssignments.first.exerciseId,
      );
      await service.recover(session.id, keepSessionOnly: true);
      expect(current().pendingProgramExerciseEdit, isNull);
      expect(ids(current()), hasLength(3));
      expect(source().exerciseAssignments, hasLength(2));
    },
  );

  test(
    'source changes stay independent until explicit apply and never drop logged exercise',
    () async {
      final first = day.exerciseAssignments.first;
      await days.updateExerciseTargets(
        templateId: day.id,
        assignmentId: first.assignmentId,
        workingSets: 5,
        targetRepsMin: 8,
        targetRepsMax: 9,
        restSeconds: 180,
      );
      await cubit.refreshForSession(session);
      expect(
        (cubit.state as SessionExerciseLoaded)
            .rows
            .first
            .assignment!
            .workingSets,
        first.workingSets,
      );
      await expectLater(
        service.edit(
          sessionId: session.id,
          action: ActiveWorkoutEditAction.remove,
          scope: ActiveWorkoutEditScope.sessionAndProgram,
          exerciseName: first.exerciseNameSnapshot,
        ),
        throwsA(failure(ActiveWorkoutEditFailure.conflict)),
      );
      await cubit.editActiveExercises(
        session: session,
        action: ActiveWorkoutEditAction.applyProgram,
      );
      expect(
        (cubit.state as SessionExerciseLoaded)
            .rows
            .first
            .assignment!
            .workingSets,
        5,
      );
      await sets.addSet(
        programId: day.programId,
        workoutTemplateId: day.id,
        workoutSessionId: session.id,
        exerciseName: first.exerciseNameSnapshot,
        weight: 30,
        reps: 10,
      );
      await days.removeExerciseAssignment(
        templateId: day.id,
        assignmentId: first.assignmentId,
      );
      await expectLater(
        service.edit(
          sessionId: session.id,
          action: ActiveWorkoutEditAction.applyProgram,
        ),
        throwsA(failure(ActiveWorkoutEditFailure.loggedSets)),
      );
      expect((await sets.getUserBox()).length, 1);
    },
  );

  test(
    'rapid duplicate actions serialize and cannot lose another addition',
    () async {
      final results = await Future.wait([
        service.edit(
          sessionId: session.id,
          action: ActiveWorkoutEditAction.add,
          exercises: [catalog[0]],
        ),
        service
            .edit(
              sessionId: session.id,
              action: ActiveWorkoutEditAction.add,
              exercises: [catalog[0]],
            )
            .then<Object>((v) => v, onError: (Object error) => error),
        service.edit(
          sessionId: session.id,
          action: ActiveWorkoutEditAction.add,
          exercises: [catalog[1]],
        ),
      ]);
      expect(results[1], failure(ActiveWorkoutEditFailure.duplicate));
      expect(ids(current()), hasLength(4));
      expect(ids(current()).toSet(), hasLength(4));
    },
  );

  test(
    'session-only exercise can be promoted with its targets without changing unrelated day entries',
    () async {
      await service.edit(
        sessionId: session.id,
        action: ActiveWorkoutEditAction.add,
        exercises: [catalog.first],
      );
      final item = current().templateExerciseAssignmentsSnapshot.last;
      await service.edit(
        sessionId: session.id,
        action: ActiveWorkoutEditAction.targets,
        scope: ActiveWorkoutEditScope.sessionAndProgram,
        exerciseName: item.exerciseNameSnapshot,
        targets: item.copyWith(
          workingSets: 3,
          targetRepsMin: 10,
          targetRepsMax: 12,
          restSeconds: 90,
        ),
      );
      expect(source().exerciseAssignments.last.exerciseId, item.exerciseId);
      expect(source().exerciseAssignments.last.workingSets, 3);
      expect(current().sessionExerciseNames, isEmpty);
    },
  );

  test('account switch cannot mutate the old session or new account', () async {
    f.uid = 'Owner-B';
    await expectLater(
      service.edit(
        sessionId: session.id,
        action: ActiveWorkoutEditAction.add,
        exercises: [catalog.first],
      ),
      throwsA(failure(ActiveWorkoutEditFailure.inactive)),
    );
    expect((await sessions.getUserBox()).values, isEmpty);
    f.uid = 'Owner-A';
    expect(ids(current()), ids(session));
  });
}
