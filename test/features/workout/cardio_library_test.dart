import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/cardio_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_catalog_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_library.dart';
import 'package:ae_coaching/features/workout/domain/workout_limits.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/cardio_activity_visuals.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../support/fake_revision_cloud.dart';

class DaysCloud extends FakeRevisionCloud
    implements WorkoutTemplateRemoteDataSource {}

class CustomCloud extends FakeRevisionCloud
    implements CustomExerciseRemoteDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repdb = ExerciseCatalogRepository();
  late Directory dir;
  late UserStorageManager storage;
  late DaysCloud days;
  late CustomCloud customCloud;
  late WorkoutTemplateRepository templates;
  late CustomExerciseRepository customs;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cardio_library_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(WorkoutTemplateAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(CustomExerciseAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
    }
    storage = UserStorageManager();
    days = DaysCloud();
    customCloud = CustomCloud();
    templates = WorkoutTemplateRepository(
      remoteDataSource: days,
      storageManager: storage,
      uidOverride: () => 'cardio-user',
    );
    customs = CustomExerciseRepository(
      storageManager: storage,
      remoteDataSource: customCloud,
      uidOverride: () => 'cardio-user',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  CardioLibraryCatalog library() => CardioLibraryCatalog(
    catalog: CombinedExerciseLibraryCatalog(
      builtInCatalog: repdb,
      customExercises: customs,
    ),
    customExercises: customs,
    appDefinedNames: appDefinedCardioNames(),
  );

  group('the curated library', () {
    test('every RepDB activity is in the bundled catalog, with English and '
        'Arabic names', () async {
      final catalog = {for (final e in await repdb.loadCatalog()) e.id: e};
      for (final entry in CardioLibrary.entries) {
        if (entry.isAppDefined) continue;
        final item = catalog[entry.exerciseId];
        expect(item, isNotNull, reason: entry.exerciseId);
        expect(item!.nameEn.trim(), isNotEmpty, reason: entry.exerciseId);
        expect(item.nameAr.trim(), isNotEmpty, reason: entry.exerciseId);
      }
    });

    test('unique ids; the approved activities are all there, in their '
        'categories', () {
      final ids = [for (final e in CardioLibrary.entries) e.exerciseId];
      expect(ids.toSet(), hasLength(ids.length));
      Set<String> inCategory(CardioCategory category) => {
        for (final e in CardioLibrary.entries)
          if (e.category == category) e.exerciseId,
      };
      expect(
        inCategory(CardioCategory.machines),
        containsAll([
          'repdb:treadmill-running',
          'repdb:stationary-bike',
          'repdb:elliptical-trainer',
          'repdb:stair-climber',
          'repdb:rowing-machine',
          'repdb:ski-erg',
          CardioLibrary.airBike, // also Assault Bike
        ]),
      );
      expect(
        inCategory(CardioCategory.bodyweight),
        containsAll([
          'repdb:jump-rope',
          'repdb:jumping-jacks',
          'repdb:high-knees',
          'repdb:mountain-climbers',
          'repdb:burpees',
          CardioLibrary.shadowBoxing,
          'repdb:step-ups',
        ]),
      );
      expect(
        inCategory(CardioCategory.outdoor),
        containsAll([
          'repdb:walking',
          'repdb:running',
          'repdb:cycling',
          CardioLibrary.hiking,
          CardioLibrary.swimming,
        ]),
      );
    });

    test('the three app-defined activities use the approved translations', () {
      final names = appDefinedCardioNames();
      expect(names[CardioLibrary.shadowBoxing], (
        en: 'Shadow Boxing',
        ar: 'ملاكمة الظل',
      ));
      expect(names[CardioLibrary.hiking], (en: 'Hiking', ar: 'المشي الجبلي'));
      expect(names[CardioLibrary.swimming], (en: 'Swimming', ar: 'السباحة'));
    });
  });

  group('loading and search (bundled data only, no network)', () {
    test('the curated activities in order, then my cardio only', () async {
      await customs.createExercise(name: 'Sled drag'); // strength
      await customs.createExercise(
        name: 'Hill sprints',
        activityType: ActivityType.cardio,
      );
      final items = await library().load();
      expect(
        items.take(CardioLibrary.entries.length).map((i) => i.exerciseId),
        CardioLibrary.entries.map((e) => e.exerciseId),
      );
      final mine = items.where((i) => i.isCustom).toList();
      expect(mine.map((i) => i.nameEn), ['Hill sprints']);
      expect(mine.single.category, isNull);
      expect(mine.single.referenceType, WorkoutExerciseReferenceType.custom);
    });

    test(
      'Air Bike and Assault Bike are one activity, found by both names',
      () async {
        final items = await library().load();
        List<String> found(String query) => [
          for (final item in items)
            if (item.matches(query)) item.exerciseId,
        ];
        expect(found('assault bike'), [CardioLibrary.airBike]);
        expect(found('air bike'), contains(CardioLibrary.airBike));
        expect(found('أسولت'), [CardioLibrary.airBike]);
        expect(found('اسولت'), [CardioLibrary.airBike]); // alef variant
      },
    );

    test('found by its Arabic or English name', () async {
      final items = await library().load();
      final swimming = items.firstWhere(
        (i) => i.exerciseId == CardioLibrary.swimming,
      );
      expect(swimming.matches('السباحة'), isTrue);
      expect(swimming.matches('swim'), isTrue);
      expect(swimming.nameFor('ar'), 'السباحة');
      expect(swimming.nameFor('en'), 'Swimming');
      final treadmill = items.where((i) => i.matches('treadmill')).toList();
      expect(treadmill, hasLength(2));
    });
  });

  test(
    'the strength picker never shows custom cardio; custom strength stays',
    () async {
      await customs.createExercise(name: 'Sled drag');
      await customs.createExercise(
        name: 'Hill sprints',
        activityType: ActivityType.cardio,
      );
      final picker = CombinedExerciseLibraryCatalog(
        builtInCatalog: repdb,
        customExercises: customs,
      );
      final own = (await picker.search()).where(
        (item) => item.source == ExerciseLibraryItemSource.custom,
      );
      expect(own.map((item) => item.nameEn), ['Sled drag']);
    },
  );

  test('a custom cardio exercise is stored and synced as cardio; strength '
      'is stored exactly as before', () async {
    final cardio = await customs.createExercise(
      name: 'Hill sprints',
      activityType: ActivityType.cardio,
    );
    final strength = await customs.createExercise(name: 'Sled drag');
    final box = await customs.getUserBox();
    expect(box.get(cardio.id)!.activityType, 'cardio');
    expect(box.get(strength.id)!.activityType, isNull);
    await customs.syncWithCloud();
    expect(customCloud.docs[cardio.id]!['activityType'], 'cardio');
    expect(customCloud.docs[strength.id]!['activityType'], 'strength');
  });

  group('adding to a day', () {
    test('cardio: the default 20-minute plan, its own assignment id, synced '
        'as cardio; strength additions are unchanged', () async {
      final day = await templates.createTemplate(programId: 'p1', name: 'Mix');
      await templates.addExerciseAssignment(
        templateId: day.id,
        exerciseId: 'repdb:bench-press',
        exerciseNameSnapshot: 'Bench Press',
        referenceType: WorkoutExerciseReferenceType.builtIn,
      );
      final updated = await templates.addExerciseAssignment(
        templateId: day.id,
        exerciseId: CardioLibrary.airBike,
        exerciseNameSnapshot: 'Air Bike',
        referenceType: WorkoutExerciseReferenceType.builtIn,
        cardio: CardioLibrary.defaultPlan,
      );
      final [strength, cardio] = updated.exerciseAssignments;
      expect(strength.type, ActivityType.strength);
      expect(strength.activityType, isNull);
      expect(strength.cardioData, isNull);
      expect(cardio.type, ActivityType.cardio);
      expect(cardio.cardio!.mode, CardioMode.countdown);
      expect(cardio.cardio!.durationSeconds, 1200);
      expect(cardio.assignmentId, isNot(strength.assignmentId));

      await templates.syncWithCloud();
      final activities = days.docs[day.id]!['activities'] as List;
      expect(activities.map((a) => a['type']), ['strength', 'cardio']);
      expect(activities[1]['cardio']['durationSeconds'], 1200);
    });

    test(
      'the same cardio activity only once per day; the 40 limit applies',
      () async {
        final day = await templates.createTemplate(
          programId: 'p1',
          name: 'Cardio',
        );
        Future<WorkoutTemplate> add(String id, String name) =>
            templates.addExerciseAssignment(
              templateId: day.id,
              exerciseId: id,
              exerciseNameSnapshot: name,
              referenceType: WorkoutExerciseReferenceType.builtIn,
              cardio: CardioLibrary.defaultPlan,
            );
        await add('repdb:running', 'Running');
        await expectLater(
          add('repdb:running', 'Running'),
          throwsA(isA<DuplicateTemplateExerciseException>()),
        );
        for (var i = 1; i < WorkoutLimits.maxActivitiesPerDay; i++) {
          await add('cardio:test-$i', 'Activity $i');
        }
        await expectLater(
          add('cardio:one-more', 'One more'),
          throwsA(isA<ActivityLimitExceededException>()),
        );
        final saved = (await templates.getUserBox()).get(day.id)!;
        expect(saved.exerciseAssignments, hasLength(40));
      },
    );

    test('an invalid plan is refused before anything is saved', () async {
      final day = await templates.createTemplate(programId: 'p1', name: 'X');
      await expectLater(
        templates.addExerciseAssignment(
          templateId: day.id,
          exerciseId: 'repdb:running',
          exerciseNameSnapshot: 'Running',
          referenceType: WorkoutExerciseReferenceType.builtIn,
          cardio: const CardioPlan(
            mode: CardioMode.countdown,
            durationSeconds: -5,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        (await templates.getUserBox()).get(day.id)!.exerciseAssignments,
        isEmpty,
      );
    });

    test('replacing a cardio activity keeps its plan', () async {
      final day = await templates.createTemplate(programId: 'p1', name: 'R');
      final added = await templates.addExerciseAssignment(
        templateId: day.id,
        exerciseId: 'repdb:running',
        exerciseNameSnapshot: 'Running',
        referenceType: WorkoutExerciseReferenceType.builtIn,
        cardio: CardioLibrary.defaultPlan,
      );
      final replaced = await templates.replaceExerciseAssignment(
        templateId: day.id,
        assignmentId: added.exerciseAssignments.single.assignmentId,
        exercise: const CardioLibraryItem(
          exerciseId: CardioLibrary.swimming,
          nameEn: 'Swimming',
          nameAr: 'السباحة',
        ).toLibraryItem(),
        languageCode: 'ar',
      );
      final activity = replaced.exerciseAssignments.single;
      expect(activity.exerciseId, CardioLibrary.swimming);
      expect(activity.exerciseNameSnapshot, 'السباحة');
      expect(activity.type, ActivityType.cardio);
      expect(activity.cardio!.durationSeconds, 1200);
    });
  });

  test('plan summaries in English and Arabic', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(
      cardioPlanSummary(en, CardioLibrary.defaultPlan),
      'Countdown · 20 min',
    );
    expect(
      cardioPlanSummary(ar, CardioLibrary.defaultPlan),
      'عد تنازلي · 20 دقيقة',
    );
    expect(
      cardioPlanSummary(
        ar,
        const CardioPlan(mode: CardioMode.stopwatch, durationSeconds: 60),
      ),
      'ساعة إيقاف · دقيقة واحدة',
    );
    expect(
      cardioPlanSummary(en, const CardioPlan(mode: CardioMode.stopwatch)),
      'Stopwatch',
    );
  });

  group('RepDB activities used as cardio (Step-Ups)', () {
    test('keeps its cardio type and plan through saving, reopening, the '
        'cloud and another phone; RepDB still lists it as strength', () async {
      final stepUps = (await repdb.loadCatalog()).firstWhere(
        (item) => item.id == 'repdb:step-ups',
      );
      expect(stepUps.category, 'strength'); // RepDB's own category

      final cardioDay = await templates.createTemplate(
        programId: 'p1',
        name: 'Conditioning',
      );
      final strengthDay = await templates.createTemplate(
        programId: 'p1',
        name: 'Legs',
      );
      await templates.addExerciseAssignment(
        templateId: cardioDay.id,
        exerciseId: 'repdb:step-ups',
        exerciseNameSnapshot: stepUps.nameEn,
        referenceType: WorkoutExerciseReferenceType.builtIn,
        cardio: CardioLibrary.defaultPlan,
      );
      // The same RepDB exercise as strength, on another day: unaffected.
      await templates.addExerciseAssignment(
        templateId: strengthDay.id,
        exerciseId: 'repdb:step-ups',
        exerciseNameSnapshot: stepUps.nameEn,
        referenceType: WorkoutExerciseReferenceType.builtIn,
      );
      await templates.syncWithCloud();

      // Reopened from disk (the app restarted).
      await Hive.close();
      final reopened = WorkoutTemplateRepository(
        remoteDataSource: days,
        storageManager: UserStorageManager(),
        uidOverride: () => 'cardio-user',
      );
      final box = await reopened.getUserBox();
      final asCardio = box.get(cardioDay.id)!.exerciseAssignments.single;
      final asStrength = box.get(strengthDay.id)!.exerciseAssignments.single;
      expect(asCardio.type, ActivityType.cardio);
      expect(asCardio.cardio!.durationSeconds, 1200);
      expect(asStrength.type, ActivityType.strength);
      expect(asStrength.cardioData, isNull);

      final cloudActivity =
          (days.docs[cardioDay.id]!['activities'] as List).single as Map;
      expect(cloudActivity['type'], 'cardio');
      expect(cloudActivity['exerciseId'], 'repdb:step-ups');
      expect(cloudActivity['cardio']['durationSeconds'], 1200);

      final otherPhone = WorkoutTemplateRepository(
        remoteDataSource: days,
        storageManager: UserStorageManager(),
        uidOverride: () => 'cardio-user-phone-2',
      );
      await otherPhone.syncWithCloud();
      final received = (await otherPhone.getUserBox())
          .get(cardioDay.id)!
          .exerciseAssignments
          .single;
      expect(received.type, ActivityType.cardio);
      expect(received.cardio!.mode, CardioMode.countdown);

      // RepDB itself is never changed.
      final again = (await ExerciseCatalogRepository().loadCatalog())
          .firstWhere((item) => item.id == 'repdb:step-ups');
      expect(again.category, 'strength');
    });
  });

  group('reading saved plans safely', () {
    test('malformed values read as missing (never throw); the stored data '
        'is kept as it is', () {
      final plan = CardioPlan.fromMap({
        'mode': 'countdown',
        'durationSeconds': '20', // text, not a number
        'speedKmh': double.nan,
        'rounds': null,
      })!;
      expect(plan.mode, CardioMode.countdown);
      expect(plan.durationSeconds, isNull);
      expect(plan.speedKmh, isNull);
      expect(CardioPlan.fromMap({'mode': 'swim'}), isNull); // unknown mode
      expect(
        TimedPlan.fromMap({'sets': 'three', 'durationSeconds': 30}),
        isNull,
      );

      final raw = {'mode': 'countdown', 'durationSeconds': '20'};
      final assignment = WorkoutTemplateExerciseAssignment.fromActivityMap({
        'id': 'a1',
        'type': 'cardio',
        'exerciseId': 'repdb:running',
        'referenceType': 'builtIn',
        'name': 'Running',
        'cardio': raw,
      });
      expect(assignment.type, ActivityType.cardio);
      expect(assignment.cardio!.durationSeconds, isNull);
      expect(assignment.toActivityMap()['cardio'], raw); // round trip intact
    });

    test(
      'an unknown activity type reads as strength (shown, never a crash)',
      () {
        final assignment = WorkoutTemplateExerciseAssignment.fromActivityMap({
          'id': 'a1',
          'type': 'yoga',
          'exerciseId': 'x',
          'referenceType': 'builtIn',
          'name': 'Future activity',
        });
        expect(assignment.type, ActivityType.strength);
      },
    );
  });

  group('cardio settings (Stage 4)', () {
    Future<WorkoutTemplate> mixedDay() async {
      final day = await templates.createTemplate(programId: 'p1', name: 'Mix');
      await templates.addExerciseAssignment(
        templateId: day.id,
        exerciseId: 'repdb:bench-press',
        exerciseNameSnapshot: 'Bench Press',
        referenceType: WorkoutExerciseReferenceType.builtIn,
      );
      await templates.addExerciseAssignment(
        templateId: day.id,
        exerciseId: 'repdb:treadmill-running',
        exerciseNameSnapshot: 'Treadmill Running',
        referenceType: WorkoutExerciseReferenceType.builtIn,
        cardio: CardioLibrary.defaultPlan,
      );
      return templates.addExerciseAssignment(
        templateId: day.id,
        exerciseId: 'repdb:squat',
        exerciseNameSnapshot: 'Squat',
        referenceType: WorkoutExerciseReferenceType.builtIn,
      );
    }

    test('saved: the plan changes; id, name, place and the strength '
        'activities around it do not; it syncs', () async {
      final day = await mixedDay();
      final before = day.exerciseAssignments;
      const plan = CardioPlan(
        mode: CardioMode.intervals,
        workSeconds: 40,
        intervalRestSeconds: 20,
        rounds: 10,
        intensity: CardioIntensity.high,
        speedKmh: 12.5,
        inclinePercent: 2,
      );
      final updated = await templates.updateCardioPlan(
        templateId: day.id,
        assignmentId: before[1].assignmentId,
        plan: plan,
      );
      final after = updated.exerciseAssignments;
      expect(
        after.map((a) => a.assignmentId),
        before.map((a) => a.assignmentId),
      );
      expect(after[0].toActivityMap(), before[0].toActivityMap());
      expect(after[2].toActivityMap(), before[2].toActivityMap());
      expect(after[1].exerciseNameSnapshot, 'Treadmill Running');
      expect(after[1].cardio!.mode, CardioMode.intervals);
      expect(after[1].cardio!.rounds, 10);
      expect(after[1].cardio!.speedKmh, 12.5);

      await templates.syncWithCloud();
      final cloud = (days.docs[day.id]!['activities'] as List)[1] as Map;
      expect(cloud['type'], 'cardio');
      expect(cloud['cardio']['mode'], 'intervals');
      expect(cloud['cardio']['intensity'], 'high');
    });

    test('settings another app version wrote are kept', () async {
      final day = await templates.createTemplate(programId: 'p1', name: 'K');
      final box = await templates.getUserBox();
      await box.put(
        day.id,
        day.copyWith(
          exerciseAssignments: [
            WorkoutTemplateExerciseAssignment.fromActivityMap({
              'id': 'run',
              'type': 'cardio',
              'exerciseId': 'repdb:running',
              'referenceType': 'builtIn',
              'name': 'Running',
              'cardio': {
                'mode': 'countdown',
                'durationSeconds': 1200,
                'paceSecondsPerKm': 330, // from a newer version
              },
            }),
          ],
        ),
      );
      final updated = await templates.updateCardioPlan(
        templateId: day.id,
        assignmentId: 'run',
        plan: const CardioPlan(
          mode: CardioMode.countdown,
          durationSeconds: 1800,
        ),
      );
      final stored = updated.exerciseAssignments.single.cardioData!;
      expect(stored['durationSeconds'], 1800);
      expect(stored['paceSecondsPerKm'], 330);
    });

    test(
      'an invalid plan or a strength exercise: refused, nothing saved',
      () async {
        final day = await mixedDay();
        final cardioId = day.exerciseAssignments[1].assignmentId;
        await expectLater(
          templates.updateCardioPlan(
            templateId: day.id,
            assignmentId: cardioId,
            plan: const CardioPlan(
              mode: CardioMode.intervals,
            ), // no work/rounds
          ),
          throwsArgumentError,
        );
        await expectLater(
          templates.updateCardioPlan(
            templateId: day.id,
            assignmentId: day.exerciseAssignments[0].assignmentId,
            plan: CardioLibrary.defaultPlan,
          ),
          throwsStateError,
        );
        final saved = (await templates.getUserBox()).get(day.id)!;
        expect(saved.exerciseAssignments[1].cardio!.durationSeconds, 1200);
        expect(saved.exerciseAssignments[0].type, ActivityType.strength);
      },
    );
  });

  group('Undo of a removal (restoreExerciseAssignment)', () {
    test('the same entry back at its place, synced; repeating it changes '
        'nothing', () async {
      final day = await templates.createTemplate(programId: 'p1', name: 'U');
      for (final (id, name) in [
        ('repdb:a', 'A'),
        ('repdb:b', 'B'),
        ('repdb:c', 'C'),
      ]) {
        await templates.addExerciseAssignment(
          templateId: day.id,
          exerciseId: id,
          exerciseNameSnapshot: name,
          referenceType: WorkoutExerciseReferenceType.builtIn,
          cardio: id == 'repdb:b' ? CardioLibrary.defaultPlan : null,
        );
      }
      final before = (await templates.getUserBox()).get(day.id)!;
      final middle = before.exerciseAssignments[1];
      await templates.removeExerciseAssignment(
        templateId: day.id,
        assignmentId: middle.assignmentId,
      );
      await templates.syncWithCloud();
      expect(days.docs[day.id]!['activities'] as List, hasLength(2));

      final restored = await templates.restoreExerciseAssignment(
        templateId: day.id,
        assignment: middle,
        index: 1,
      );
      expect(
        restored.exerciseAssignments.map((a) => a.toActivityMap()),
        before.exerciseAssignments.map((a) => a.toActivityMap()),
      );
      final again = await templates.restoreExerciseAssignment(
        templateId: day.id,
        assignment: middle,
        index: 1,
      );
      expect(again.exerciseAssignments, hasLength(3));
      await templates.syncWithCloud();
      final cloud = days.docs[day.id]!['activities'] as List;
      expect(
        cloud.map((a) => a['id']),
        restored.exerciseAssignments.map((a) => a.assignmentId),
      );
      expect(cloud[1]['cardio']['durationSeconds'], 1200);
    });

    test(
      'refused when the exercise is back already or the day is full',
      () async {
        final day = await templates.createTemplate(programId: 'p1', name: 'F');
        final added = await templates.addExerciseAssignment(
          templateId: day.id,
          exerciseId: 'repdb:running',
          exerciseNameSnapshot: 'Running',
          referenceType: WorkoutExerciseReferenceType.builtIn,
          cardio: CardioLibrary.defaultPlan,
        );
        final removed = added.exerciseAssignments.single;
        await templates.removeExerciseAssignment(
          templateId: day.id,
          assignmentId: removed.assignmentId,
        );
        await templates.addExerciseAssignment(
          templateId: day.id,
          exerciseId: 'repdb:running',
          exerciseNameSnapshot: 'Running',
          referenceType: WorkoutExerciseReferenceType.builtIn,
          cardio: CardioLibrary.defaultPlan,
        ); // added again meanwhile
        await expectLater(
          templates.restoreExerciseAssignment(
            templateId: day.id,
            assignment: removed,
            index: 0,
          ),
          throwsA(isA<DuplicateTemplateExerciseException>()),
        );

        final full = await templates.createTemplate(
          programId: 'p1',
          name: 'Full',
        );
        for (var i = 0; i < WorkoutLimits.maxActivitiesPerDay; i++) {
          await templates.addExerciseAssignment(
            templateId: full.id,
            exerciseId: 'cardio:x$i',
            exerciseNameSnapshot: 'X$i',
            referenceType: WorkoutExerciseReferenceType.builtIn,
          );
        }
        await expectLater(
          templates.restoreExerciseAssignment(
            templateId: full.id,
            assignment: removed,
            index: 0,
          ),
          throwsA(isA<ActivityLimitExceededException>()),
        );
      },
    );
  });
}
