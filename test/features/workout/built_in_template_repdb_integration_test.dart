import 'dart:convert';
import 'dart:io';

import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program_draft.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/standard_template_fixtures.dart';

class _SetsRemote implements WorkoutRemoteDataSource {
  @override
  Future<void> deleteMultipleSets(List<String> keys) async {}
  @override
  Future<void> deleteSet(String key) async {}
  @override
  Future<void> syncSet(String key, ExerciseSet set) async {}
  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSets() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StandardTemplateFixture f;
  setUp(() async {
    f = StandardTemplateFixture();
    await f.open();
  });
  tearDown(() async => f.close());

  test(
    'all bundled references are canonical, with names, instructions and offline media',
    () async {
      final templates = standardTemplateCatalog();
      final splits = await templates.loadTemplates();
      final active = {
        for (final e in await templates.catalog.loadCatalog()) e.id: e,
      };
      final source = jsonDecode(
        File(
          'lib/assets/data/standard_workout_templates.json',
        ).readAsStringSync(),
      );
      var occurrences = 0;
      final unique = <String>{};
      for (final s in source['splits']) {
        for (final v in s['variants']) {
          for (final d in v['days']) {
            final dayIds = <String>{};
            for (final row in d['exercises']) {
              final id = row['exercise_id'] as String;
              expect(id, startsWith('repdb:'));
              expect(
                dayIds.add(id),
                isTrue,
                reason: '${v['id']}/${d['id']}/$id',
              );
              final e = active[id]!;
              expect(e.isRepDb, isTrue);
              expect(e.nameEn, isNotEmpty);
              expect(e.nameAr, isNotEmpty);
              expect(e.primaryMuscles, isNotEmpty);
              // RepDB leaves equipment empty for some bodyweight movements.
              expect(
                e.equipment.isNotEmpty || e.isBodyweight,
                isTrue,
                reason: id,
              );
              expect(e.instructionsEn, isNotEmpty);
              final images = [
                e.startImage,
                e.peakImage,
                e.mainImage,
              ].whereType<String>();
              expect(images, isNotEmpty);
              for (final image in images) {
                expect(
                  File('lib/assets/repdb/$image').existsSync(),
                  isTrue,
                  reason: '$id/$image',
                );
              }
              unique.add(id);
              occurrences++;
            }
          }
        }
      }
      expect(splits, hasLength(7));
      expect(occurrences, 214);
      expect(unique, hasLength(38));
    },
  );

