import 'dart:convert';
import 'dart:io';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program_draft.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/legacy_exercise_migration.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_draft_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/standard_template_fixtures.dart';

void main() {
  late StandardTemplateFixture f;
  late ExerciseCatalogRepository catalog;
  late WorkoutSessionRepository sessions;
  late Directory journals;
  LegacyExerciseMigration migration({
    Future<Directory> Function()? directory,
  }) => LegacyExerciseMigration(
    templates: f.days,
    sessions: sessions,
    catalog: catalog,
    currentUserId: () => f.uid,
    journalDirectory: directory ?? () async => journals,
  );
  Map<String, dynamic> snapshot(WorkoutTemplate day) => {
    ...day.toJson(),
    'exerciseAssignments': day.exerciseAssignments
        .map((e) => e.toJson())
        .toList(),
  };
  File journal() =>
      File('${journals.path}/${Uri.encodeComponent(f.uid)}/repdb-v1.json');
  // Historical content must be explicit: first-party templates now contain
  // canonical IDs and must no longer serve as fixtures for unresolved data.
  Future<WorkoutProgramDraft> legacyDraft() async {
    final draft = await f.draft();
    const originalIds = {
      'repdb:tricep-pushdown': 'ex_rope_triceps_pushdown',
      'repdb:leg-press': 'ex_leg_press_45',
      'repdb:close-grip-lat-pulldown': 'ex_neutral_grip_lat_pulldown',
    };
    return draft.copyWith(
      days: [
        for (final day in draft.days)
          day.copyWith(
            exerciseAssignments: [
              for (final assignment in day.exerciseAssignments)
                assignment.copyWith(
                  exerciseId:
                      originalIds[assignment.exerciseId] ??
                      assignment.exerciseId,
                ),
            ],
          ),
      ],
    );
  }

  Future<WorkoutTemplate> seed() async {
    final day = WorkoutTemplate(
      id: 'existing-day',
      programId: 'existing-program',
      name: 'Original day name',
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025, 2),
      orderIndex: 4,
      exerciseAssignments: [
        WorkoutTemplateExerciseAssignment(
          assignmentId: 'stable-assignment-1',
          exerciseId: 'ex_barbell_bench_press',
          exerciseNameSnapshot: 'My original bench name',
          referenceType: 'builtIn',
          workingSets: 4,
          targetRepsMin: 6,
          targetRepsMax: 9,
          restSeconds: 123,
        ),
        WorkoutTemplateExerciseAssignment(
          assignmentId: 'stable-assignment-2',
          exerciseId: 'ex_rope_triceps_pushdown',
          exerciseNameSnapshot: 'Original rope variation',
          referenceType: 'builtIn',
        ),
        WorkoutTemplateExerciseAssignment(
          assignmentId: 'stable-assignment-3',
          exerciseId: 'custom_original',
          exerciseNameSnapshot: 'My custom exercise',
          referenceType: 'custom',
        ),
      ],
    );
    await (await f.days.getUserBox()).put(day.id, day);
    return day;
  }

  setUp(() async {
    f = StandardTemplateFixture();
    await f.open();
    journals = Directory('${f.directory.path}/journals');
    catalog = ExerciseCatalogRepository(
      loadAsset: (path) => File(path).readAsString(),
    );
    sessions = WorkoutSessionRepository(
      storageManager: f.storage,
      remoteDataSource: TemplateSessionRemote(),
      uidOverride: () => f.uid,
    );
    await sessions.getUserBox();
    await f.days.getUserBox();
  });
  tearDown(() => f.close());

  test(
    'only exact reusable references migrate; targets, order, custom and unmatched names survive',
    () async {
      final original = await seed();
      final before = snapshot(original);
      expect(await migration().migrate(), 1);
      final changed = (await f.days.getUserBox()).get(original.id)!;
      expect(changed.exerciseAssignments.first.exerciseId, 'repdb:bench-press');
      final expected = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
      (expected['exerciseAssignments'] as List).first['exerciseId'] =
          'repdb:bench-press';
      expect(snapshot(changed), expected);
      expect(f.dayRemote.documents, isEmpty); // No new cloud behavior.
      expect(await migration().migrate(), 0);
      expect(await migration().rollback(), 1);
      expect(snapshot((await f.days.getUserBox()).get(original.id)!), before);
      expect(
        await migration().migrate(),
        0,
      ); // Rollback explicitly disables reapplication.
    },
  );

  test(
    'active session day and captured identities are protected; completed session remains immutable',
    () async {
      final original = await seed();
      final box = await sessions.getUserBox();
      final active = WorkoutSession(
        id: 'active',
        programId: original.programId,
        workoutTemplateId: original.id,
        workoutNameSnapshot: original.name,
        date: DateTime(2025),
        startedAt: DateTime(2025),
        status: 'inProgress',
        templateExerciseAssignmentsSnapshot: original.exerciseAssignments
            .map((a) => a.copyWith())
            .toList(),
        sessionExerciseNames: ['Session-only name'],
      );
      await box.put(active.id, active);
      expect(await migration().migrate(), 0);
      expect(
        (await f.days.getUserBox())
            .get(original.id)!
            .exerciseAssignments
            .first
            .exerciseId,
        'ex_barbell_bench_press',
      );
      final completed = active.copyWith(
        status: 'completed',
        completedAt: DateTime(2025, 3),
        totalVolume: 1234,
      );
      await box.put(active.id, completed);
      final historyBefore = completed.toJson();
      expect(await migration().migrate(), 1);
      expect(box.get(active.id)!.toJson(), historyBefore);
      expect(
        box
            .get(active.id)!
            .templateExerciseAssignmentsSnapshot
            .first
            .exerciseId,
        'ex_barbell_bench_press',
      );
      expect(box.get(active.id)!.sessionExerciseNames, ['Session-only name']);
    },
  );

  test(
    'prepared-before-write interruption resumes and is idempotent',
    () async {
      final original = await seed();
      await migration().migrate();
      final data =
          jsonDecode(await journal().readAsString()) as Map<String, dynamic>;
      final entries = data['entries'] as Map<String, dynamic>;
      (entries.values.single as Map)['phase'] = 'prepared';
      await journal().writeAsString(jsonEncode(data));
      await (await f.days.getUserBox()).put(
        original.id,
        WorkoutTemplate.fromJson(snapshot(original)),
      );
      expect(await migration().migrate(), 1);
      expect(await migration().migrate(), 0);
      final recovered = jsonDecode(await journal().readAsString()) as Map;
      expect((recovered['entries'] as Map).values.single['phase'], 'applied');
    },
  );

  test(
    'prepared-after-write interruption only finalizes the journal',
    () async {
      await seed();
      await migration().migrate();
      final data =
          jsonDecode(await journal().readAsString()) as Map<String, dynamic>;
      ((data['entries'] as Map).values.single as Map)['phase'] = 'prepared';
      await journal().writeAsString(jsonEncode(data));
      expect(await migration().migrate(), 0);
      expect(
        ((jsonDecode(await journal().readAsString()) as Map)['entries'] as Map)
            .values
            .single['phase'],
        'applied',
      );
    },
  );

  test('account change aborts before modifying the outgoing account', () async {
    final original = await seed();
    final oldBox = await f.days.getUserBox();
    final operation = migration(
      directory: () async {
        f.uid = 'Owner-B';
        return journals;
      },
    );
    await expectLater(operation.migrate(), throwsStateError);
    expect(snapshot(oldBox.get(original.id)!), snapshot(original));
    expect(await journals.exists(), isFalse);
  });

  test(
    'rollback does not overwrite a user edit made after migration',
    () async {
      final original = await seed();
      await migration().migrate();
      final box = await f.days.getUserBox();
      final changed = box
          .get(original.id)!
          .copyWith(name: 'User edited after migration');
      await box.put(original.id, changed);
      expect(await migration().rollback(), 0);
      expect(snapshot(box.get(original.id)!), snapshot(changed));
    },
  );

  test(
    'production importer refuses unmatched variations before writing any program',
    () async {
      final draft = await legacyDraft();
      final importer = WorkoutTemplateImportService(
        programs: f.programs,
        templates: f.days,
        currentUserId: () => f.uid,
        catalog: catalog,
      );
      await expectLater(
        importer.save(draft),
        throwsA(isA<UnresolvedLegacyExerciseException>()),
      );
      expect((await f.programs.getUserBox()).values, isEmpty);
      expect((await f.days.getUserBox()).values, isEmpty);
      expect(f.programRemote.documents, isEmpty);
      expect(f.dayRemote.documents, isEmpty);
    },
  );
  test(
    'builder can edit genuinely unresolved saved content without changing assignment IDs',
    () async {
      final draft = await legacyDraft();
      final cubit = WorkoutProgramDraftCubit(
        draft: draft,
        importer: WorkoutTemplateImportService(
          programs: f.programs,
          templates: f.days,
          currentUserId: () => f.uid,
          catalog: catalog,
        ),
      );
      addTearDown(cubit.close);
      await cubit.save();
      expect(cubit.state.error, WorkoutDraftError.legacyResolution);
      // Explicit user choices in the builder, never automatic equivalences.
      const choices = {
        'ex_rope_triceps_pushdown': 'repdb:tricep-pushdown',
        'ex_leg_press_45': 'repdb:leg-press',
        'ex_neutral_grip_lat_pulldown': 'repdb:close-grip-lat-pulldown',
      };
      for (final day in draft.days) {
        for (final assignment in day.exerciseAssignments) {
          if (!assignment.exerciseId.startsWith('ex_')) continue;
          final chosen = await catalog.resolveReference(
            choices[assignment.exerciseId]!,
          );
          cubit.replaceExercise(
            day.id,
            assignment.assignmentId,
            ExerciseLibraryItem.fromBuiltIn(chosen!),
            'ar',
          );
        }
      }
      final expected = cubit.state.draft;
      expect(
        expected.days
            .expand((day) => day.exerciseAssignments)
            .every((a) => a.exerciseId.startsWith('repdb:')),
        isTrue,
      );
      expect(
        expected.days
            .expand((day) => day.exerciseAssignments)
            .map((a) => a.assignmentId),
        draft.days
            .expand((day) => day.exerciseAssignments)
            .map((a) => a.assignmentId),
      );
      await cubit.save();
      expect(cubit.state.saved, isNotNull);
      expect(cubit.state.error, isNull);
      final box = await f.days.getUserBox();
      for (final day in expected.days) {
        expect(snapshot(box.get(day.id)!), snapshot(day));
      }
      expect((await f.programs.getUserBox()).values, hasLength(1));
      expect(await migration().migrate(), 0);
    },
  );
}
