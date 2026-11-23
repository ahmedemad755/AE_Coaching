import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/workout_limits.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../support/fake_revision_cloud.dart';
import 'package:ae_coaching/core/sync/revision_sync_engine.dart';

class DaysCloud extends FakeRevisionCloud
    implements WorkoutTemplateRemoteDataSource {}

class CustomCloud extends FakeRevisionCloud
    implements CustomExerciseRemoteDataSource {}

/// One phone of the same account (its own local boxes, the shared cloud).
class Phone {
  Phone(
    String uid,
    UserStorageManager storage,
    DaysCloud days,
    CustomCloud custom,
  ) : templates = WorkoutTemplateRepository(
        remoteDataSource: days,
        storageManager: storage,
        uidOverride: () => uid,
      ),
      customExercises = CustomExerciseRepository(
        storageManager: storage,
        remoteDataSource: custom,
        uidOverride: () => uid,
      );

  final WorkoutTemplateRepository templates;
  final CustomExerciseRepository customExercises;

  Future<Box<WorkoutTemplate>> box() => templates.getUserBox();
  Future<WorkoutTemplate?> day(String id) async => (await box()).get(id);
  Future<void> sync() async => templates.fetchAndSyncFromRemote(await box());
}

List<String> ids(WorkoutTemplate? day) => [
  for (final a in day?.exerciseAssignments ?? const []) a.assignmentId,
];

List<String> cloudIds(Map<String, dynamic> doc) => [
  for (final a in doc['activities'] as List) a['id'] as String,
];