  for (final language in ['en', 'ar']) {
    for (final variantId in [
      'ppl_3',
      'ppl_6',
      'upper_lower_4',
      'full_body_3',
      'bro_5',
      'arnold_3',
      'arnold_6',
      'hybrid_5',
      'anterior_posterior_4',
    ]) {
      test(
        '$language $variantId saves, reopens, edits, tracks and completes every day with canonical identity',
        () async {
          final templates = standardTemplateCatalog();
          final splits = await templates.loadTemplates();
          final split = splits.singleWhere(
            (s) => s.variants.any((v) => v.id == variantId),
          );
          final variant = split.variants.singleWhere((v) => v.id == variantId);
          final draft = WorkoutProgramDraft.fromTemplate(
            split: split,
            variant: variant,
            languageCode: language,
            ownerUid: f.uid,
          );
          final result = await f.importer.save(draft);
          expect(result.cloudSyncIncomplete, isFalse);
          expect(result.program.id, draft.programId);
          await f.storage.closeForUser(f.uid);
          final sessions = WorkoutSessionRepository(
            storageManager: f.storage,
            remoteDataSource: TemplateSessionRemote(),
            uidOverride: () => f.uid,
          );
          final sets = SessionExerciseRepository(
            storageManager: f.storage,
            remoteDataSource: _SetsRemote(),
            uidOverride: () => f.uid,
          );
          final cubit = SessionExerciseCubit(
            repository: sets,
            sessionRepository: sessions,
          );
          addTearDown(cubit.close);
          for (var i = 0; i < draft.days.length; i++) {
            final expected = draft.days[i];
            var day = (await f.days.getUserBox()).get(expected.id)!;
            expect(
              day.exerciseAssignments.map((e) => e.toJson()),
              expected.exerciseAssignments.map((e) => e.toJson()),
            );
            final first = day.exerciseAssignments.first;
            await f.days.updateExerciseTargets(
              templateId: day.id,
              assignmentId: first.assignmentId,
              workingSets: 4,
              targetRepsMin: 8,
              targetRepsMax: 12,
              restSeconds: 120,
            );
            day = (await f.days.getUserBox()).get(day.id)!;
            expect(day.exerciseAssignments.first.exerciseId, first.exerciseId);
            expect(
              day.exerciseAssignments.first.assignmentId,
              first.assignmentId,
            );
            expect(day.exerciseAssignments.first.workingSets, 4);
            final session = await sessions.startWorkoutSession(
              programId: draft.programId,
              workoutTemplateId: day.id,
              workoutNameSnapshot: day.name,
              templateExerciseAssignments: day.exerciseAssignments,
            );
            expect(
              session.templateExerciseAssignmentsSnapshot.map(
                (e) => e.toJson(),
              ),
              day.exerciseAssignments.map((e) => e.toJson()),
            );
            await cubit.loadForSession(session);
            expect(cubit.state, isA<SessionExerciseLoaded>());
            expect(
              (cubit.state as SessionExerciseLoaded).rows.map(
                (r) => r.exerciseName,
              ),
              day.exerciseAssignments.map((e) => e.exerciseNameSnapshot),
            );
            for (final assignment in day.exerciseAssignments) {
              expect(
                (await templates.catalog.resolveReference(
                  assignment.exerciseId,
                ))!.isRepDb,
                isTrue,
              );
              await sets.addSet(
                programId: draft.programId,
                workoutTemplateId: day.id,
                workoutSessionId: session.id,
                exerciseName: assignment.exerciseNameSnapshot,
                weight: 20,
                reps: 10,
              );
            }
            final completed = await sessions.completeWorkoutSession(
              sessionId: session.id,
              totalVolume: day.exerciseAssignments.length * 200.0,
            );
            final summary = await cubit.buildCompletionSummary(completed);
            expect(
              summary.progressSummary.exerciseResults.map(
                (e) => e.exerciseName,
              ),
              day.exerciseAssignments.map((e) => e.exerciseNameSnapshot),
            );
            expect(
              summary.progressSummary.currentTotalVolume,
              day.exerciseAssignments.length * 200.0,
            );
            final history = sessions
                .getCompletedSessionsForTemplate(
                  await sessions.getUserBox(),
                  day.id,
                )
                .single;
            expect(
              history.templateExerciseAssignmentsSnapshot.map(
                (e) => e.exerciseId,
              ),
              expected.exerciseAssignments.map((e) => e.exerciseId),
            );
            expect(history.isCompleted, isTrue);
          }
          await f.storage.closeForUser(f.uid);
          expect(
            sessions.getCompletedSessionsForProgram(
              await sessions.getUserBox(),
              draft.programId,
            ),
            hasLength(draft.days.length),
          );
          // A subsequent workout uses the same IDs and name snapshots, so the
          // existing progress comparison finds the correct previous session.
          final firstDay = (await f.days.getUserBox()).get(
            draft.days.first.id,
          )!;
          final previous = sessions
              .getCompletedSessionsForTemplate(
                await sessions.getUserBox(),
                firstDay.id,
              )
              .single;
          final next = await sessions.startWorkoutSession(
            programId: draft.programId,
            workoutTemplateId: firstDay.id,
            workoutNameSnapshot: firstDay.name,
            templateExerciseAssignments: firstDay.exerciseAssignments,
          );
          for (final assignment in firstDay.exerciseAssignments) {
            await sets.addSet(
              programId: draft.programId,
              workoutTemplateId: firstDay.id,
              workoutSessionId: next.id,
              exerciseName: assignment.exerciseNameSnapshot,
              weight: 20,
              reps: 10,
            );
          }
          final repeated = await sessions.completeWorkoutSession(
            sessionId: next.id,
            totalVolume: firstDay.exerciseAssignments.length * 200.0,
          );
          final comparison = await cubit.buildCompletionSummary(repeated);
          expect(comparison.progressSummary.previousSessionId, previous.id);
          expect(comparison.progressSummary.volumeDeltaPercent, 0);
          expect(
            comparison.progressSummary.exerciseResults.every(
              (e) => e.previousSets.length == 1,
            ),
            isTrue,
          );
          expect(
            comparison.personalRecords,
            isEmpty,
          ); // Equal loads are not PRs.
          expect(
            repeated.templateExerciseAssignmentsSnapshot.map(
              (e) => e.exerciseId,
            ),
            previous.templateExerciseAssignmentsSnapshot.map(
              (e) => e.exerciseId,
            ),
          );
        },
      );
    }
  }

  test(
    'unresolved saved legacy content stays unchanged and still fails new-copy validation before writes',
    () async {
      final catalog = standardTemplateCatalog().catalog;
      final mappingBefore = File(
        'lib/assets/repdb/legacy-mapping.json',
      ).readAsBytesSync();
      final mappings = await catalog.loadLegacyMapping();
      expect(mappings, hasLength(35));
      var savedCopies = 0;
      for (final id in [
        'ex_rope_triceps_pushdown',
        'ex_leg_press_45',
        'ex_neutral_grip_lat_pulldown',
      ]) {
        expect(mappings.containsKey(id), isFalse);
        expect((await catalog.resolveReference(id))!.isRepDb, isFalse);
        final existing = await f.days.createTemplate(
          programId: 'existing-program',
          name: 'Saved legacy day',
        );
        await f.days.addExerciseAssignment(
          templateId: existing.id,
          exerciseId: id,
          exerciseNameSnapshot: 'Original variation',
          referenceType: WorkoutExerciseReferenceType.builtIn,
        );
        Future<String> snapshot() async {
          final saved = (await f.days.getUserBox()).get(existing.id)!;
          return jsonEncode({
            ...saved.toJson(),
            'exerciseAssignments': saved.exerciseAssignments
                .map((e) => e.toJson())
                .toList(),
          });
        }

        final before = await snapshot();
        final valid = await f.draft();
        final day = valid.days.first;
        final invalid = valid.copyWith(
          days: [
            day.copyWith(
              exerciseAssignments: [
                day.exerciseAssignments.first.copyWith(exerciseId: id),
              ],
            ),
            ...valid.days.skip(1),
          ],
        );
        await expectLater(
          f.importer.save(invalid),
          throwsA(
            isA<UnresolvedLegacyExerciseException>().having(
              (e) => e.exerciseId,
              'exerciseId',
              id,
            ),
          ),
        );
        expect((await f.programs.getUserBox()).length, savedCopies);
        expect((await f.days.getUserBox()).containsKey(day.id), isFalse);
        await f.importer.save(valid);
        savedCopies++;
        expect(await snapshot(), before);
        expect((await f.programs.getUserBox()).length, savedCopies);
      }
      expect(
        File('lib/assets/repdb/legacy-mapping.json').readAsBytesSync(),
        mappingBefore,
      );
    },
  );
}
