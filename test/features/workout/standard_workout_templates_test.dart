// ignore_for_file: subtype_of_sealed_class
import 'dart:convert';
import 'dart:io';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/standard_workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_draft_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'support/standard_template_fixtures.dart';

class _FourFieldAdapter extends WorkoutTemplateExerciseAssignmentAdapter {
  @override
  void write(BinaryWriter writer, WorkoutTemplateExerciseAssignment obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.assignmentId)
      ..writeByte(1)
      ..write(obj.exerciseId)
      ..writeByte(2)
      ..write(obj.exerciseNameSnapshot)
      ..writeByte(3)
      ..write(obj.referenceType);
  }
}

class _FailPutBox implements Box<WorkoutProgram> {
  final Box<WorkoutProgram> delegate;
  _FailPutBox(this.delegate);
  @override
  String get name => delegate.name;
  @override
  bool get isOpen => delegate.isOpen;
  @override
  bool containsKey(dynamic key) => delegate.containsKey(key);
  @override
  Future<void> put(dynamic key, WorkoutProgram value) async =>
      throw StateError('Disk failure');
  @override
  Future<void> delete(dynamic key) => delegate.delete(key);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailProgramRepository extends WorkoutProgramRepository {
  _FailProgramRepository(StandardTemplateFixture f)
    : super(
        storageManager: f.storage,
        remoteDataSource: f.programRemote,
        uidOverride: () => f.uid,
      );
  @override
  Future<Box<WorkoutProgram>> getUserBox() async =>
      _FailPutBox(await super.getUserBox());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all seven splits, nine variants, schedules, IDs and targets are valid',
    () async {
      final splits = await standardTemplateCatalog().loadTemplates();
      expect(splits.length, 7);
      final variants = splits.expand((s) => s.variants).toList();
      expect(
        {for (final v in variants) v.id: v.days.length},
        {
          'ppl_3': 3,
          'ppl_6': 6,
          'upper_lower_4': 4,
          'full_body_3': 3,
          'bro_5': 5,
          'arnold_3': 3,
          'arnold_6': 6,
          'hybrid_5': 5,
          'anterior_posterior_4': 4,
        },
      );
      final catalog =
          jsonDecode(
                File(ExerciseCatalogRepository.assetPath).readAsStringSync(),
              )['exercises']
              as List;
      final ids = {...catalog.map((e) => 'repdb:${e['id']}')};
      for (final split in splits) {
        expect(split.nameAr, matches(RegExp(r'[\u0600-\u06ff]')));
        for (final v in split.variants) {
          expect(v.suggestedWeek, hasLength(7));
          expect(
            v.suggestedWeek.whereType<int>().toSet(),
            List.generate(v.days.length, (i) => i).toSet(),
          );
          expect(v.suggestedWeek, contains(null));
          for (final d in v.days) {
            expect(d.exercises.length, inInclusiveRange(3, 8));
            expect(
              d.exercises.map((e) => e.exercise.id).toSet(),
              hasLength(d.exercises.length),
            );
            for (final e in d.exercises) {
              expect(ids, contains(e.exercise.id));
              expect(e.exercise.isRepDb, isTrue);
              expect(e.workingSets, inInclusiveRange(2, 4));
              expect(e.repsMin, greaterThanOrEqualTo(6));
              expect(e.repsMax, inInclusiveRange(e.repsMin, 20));
              expect(e.restSeconds, inInclusiveRange(60, 180));
            }
          }
        }
      }
      final ap = splits.last.variants.single.days;
      expect(ap.map((d) => d.nameEn), [
        'Anterior A',
        'Posterior A',
        'Anterior B',
        'Posterior B',
      ]);
      expect(
        ap[0].exercises.map((e) => e.exercise.id),
        contains('repdb:ez-bar-curl'),
      );
      expect(
        ap[1].exercises.map((e) => e.exercise.id),
        contains('repdb:tricep-pushdown'),
      );
      expect(
        ap[0].exercises.map((e) => e.exercise.id),
        isNot(ap[2].exercises.map((e) => e.exercise.id)),
      );
      final ppl = splits.first;
      expect(
        ppl.variants[1].days[0].exercises.fold<int>(
          0,
          (n, e) => n + e.workingSets,
        ),
        lessThan(
          ppl.variants[0].days[0].exercises.fold<int>(
            0,
            (n, e) => n + e.workingSets,
          ),
        ),
      );
    },
  );