void main() {
  late Directory dir;
  late DaysCloud days;
  late CustomCloud custom;
  late Phone a;
  late Phone b;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cloud_sync_repo_');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(WorkoutTemplateAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(CustomExerciseAdapter());
    }
    final storage = UserStorageManager();
    days = DaysCloud();
    custom = CustomCloud();
    a = Phone('phone-a', storage, days, custom);
    b = Phone('phone-b', storage, days, custom);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<WorkoutTemplate> dayWithActivities(Phone phone) async {
    final day = await phone.templates.createTemplate(
      programId: 'p1',
      name: 'Push',
    );
    await phone.templates.addExerciseAssignment(
      templateId: day.id,
      exerciseId: 'repdb:bench-press',
      exerciseNameSnapshot: 'Bench press',
      referenceType: WorkoutExerciseReferenceType.builtIn,
    );
    await phone.templates.addExerciseAssignment(
      templateId: day.id,
      exerciseId: 'cardio:treadmill',
      exerciseNameSnapshot: 'Treadmill',
      referenceType: WorkoutExerciseReferenceType.builtIn,
    );
    // Make the second one a cardio activity (what Stage 4's screen will do).
    final box = await phone.box();
    final current = box.get(day.id)!;
    await box.put(
      day.id,
      current.copyWith(
        exerciseAssignments: [
          current.exerciseAssignments[0],
          current.exerciseAssignments[1].withActivity(
            type: ActivityType.cardio,
            cardio: const CardioPlan(
              mode: CardioMode.countdown,
              durationSeconds: 1200,
            ),
          ),
        ],
      ),
    );
    return box.get(day.id)!;
  }

  test(
    'a day with mixed activities reaches the cloud and another phone, in order',
    () async {
      final day = await dayWithActivities(a);
      expect(await a.templates.isConfirmedInCloud([day.id]), isFalse);
      await a.sync();
      expect(await a.templates.isConfirmedInCloud([day.id]), isTrue);

      final doc = days.docs[day.id]!;
      expect(doc['schemaVersion'], 2);
      expect(doc['revision'], 1);
      expect(cloudIds(doc), ids(day));
      expect((doc['activities'] as List)[1]['type'], 'cardio');

      await b.sync();
      final onB = await b.day(day.id);
      expect(ids(onB), ids(day));
      expect(onB!.exerciseAssignments[1].cardio!.durationSeconds, 1200);
    },
  );

  test(
    'reorder and delete: the cloud follows; deletion is a tombstone',
    () async {
      final day = await dayWithActivities(a);
      await a.sync();
      await b.sync();
      final order = ids(day).reversed.toList();
      await a.templates.reorderExerciseAssignments(
        templateId: day.id,
        orderedAssignmentIds: order,
      );
      await a.sync();
      expect(cloudIds(days.docs[day.id]!), order);
      await b.sync();
      expect(ids(await b.day(day.id)), order);

      await a.templates.deleteTemplate(day.id);
      expect(await a.day(day.id), isNull); // gone here immediately
      await a.sync();
      expect(days.docs[day.id]!['deleted'], isTrue); // never a raw delete
      await b.sync();
      expect(await b.day(day.id), isNull);
    },
  );

  test('the activity limit is enforced before anything is saved', () async {
    final day = await a.templates.createTemplate(programId: 'p1', name: 'Big');
    for (var i = 0; i < WorkoutLimits.maxActivitiesPerDay; i++) {
      await a.templates.addExerciseAssignment(
        templateId: day.id,
        exerciseId: 'repdb:e$i',
        exerciseNameSnapshot: 'Exercise $i',
        referenceType: WorkoutExerciseReferenceType.builtIn,
      );
    }
    await expectLater(
      a.templates.addExerciseAssignment(
        templateId: day.id,
        exerciseId: 'repdb:one-too-many',
        exerciseNameSnapshot: 'One too many',
        referenceType: WorkoutExerciseReferenceType.builtIn,
      ),
      throwsA(isA<ActivityLimitExceededException>()),
    );
    expect(
      (await a.day(day.id))!.exerciseAssignments,
      hasLength(WorkoutLimits.maxActivitiesPerDay),
    );
  });

  test(
    'old exercises on a new phone: offered with a preview, restored only on confirmation',
    () async {
      days.docs['old-day'] = {
        'id': 'old-day',
        'programId': 'p1',
        'name': 'Legs',
        'createdAt': '2026-09-01T00:00:00.000Z',
        'updatedAt': '2026-09-02T00:00:00.000Z',
        'isArchived': false,
        'exerciseAssignments': [
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'sq',
            exerciseId: 'repdb:squat',
            exerciseNameSnapshot: 'Squat',
            referenceType: 'builtIn',
          ).toJson(),
        ],
      };
      await b.sync();
      expect(ids(await b.day('old-day')), isEmpty); // nothing silently imported
      final issue = (await b.templates.syncIssues()).single;
      expect(issue.promptsUser, isTrue);
      expect(issue.olderExercises.single.exerciseNameSnapshot, 'Squat');
      expect(issue.olderSavedAt, DateTime.utc(2026, 9, 2));
      expect(days.docs['old-day']!['schemaVersion'], isNull); // still untouched

      await b.templates.restoreOlderExercises('old-day');
      await b.sync();
      expect(ids(await b.day('old-day')), ['sq']);
      expect(days.docs['old-day']!['legacyDecision'], 'restored');
      expect(cloudIds(days.docs['old-day']!), ['sq']);
      expect(
        days.docs['old-day']!['exerciseAssignments'],
        hasLength(1),
      ); // kept
      expect(await b.templates.syncIssues(), isEmpty);

      await a.sync(); // the other phone is never asked again
      expect(await a.templates.syncIssues(), isEmpty);
      expect(ids(await a.day('old-day')), ['sq']);
    },
  );

  test(
    'dismissing old exercises is remembered and syncs an empty day',
    () async {
      days.docs['old-day'] = {
        'id': 'old-day',
        'programId': 'p1',
        'name': 'Legs',
        'createdAt': '2026-09-01T00:00:00.000Z',
        'isArchived': false,
        'exerciseAssignments': [
          WorkoutTemplateExerciseAssignment(
            assignmentId: 'sq',
            exerciseId: 'repdb:squat',
            exerciseNameSnapshot: 'Squat',
            referenceType: 'builtIn',
          ).toJson(),
        ],
      };
      await b.sync();
      await b.templates.dismissOlderExercises('old-day');
      await b.sync();
      expect(days.docs['old-day']!['legacyDecision'], 'dismissed');
      expect(days.docs['old-day']!['activities'], isEmpty);
      expect(await b.templates.syncIssues(), isEmpty);
    },
  );

  test(
    'a conflict through the repository: keep mine / keep the cloud version',
    () async {
      final day = await dayWithActivities(a);
      await a.sync();
      await b.sync();
      // Each edit also starts a background sync, so the order is fixed:
      // A's edit reaches the cloud, then B edits its now outdated copy.
      await a.templates.updateTemplate(templateId: day.id, name: 'From A');
      await a.sync();
      await b.templates.updateTemplate(templateId: day.id, name: 'From B');
      await b.sync();
      expect(await a.templates.syncIssues(), isEmpty);
      final issue = (await b.templates.syncIssues()).single;
      expect(issue.isConflict, isTrue);
      expect(issue.day.name, 'From A'); // the cloud version is shown
      expect(issue.myVersion!.name, 'From B');

      await b.templates.keepMyVersion(day.id);
      await b.sync();
      expect(days.docs[day.id]!['name'], 'From B');
      expect(await b.templates.syncIssues(), isEmpty);
      // The copy is kept until explicitly discarded.
      final engine = await b.templates.syncEngine();
      final copy = engine.conflictCopies().single;
      await b.templates.discardConflictCopy(copy['key'] as String);
      expect(engine.conflictCopies(), isEmpty);
    },
  );

  test(
    'the migration marker is written only after verification against the server',
    () async {
      await dayWithActivities(a);
      days.offline = true;
      await a.sync();
      expect(await a.templates.migrationMarker(), isNull);
      days.offline = false;
      await a.sync();
      final marker = await a.templates.migrationMarker();
      expect(marker!['days'], 1);
      expect(marker['verifiedAt'], isA<String>());
    },
  );

  test(
    'custom exercises: stable ids, re-syncing or another phone never duplicates',
    () async {
      final made = await a.customExercises.createExercise(name: 'Sled push');
      await a.customExercises.syncWithCloud();
      expect(custom.docs.keys, [made.id]);
      expect(custom.docs[made.id]!['revision'], 1);

      // An interrupted migration: the sync state is lost locally.
      final box = await a.customExercises.getUserBox();
      await box.put(made.id, box.get(made.id)!.withSyncMeta(SyncMeta.empty));
      final accepted = custom.accepted;
      await a.customExercises.syncWithCloud();
      expect(custom.docs, hasLength(1));
      expect(custom.accepted, accepted); // identical: adopted, not rewritten

      await b.customExercises.syncWithCloud();
      await b.customExercises.syncWithCloud();
      final onB = await b.customExercises.getAllExercises();
      expect(onB.map((e) => e.id), [made.id]);
      expect(onB.single.name, 'Sled push');
    },
  );

  Map<String, dynamic> oldDayWith(int count) => {
    'id': 'old-day',
    'programId': 'p1',
    'name': 'Legs',
    'createdAt': '2026-09-01T00:00:00.000Z',
    'updatedAt': '2026-09-02T00:00:00.000Z',
    'isArchived': false,
    'orderIndex': 0,
    'exerciseAssignments': [
      for (var i = 0; i < count; i++)
        WorkoutTemplateExerciseAssignment(
          assignmentId: 'old$i',
          exerciseId: 'repdb:old$i',
          exerciseNameSnapshot: 'Old $i',
          referenceType: 'builtIn',
        ).toJson(),
    ],
  };

  WorkoutTemplate oversizedDay(String id, int count) => WorkoutTemplate(
    id: id,
    programId: 'p1',
    name: 'Everything',
    createdAt: DateTime.utc(2026, 10),
    orderIndex: 0,
    exerciseAssignments: [
      for (var i = 0; i < count; i++)
        WorkoutTemplateExerciseAssignment(
          assignmentId: 'e$i',
          exerciseId: 'repdb:e$i',
          exerciseNameSnapshot: 'Exercise $i',
          referenceType: 'builtIn',
        ),
    ],
    syncData: SyncMeta.empty.migratedAsNew().toMap(),
  );

  test('restoring more old exercises than a day holds: none is cut, the rest '
      'go to a new day, in order, and everything syncs', () async {
    const limit = WorkoutLimits.maxActivitiesPerDay;
    days.docs['old-day'] = oldDayWith(limit + 7);
    await b.sync();
    final written = await b.templates.restoreOlderExercises('old-day');
    expect(written, hasLength(2));
    final day = (await b.day('old-day'))!;
    final extra = written.last;
    expect(ids(day), [for (var i = 0; i < limit; i++) 'old$i']);
    expect(ids(extra), [for (var i = limit; i < limit + 7; i++) 'old$i']);
    expect(extra.name, 'Legs (2)');
    expect(extra.programId, 'p1');
    expect(extra.orderIndex, 1); // after the day, at the end of the program

    await b.sync();
    expect(cloudIds(days.docs['old-day']!), ids(day));
    expect(cloudIds(days.docs[extra.id]!), ids(extra));
    expect(days.docs['old-day']!['exerciseAssignments'], hasLength(limit + 7));
    expect(days.docs['old-day']!['legacyDecision'], 'restored');
    expect(await b.templates.syncIssues(), isEmpty);
    await a.sync(); // the other phone gets both days
    expect(ids(await a.day(extra.id)), ids(extra));
  });

  test('a day with more activities than the cloud accepts is never sent: it is '
      'flagged, then split by the user, and both days sync', () async {
    const limit = WorkoutLimits.maxActivitiesPerDay;
    final box = await a.box();
    // E.g. kept from an older app version, which had no limit.
    await box.put('big', oversizedDay('big', limit + 5));
    final rejected = days.rejected;
    final report = await a.templates.syncWithCloud();
    expect(report.blocked, 1);
    expect(days.docs.containsKey('big'), isFalse); // never sent
    expect(days.rejected, rejected); // no refused write either
    expect(
      (await a.day('big'))!.syncMeta.blockedReason,
      '${RevisionSyncEngine.localBlockPrefix}tooManyActivities',
    );

    final written = await a.templates.splitOversizedDay('big');
    expect(written.map((d) => d.exerciseAssignments.length), [limit, 5]);
    await a.sync();
    expect(cloudIds(days.docs['big']!), ids(written.first));
    expect(cloudIds(days.docs[written.last.id]!), ids(written.last));
    expect((await a.day('big'))!.syncMeta.isBlocked, isFalse);
  });

  test(
    'an interrupted split is simply done again: nothing duplicated',
    () async {
      const limit = WorkoutLimits.maxActivitiesPerDay;
      final box = await a.box();
      final original = oversizedDay('big', limit + 3);
      await box.put('big', original);
      final first = await a.templates.splitOversizedDay('big');
      // As if the app stopped before the day itself was shortened.
      await box.put('big', original);
      final again = await a.templates.splitOversizedDay('big');
      expect(again.last.id, first.last.id);
      expect(box.values.where((d) => d.programId == 'p1'), hasLength(2));
      expect([
        ...ids(await a.day('big')),
        ...ids(await a.day(first.last.id)),
      ], ids(original));
    },
  );
}