  test(
    'invalid catalog references and targets fail without caching broken data',
    () async {
      final original = jsonDecode(
        File(StandardWorkoutTemplateRepository.assetPath).readAsStringSync(),
      );
      for (final mutation in [
        'id',
        'exactLegacyAlias',
        'unresolvedLegacy',
        'duplicate',
        'sets',
        'reps',
        'rest',
        'schedule',
      ]) {
        final data = jsonDecode(jsonEncode(original));
        final v = data['splits'][0]['variants'][0];
        final e = v['days'][0]['exercises'][0];
        switch (mutation) {
          case 'id':
            e['exercise_id'] = 'invented';
          case 'exactLegacyAlias':
            e['exercise_id'] = 'ex_barbell_bench_press';
          case 'unresolvedLegacy':
            e['exercise_id'] = 'ex_rope_triceps_pushdown';
          case 'duplicate':
            e['exercise_id'] = v['days'][0]['exercises'][1]['exercise_id'];
          case 'sets':
            e['working_sets'] = 0;
          case 'reps':
            e['reps_min'] = 20;
            e['reps_max'] = 5;
          case 'rest':
            e['rest_seconds'] = -1;
          case 'schedule':
            v['suggested_week'] = [0, 0, 1, null, null, null, null];
        }
        final repo = StandardWorkoutTemplateRepository(
          catalog: ExerciseCatalogRepository(
            loadAsset: (p) => File(p).readAsString(),
          ),
          loadAsset: (_) async => jsonEncode(data),
        );
        await expectLater(
          repo.loadTemplates(),
          throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
        );
      }
    },
  );

  group('independent copies and persistence', () {
    late StandardTemplateFixture f;
    setUp(() async {
      f = StandardTemplateFixture();
      await f.open();
    });
    tearDown(() async => f.close());
    test(
      'source lists immutable; copies have fresh program/day/assignment IDs',
      () async {
        final source = (await standardTemplateCatalog().loadTemplates()).first;
        expect(() => source.variants.clear(), throwsUnsupportedError);
        expect(
          () => source.variants.first.days.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => source.variants.first.days.first.exercises.clear(),
          throwsUnsupportedError,
        );
        final a = await f.draft();
        final b = await f.draft(language: 'ar');
        expect(a.programId, isNot(b.programId));
        expect(a.days.first.id, isNot(b.days.first.id));
        expect(
          a.days.first.exerciseAssignments.first.assignmentId,
          isNot(b.days.first.exerciseAssignments.first.assignmentId),
        );
        expect(b.days.first.name, 'دفع');
        final sourceName = source.variants.first.days.first.nameEn;
        final cubit = WorkoutProgramDraftCubit(draft: a, importer: f.importer);
        cubit.renameDay(a.days.first.id, 'My push');
        expect(source.variants.first.days.first.nameEn, sourceName);
        expect(b.days.first.name, 'دفع');
        expect((await f.programs.getUserBox()).isEmpty, isTrue);
        await cubit.close();
      },
    );
    test(
      'full customization saves complete inactive copy and survives reopening',
      () async {
        final old = await f.programs.createProgram(
          name: 'Existing active',
          makeActive: true,
        );
        final oldDay = await f.days.createTemplate(
          programId: old.id,
          name: 'Existing day',
        );
        final a = await f.draft();
        final day = a.days.first;
        final cubit = WorkoutProgramDraftCubit(draft: a, importer: f.importer);
        cubit.renameProgram('Custom copy');
        cubit.renameDay(day.id, 'Custom push');
        cubit.removeExercise(day.id, day.exerciseAssignments.last.assignmentId);
        const added = ExerciseLibraryItem(
          id: 'custom_test',
          nameEn: 'My custom exercise',
          source: ExerciseLibraryItemSource.custom,
        );
        cubit.addExercises(day.id, [added], 'en');
        final first = day.exerciseAssignments.first;
        const replacement = ExerciseLibraryItem(
          id: 'ex_dumbbell_bench_press',
          nameEn: 'Dumbbell Bench Press',
          source: ExerciseLibraryItemSource.builtIn,
        );
        cubit.replaceExercise(day.id, first.assignmentId, replacement, 'en');
        cubit.updateTargets(
          day.id,
          first.copyWith(
            workingSets: 4,
            targetRepsMin: 9,
            targetRepsMax: 13,
            restSeconds: 120,
          ),
        );
        cubit.moveExercise(day.id, 0, 1);
        await cubit.save();
        await cubit.save(); // second tap never creates a duplicate
        expect(cubit.state.saved, isNotNull);
        final box = await f.programs.getUserBox();
        expect(box.length, 2);
        expect(box.get(old.id)!.isActive, isTrue);
        expect(box.get(a.programId)!.isActive, isFalse);
        expect(
          (await f.days.getUserBox()).get(oldDay.id)!.name,
          'Existing day',
        );
        final saved = (await f.days.getUserBox()).get(day.id)!;
        expect(saved.name, 'Custom push');
        expect(saved.exerciseAssignments[1].exerciseId, 'repdb:db-bench-press');
        expect(saved.exerciseAssignments[1].workingSets, 4);
        expect(saved.exerciseAssignments[1].restSeconds, 120);
        expect(saved.exerciseAssignments.last.referenceType, 'custom');
        expect(
          f.dayRemote.documents[day.id]!.containsKey('exerciseAssignments'),
          isFalse,
        );
        await f.storage.closeForUser(f.uid);
        final reopened = (await f.days.getUserBox()).get(day.id)!;
        expect(reopened.exerciseAssignments[1].targetRepsMax, 13);
        await cubit.close();
      },
    );
    test(
      'cloud failure retains exactly one complete local copy and exposes warning',
      () async {
        f.dayRemote.fail = true;
        final draft = await f.draft();
        final result = await f.importer.save(draft);
        expect(result.cloudSyncIncomplete, isTrue);
        expect((await f.programs.getUserBox()).length, 1);
        expect((await f.days.getUserBox()).length, 3);
        await expectLater(f.importer.save(draft), throwsStateError);
        expect((await f.days.getUserBox()).length, 3);
      },
    );
    test(
      'pending offline cloud acknowledgement cannot block a local save indefinitely',
      () async {
        f.programRemote.hang = true;
        final draft = await f.draft();
        final service = WorkoutTemplateImportService(
          programs: f.programs,
          templates: f.days,
          currentUserId: () => f.uid,
          syncTimeout: const Duration(milliseconds: 10),
        );
        final saved = await service.save(draft);
        expect(saved.cloudSyncIncomplete, isTrue);
        expect(
          (await f.programs.getUserBox()).containsKey(draft.programId),
          isTrue,
        );
        expect((await f.days.getUserBox()).length, 3);
      },
    );
    test(
      'using a template preserves existing completed sessions and logged sets',
      () async {
        final now = DateTime.now();
        final history = await f.storage.getUserBox<WorkoutSession>(
          'workout_sessions',
          f.uid,
        );
        final sets = await f.storage.getUserBox<ExerciseSet>('sets', f.uid);
        final session = WorkoutSession(
          id: 'old-session',
          programId: 'old-program',
          workoutTemplateId: 'old-day',
          workoutNameSnapshot: 'Historical day',
          date: now,
          startedAt: now,
          completedAt: now,
          status: 'completed',
          totalVolume: 480,
        );
        final set = ExerciseSet(
          exerciseName: 'Historical Bench',
          weight: 60,
          reps: 8,
          date: now,
          programId: 'old-program',
          workoutTemplateId: 'old-day',
          workoutSessionId: session.id,
        );
        await history.put(session.id, session);
        final key = await sets.add(set);
        final beforeSession = jsonEncode(session.toJson());
        final beforeSet = jsonEncode(set.toJson());
        await f.importer.save(await f.draft());
        expect(history.length, 1);
        expect(sets.length, 1);
        expect(jsonEncode(history.get(session.id)!.toJson()), beforeSession);
        expect(jsonEncode(sets.get(key)!.toJson()), beforeSet);
      },
    );
    test(
      'local failure rolls back only new records and keeps draft retryable',
      () async {
        final old = await f.programs.createProgram(name: 'Existing');
        final oldDay = await f.days.createTemplate(
          programId: old.id,
          name: 'Old day',
        );
        final draft = await f.draft();
        final service = WorkoutTemplateImportService(
          programs: _FailProgramRepository(f),
          templates: f.days,
          currentUserId: () => f.uid,
        );
        await expectLater(service.save(draft), throwsStateError);
        expect((await f.programs.getUserBox()).keys, [old.id]);
        expect((await f.days.getUserBox()).keys, [oldDay.id]);
        final retry = await f.importer.save(draft);
        expect(retry.program.id, draft.programId);
      },
    );
    test(
      'account switch rejects stale draft and isolates saved copies',
      () async {
        final draft = await f.draft();
        await f.importer.save(draft);
        f.uid = 'Owner-B';
        expect((await f.programs.getUserBox()).isEmpty, isTrue);
        expect((await f.days.getUserBox()).isEmpty, isTrue);
        await expectLater(f.importer.save(draft), throwsStateError);
        expect((await f.programs.getUserBox()).isEmpty, isTrue);
        final cubit = WorkoutProgramDraftCubit(
          draft: draft,
          importer: f.importer,
        );
        cubit.renameProgram('Wrong account');
        expect(cubit.state.error, WorkoutDraftError.accountChanged);
        await cubit.close();
      },
    );
    test(
      'session snapshot targets stay unchanged after template target edits/replacement',
      () async {
        final draft = await f.draft();
        await f.importer.save(draft);
        final day = draft.days.first;
        final sessions = WorkoutSessionRepository(
          storageManager: f.storage,
          remoteDataSource: TemplateSessionRemote(),
          uidOverride: () => f.uid,
        );
        final session = await sessions.startWorkoutSession(
          programId: draft.programId,
          workoutTemplateId: day.id,
          workoutNameSnapshot: day.name,
          templateExerciseAssignments: day.exerciseAssignments,
        );
        final first = day.exerciseAssignments.first;
        await f.days.updateExerciseTargets(
          templateId: day.id,
          assignmentId: first.assignmentId,
          workingSets: 5,
          targetRepsMin: 10,
          targetRepsMax: 15,
          restSeconds: 90,
        );
        await f.days.replaceExerciseAssignment(
          templateId: day.id,
          assignmentId: first.assignmentId,
          exercise: const ExerciseLibraryItem(
            id: 'ex_dumbbell_bench_press',
            nameEn: 'Dumbbell Bench Press',
            source: ExerciseLibraryItemSource.builtIn,
          ),
          languageCode: 'en',
        );
        expect(
          (await f.days.getUserBox())
              .get(day.id)!
              .exerciseAssignments
              .first
              .workingSets,
          5,
        );
        final frozen = (await sessions.getUserBox())
            .get(session.id)!
            .templateExerciseAssignmentsSnapshot
            .first;
        expect(frozen.exerciseId, first.exerciseId);
        expect(frozen.workingSets, first.workingSets);
        expect(
          session.totalVolume,
          0,
        ); // planning never fabricates recorded sets
      },
    );
    test(
      'real four-field Hive bytes still decode, then roundtrip optional targets',
      () async {
        Hive.registerAdapter(_FourFieldAdapter(), override: true);
        final box = await Hive.openBox<WorkoutTemplateExerciseAssignment>(
          'legacy_assignments',
        );
        await box.put(
          'old',
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'legacy',
            exerciseId: 'manual',
            exerciseNameSnapshot: 'Old exercise',
            referenceType: 'manual',
          ),
        );
        await box.close();
        Hive.registerAdapter(
          WorkoutTemplateExerciseAssignmentAdapter(),
          override: true,
        );
        final reopened = await Hive.openBox<WorkoutTemplateExerciseAssignment>(
          'legacy_assignments',
        );
        final old = reopened.get('old')!;
        expect(old.workingSets, isNull);
        expect(old.hasTargets, isFalse);
        expect(old.toJson().keys, hasLength(4));
        await reopened.put(
          'new',
          old.copyWith(
            workingSets: 3,
            targetRepsMin: 8,
            targetRepsMax: 12,
            restSeconds: 120,
          ),
        );
        await reopened.close();
        final again = await Hive.openBox<WorkoutTemplateExerciseAssignment>(
          'legacy_assignments',
        );
        expect(again.get('new')!.restSeconds, 120);
        expect(again.get('old')!.assignmentId, 'legacy');
      },
    );
  });
}
