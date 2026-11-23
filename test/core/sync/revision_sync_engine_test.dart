import 'dart:io';

import 'package:ae_coaching/core/sync/revision_cloud.dart';
import 'package:ae_coaching/core/sync/revision_sync_engine.dart';
import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/sync/workout_sync_adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../support/fake_revision_cloud.dart';

/// A simulated process kill: an Error, which the engine never swallows.
class _Crash extends Error {}

/// One phone: its own boxes and engine, sharing [cloud] with other phones.
class Device {
  Device(this.name, this.cloud);

  final String name;
  final FakeRevisionCloud cloud;
  late Box<WorkoutTemplate> records;
  late Box<Map> conflicts;
  late Box<Map> tombstones;
  late RevisionSyncEngine<WorkoutTemplate> engine;
  String? crashAt;
  var _writes = 0;

  Future<Device> open() async {
    records = await Hive.openBox<WorkoutTemplate>('templates_$name');
    conflicts = await Hive.openBox<Map>('conflicts_$name');
    tombstones = await Hive.openBox<Map>('tombstones_$name');
    engine = RevisionSyncEngine<WorkoutTemplate>(
      records: records,
      conflicts: conflicts,
      tombstones: tombstones,
      cloud: cloud,
      adapter: WorkoutTemplateSyncAdapter(),
      newWriteId: () =>
          '$name-${++_writes}-${DateTime.now().microsecondsSinceEpoch}',
      faultHook: (point) {
        if (point == crashAt) {
          crashAt = null;
          throw _Crash();
        }
      },
    );
    return this;
  }

  /// The app is killed and started again: boxes are reopened from disk.
  Future<void> restart() async {
    await records.close();
    await conflicts.close();
    await tombstones.close();
    await open();
  }

  WorkoutTemplate? day(String id) => records.get(id);

  Future<void> edit(String id, WorkoutTemplate Function(WorkoutTemplate) change) =>
      records.put(id, change(records.get(id)!));

  Future<SyncReport> sync() => engine.syncAll();
}

WorkoutTemplateExerciseAssignment exercise(String id, {int sets = 3}) =>
    WorkoutTemplateExerciseAssignment(
      assignmentId: id,
      exerciseId: 'repdb:$id',
      exerciseNameSnapshot: id,
      referenceType: 'builtIn',
      workingSets: sets,
      targetRepsMin: 8,
      targetRepsMax: 12,
      restSeconds: 90,
    );

/// A day created by the new app (ready to be created in the cloud).
WorkoutTemplate newDay(String id, List<String> exercises, {String name = 'Push'}) =>
    WorkoutTemplate(
      id: id,
      programId: 'p1',
      name: name,
      createdAt: DateTime.utc(2026, 11, 1),
      exerciseAssignments: [for (final e in exercises) exercise(e)],
      syncData: SyncMeta.empty.migratedAsNew().toMap(),
    );

/// A day as the current (pre-cloud) app stores it: never migrated.
WorkoutTemplate legacyDay(
  String id,
  List<String> exercises, {
  DateTime? updatedAt,
}) => WorkoutTemplate(
  id: id,
  programId: 'p1',
  name: 'Legacy',
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: updatedAt,
  exerciseAssignments: [for (final e in exercises) exercise(e)],
);

/// The old-format document the current app wrote (optionally with a stale
/// exercise list from an even older build).
Map<String, dynamic> legacyDoc(
  String id, {
  List<String>? staleList,
  String updatedAt = '2026-10-10T00:00:00.000Z',
}) => {
  'id': id,
  'programId': 'p1',
  'name': 'Legacy',
  'createdAt': '2026-10-01T00:00:00.000Z',
  'updatedAt': updatedAt,
  'isArchived': false,
  'orderIndex': 0,
  if (staleList != null)
    'exerciseAssignments': [for (final e in staleList) exercise(e).toJson()],
};

List<String> names(WorkoutTemplate? day) =>
    [for (final a in day?.exerciseAssignments ?? const []) a.assignmentId];

void main() {
  late Directory dir;
  late FakeRevisionCloud cloud;
  late Device a;
  late Device b;

  setUpAll(() {
    Hive.registerAdapter(WorkoutTemplateAdapter());
    Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('revision_sync_');
    Hive.init(dir.path);
    cloud = FakeRevisionCloud();
    a = await Device('a', cloud).open();
    b = await Device('b', cloud).open();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('A · optimistic concurrency', () {
    test('A1 two devices edit the same day from the same revision: one wins, '
        'the other keeps its version as a conflict copy, nothing is lost', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync();
      await b.sync();
      expect(cloud.docs['d1']!['revision'], 1);
      expect(names(b.day('d1')), ['bench']);

      await a.edit('d1', (d) => d.copyWith(name: 'Push (A)'));
      await b.edit(
        'd1',
        (d) => d.copyWith(exerciseAssignments: [...d.exerciseAssignments, exercise('fly')]),
      );

      await a.sync(); // A wins: revision 2
      expect(cloud.docs['d1']!['revision'], 2);
      final report = await b.sync(); // B is behind: conflict, not overwrite
      expect(report.conflicts, 1);
      expect(cloud.docs['d1']!['revision'], 2);
      expect(cloud.docs['d1']!['name'], 'Push (A)');
      expect(b.day('d1')!.name, 'Push (A)'); // shows the newer cloud version
      expect(b.day('d1')!.syncMeta.conflictReason, SyncConflictReason.editedElsewhere);
      final copy = b.engine.conflictCopies().single;
      expect(names(WorkoutTemplate.fromCloudContent(Map.from(copy['content'] as Map))), [
        'bench',
        'fly',
      ]);

      // B keeps its version: re-based EXPLICITLY on revision 2 → revision 3.
      await b.engine.keepMine('d1');
      await b.sync();
      expect(cloud.docs['d1']!['revision'], 3);
      expect(cloud.docs['d1']!['baseRevision'], 2);
      await a.sync(); // A fast-forwards to B's choice
      expect(names(a.day('d1')), ['bench', 'fly']);
      expect(b.engine.conflictCopies(), hasLength(1)); // kept until deleted
    });

    test('A1b a true race: both send from revision 1, the server takes exactly one', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync();
      await b.sync();
      await a.edit('d1', (d) => d.copyWith(name: 'A'));
      await b.edit('d1', (d) => d.copyWith(name: 'B'));
      // B's write lands while A's is on its way.
      cloud.beforeWrite = (id) async {
        cloud.beforeWrite = null;
        await b.sync();
      };
      final report = await a.sync();
      expect(cloud.docs['d1']!['name'], 'B');
      expect(cloud.docs['d1']!['revision'], 2);
      expect(report.conflicts, 1);
      expect(a.engine.conflictCopies().single['content']['name'], 'A');
    });

    test('A2 both edit offline, then reconnect: same protection', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync();
      await b.sync();
      cloud.offline = true;
      await a.edit('d1', (d) => d.copyWith(name: 'A offline'));
      await b.edit('d1', (d) => d.copyWith(name: 'B offline'));
      expect((await a.sync()).offline, isTrue);
      expect((await b.sync()).offline, isTrue);
      expect(cloud.accepted, 1);
      cloud.offline = false;
      await b.sync();
      await a.sync();
      expect(cloud.docs['d1']!['name'], 'B offline');
      expect(a.day('d1')!.syncMeta.hasConflict, isTrue);
    });

    test('A3 the same edit on both devices is not a conflict', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync();
      await b.sync();
      await a.edit('d1', (d) => d.copyWith(name: 'Same'));
      await b.edit('d1', (d) => d.copyWith(name: 'Same'));
      await a.sync();
      final report = await b.sync();
      expect(report.conflicts, 0);
      expect(b.day('d1')!.syncMeta.baseRevision, 2);
      expect(b.engine.conflictCopies(), isEmpty);
    });

    test('A4 an edit made while a write is in flight is kept, and sent next', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      cloud.beforeWrite = (id) async {
        cloud.beforeWrite = null;
        // The user reorders while the first write travels.
        await a.edit('d1', (d) => d.copyWith(name: 'edited in flight'));
      };
      await a.sync();
      // The server holds what was SENT; the newer local edit survived the
      // acknowledgement and is still marked as unsynced.
      expect(cloud.docs['d1']!['name'], 'Push');
      final local = a.day('d1')!;
      expect(local.name, 'edited in flight');
      expect(local.syncMeta.baseRevision, 1);
      expect(local.syncMeta.hasUnsyncedChanges(local.contentFingerprint), isTrue);
      await a.sync();
      expect(cloud.docs['d1']!['name'], 'edited in flight');
      expect(cloud.docs['d1']!['revision'], 2);
    });

    test('A4b changed and changed back during the flight: nothing left to send', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      cloud.beforeWrite = (id) async {
        cloud.beforeWrite = null;
        await a.edit('d1', (d) => d.copyWith(name: 'temp'));
        await a.edit('d1', (d) => d.copyWith(name: 'Push'));
      };
      await a.sync();
      final local = a.day('d1')!;
      expect(local.syncMeta.hasUnsyncedChanges(local.contentFingerprint), isFalse);
      final before = cloud.accepted;
      await a.sync();
      expect(cloud.accepted, before);
    });

    test('A5 a lost acknowledgement: after a restart the write is recognised as ours', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      cloud.loseNextAck = true;
      final report = await a.sync();
      expect(report.offline, isTrue);
      expect(cloud.docs['d1']!['revision'], 1); // it DID land
      await a.restart();
      await a.edit('d1', (d) => d.copyWith(name: 'after restart'));
      final second = await a.sync();
      expect(second.conflicts, 0);
      expect(cloud.docs['d1']!['revision'], 2);
      expect(cloud.docs['d1']!['name'], 'after restart');
    });

    test("A6 our own older write landing late is re-based on, not a conflict", () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync(); // rev 1
      await a.edit('d1', (d) => d.copyWith(name: 'v2'));
      cloud.offline = true;
      await a.sync(); // nothing sent
      cloud.offline = false;
      // Simulate Firestore's offline queue replaying an earlier copy of OUR
      // write: the server moves with one of our writeIds.
      await a.edit('d1', (d) => d.copyWith(name: 'v3'));
      final flightId = 'a-replayed';
      final meta = a.day('d1')!.syncMeta;
      await a.records.put(
        'd1',
        a.day('d1')!.withSyncMeta(
          SyncMeta.fromMap({...meta.toMap()!, 'recentWriteIds': [flightId]}),
        ),
      );
      cloud.docs['d1'] = {
        ...cloud.docs['d1']!,
        'name': 'v2',
        'revision': 2,
        'baseRevision': 1,
        'writeId': flightId,
        'contentHash': 'f' * 64,
      };
      final report = await a.sync();
      expect(report.conflicts, 0);
      expect(cloud.docs['d1']!['name'], 'v3');
      expect(cloud.docs['d1']!['revision'], 3);
    });

    test('A7 deleted here, edited elsewhere: the day comes back, the user decides', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync();
      await b.sync();
      await a.engine.markDeleted('d1'); // tombstone based on revision 1
      expect(a.day('d1'), isNull);
      await b.edit('d1', (d) => d.copyWith(name: 'kept by B'));
      await b.sync(); // revision 2
      final report = await a.sync(); // tombstone refused (stale base)
      expect(report.conflicts, 1);
      expect(cloud.docs['d1']!['deleted'], isFalse);
      expect(a.day('d1')!.name, 'kept by B');
      expect(
        a.day('d1')!.syncMeta.conflictReason,
        SyncConflictReason.deletedHereEditedElsewhere,
      );
      // "Delete anyway": a new tombstone based on revision 2.
      await a.engine.keepMine('d1');
      await a.sync();
      expect(cloud.docs['d1']!['deleted'], isTrue);
      expect(cloud.docs['d1']!['revision'], 3);
      await b.sync();
      expect(b.day('d1'), isNull); // B had no unsent edits: removed
    });

    test('A7b edited here, deleted elsewhere: kept as a conflict, restorable', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync();
      await b.sync();
      await b.engine.markDeleted('d1');
      await b.sync();
      await a.edit('d1', (d) => d.copyWith(name: 'still mine'));
      await a.sync();
      expect(a.day('d1')!.syncMeta.conflictReason, SyncConflictReason.deletedElsewhere);
      expect(a.day('d1')!.name, 'still mine');
      await a.engine.keepMine('d1'); // restore
      await a.sync();
      expect(cloud.docs['d1']!['deleted'], isFalse);
      expect(cloud.docs['d1']!['name'], 'still mine');
      await b.sync();
      expect(b.day('d1')!.name, 'still mine');
    });

    test('A8 the server refuses a stale base, a skipped revision and a reused writeId', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync();
      await a.edit('d1', (d) => d.copyWith(name: 'x'));
      await a.sync(); // revision 2
      final doc = cloud.docs['d1']!;
      Map<String, dynamic> payload(int base, int revision, String writeId) => {
        ...doc,
        'baseRevision': base,
        'revision': revision,
        'writeId': writeId,
        'name': 'stale',
      };
      for (final bad in [
        payload(1, 2, 'w1'), // stale base
        payload(2, 4, 'w2'), // skipped revision
        payload(2, 3, doc['writeId'] as String), // reused writeId
      ]) {
        await expectLater(cloud.write('d1', bad), throwsA(isA<CloudWriteRejected>()));
      }
      expect(cloud.docs['d1']!['name'], 'x');
      expect(cloud.docs['d1']!['revision'], 2);
    });
  });

  group('B · crash safety', () {
    test('B1 killed after recording the write, before sending it', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      a.crashAt = 'flightRecorded';
      await expectLater(a.sync(), throwsA(isA<_Crash>()));
      expect(cloud.docs, isEmpty);
      await a.restart();
      await a.sync();
      expect(cloud.docs['d1']!['revision'], 1);
      expect(a.day('d1')!.syncMeta.hasFlight, isFalse);
    });

    test('B1 killed after the server applied it, before the acknowledgement', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      a.crashAt = 'cloudWritten';
      await expectLater(a.sync(), throwsA(isA<_Crash>()));
      expect(cloud.docs['d1']!['revision'], 1);
      await a.restart();
      final accepted = cloud.accepted;
      await a.sync();
      expect(cloud.accepted, accepted); // recognised, not sent twice
      expect(a.day('d1')!.syncMeta.baseRevision, 1);
    });

    test('B1 killed between recording a deletion and removing the day', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync();
      a.crashAt = 'tombstoneRecorded';
      await expectLater(a.engine.markDeleted('d1'), throwsA(isA<_Crash>()));
      expect(a.day('d1'), isNotNull); // half done
      await a.restart();
      await a.sync();
      expect(a.day('d1'), isNull);
      expect(cloud.docs['d1']!['deleted'], isTrue);
      expect(a.tombstones.isEmpty, isTrue);
    });

    test('B3 killed right after saving a conflict copy: resumed, never duplicated', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync();
      await b.sync();
      await a.edit('d1', (d) => d.copyWith(name: 'A'));
      await a.sync();
      await b.edit('d1', (d) => d.copyWith(name: 'B'));
      b.crashAt = 'conflictCopySaved';
      await expectLater(b.sync(), throwsA(isA<_Crash>()));
      await b.restart();
      await b.sync();
      expect(b.engine.conflictCopies(), hasLength(1));
      expect(b.day('d1')!.syncMeta.hasConflict, isTrue);
    });

    test('B2 a torn write at the end of the box file: the previous record survives whole', () async {
      final box = await Hive.openBox<WorkoutTemplate>('torn');
      await box.put('d1', newDay('d1', ['bench'], name: 'first'));
      await box.flush();
      final file = File('${dir.path}/torn.hive');
      final intact = await file.length();
      await box.put('d1', newDay('d1', ['bench', 'fly'], name: 'second'));
      await box.flush();
      await box.close();
      // The process died while the second frame was being written.
      final bytes = await file.readAsBytes();
      await file.writeAsBytes(bytes.sublist(0, intact + (bytes.length - intact) ~/ 2));
      final reopened = await Hive.openBox<WorkoutTemplate>('torn');
      expect(reopened.get('d1')!.name, 'first');
      expect(names(reopened.get('d1')), ['bench']);
    });

    test('deleted here while a write was in flight: the deletion follows it', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync(); // rev 1
      await a.edit('d1', (d) => d.copyWith(name: 'x'));
      cloud.beforeWrite = (id) async {
        cloud.beforeWrite = null;
        await a.engine.markDeleted('d1');
      };
      await a.sync(); // content write lands as rev 2, then the tombstone
      await a.sync();
      expect(cloud.docs['d1']!['deleted'], isTrue);
      expect(a.engine.conflictCopies(), isEmpty);
    });
  });

  group('C · old-format documents (legacy restoration matrix)', () {
    test('local list non-empty: migrated; the old cloud list is kept, never changed', () async {
      cloud.docs['d1'] = legacyDoc('d1', staleList: ['old-a', 'old-b']);
      await a.records.put('d1', legacyDay('d1', ['bench']));
      await a.sync();
      expect(cloud.docs['d1']!['schemaVersion'], 2);
      expect(cloud.docs['d1']!['revision'], 1);
      expect([for (final x in cloud.docs['d1']!['activities'] as List) x['id']], ['bench']);
      expect(
        [for (final x in cloud.docs['d1']!['exerciseAssignments'] as List) x['assignmentId']],
        ['old-a', 'old-b'],
      );
      final candidate = a.day('d1')!.syncMeta.legacyCandidate!;
      expect(candidate['prompt'], isFalse); // only a manual restore
    });

    test('nothing old to restore: migrated as is', () async {
      cloud.docs['d1'] = legacyDoc('d1');
      await a.records.put('d1', legacyDay('d1', []));
      await a.sync();
      expect(cloud.docs['d1']!['revision'], 1);
      expect(a.day('d1')!.syncMeta.legacyCandidate, isNull);
    });

    test('local empty and edited after the cloud copy: treated as intentional', () async {
      cloud.docs['d1'] = legacyDoc('d1', staleList: ['old-a'], updatedAt: '2026-10-10T00:00:00.000Z');
      await a.records.put(
        'd1',
        legacyDay('d1', [], updatedAt: DateTime.utc(2026, 10, 20)),
      );
      final report = await a.sync();
      expect(report.awaitingUser, 0);
      expect(cloud.docs['d1']!['activities'], isEmpty);
      expect(a.day('d1')!.syncMeta.legacyCandidate!['prompt'], isFalse);
    });

    test('local empty, not newer: waits for the user, writes NOTHING', () async {
      cloud.docs['d1'] = legacyDoc('d1', staleList: ['old-a'], updatedAt: '2026-10-10T00:00:00.000Z');
      await a.records.put('d1', legacyDay('d1', [], updatedAt: DateTime.utc(2026, 10, 1)));
      final report = await a.sync();
      expect(report.awaitingUser, 1);
      expect(cloud.docs['d1']!['schemaVersion'], isNull); // untouched
      expect(a.day('d1')!.syncMeta.isMigrated, isFalse);
      expect(a.day('d1')!.syncMeta.legacyCandidate!['prompt'], isTrue);
      await a.sync(); // asked again only by the UI, nothing written meanwhile
      expect(cloud.docs['d1']!['schemaVersion'], isNull);
    });

    test('new device: only the header arrives; old exercises wait for the user', () async {
      cloud.docs['d1'] = legacyDoc('d1', staleList: ['old-a', 'old-b']);
      final report = await b.sync();
      expect(report.awaitingUser, 1);
      expect(names(b.day('d1')), isEmpty); // nothing imported silently
      expect(b.day('d1')!.syncMeta.origin, 'serverLegacy');
      expect(b.day('d1')!.syncMeta.legacyCandidate!['items'], hasLength(2));
    });

    test('a decision made on one device is not asked again on another', () async {
      cloud.docs['d1'] = legacyDoc('d1', staleList: ['old-a']);
      await a.sync();
      await b.sync();
      // A restores (what the repository does on confirmation).
      final day = a.day('d1')!;
      final candidate = day.syncMeta.legacyCandidate!;
      await a.records.put(
        'd1',
        day
            .copyWith(
              exerciseAssignments: [
                for (final item in candidate['items'] as List)
                  WorkoutTemplateExerciseAssignment.fromActivityMap(item as Map),
              ],
            )
            .withSyncMeta(day.syncMeta.withLegacyDecision('restored').migratedAsNew()),
      );
      await a.sync();
      expect(cloud.docs['d1']!['legacyDecision'], 'restored');
      await b.sync(); // B's shell adopts A's migrated day
      expect(names(b.day('d1')), ['old-a']);
      expect(b.day('d1')!.syncMeta.legacyDecision, 'restored');
      expect(b.day('d1')!.syncMeta.legacyCandidate, isNull);
    });

    test('never-migrated local day that differs from an already-migrated cloud day: conflict', () async {
      await b.records.put('d1', newDay('d1', ['cloud-only']));
      await b.sync();
      await a.records.put('d1', legacyDay('d1', ['local-only']));
      final report = await a.sync();
      expect(report.conflicts, 1);
      expect(a.day('d1')!.syncMeta.conflictReason, SyncConflictReason.differsFromCloud);
      expect(names(a.day('d1')), ['cloud-only']);
      expect(a.engine.conflictCopies(), hasLength(1));
    });
  });

  group('F · failures', () {
    test('rules not deployed yet: nothing is lost, it waits and retries next session', () async {
      cloud.docs['d1'] = legacyDoc('d1');
      cloud.newRulesDeployed = false;
      await a.records.put('d1', legacyDay('d1', ['bench']));
      final report = await a.sync();
      expect(report.blocked, 1);
      expect(cloud.docs['d1']!['schemaVersion'], isNull);
      expect(names(a.day('d1')), ['bench']);
      expect(a.day('d1')!.syncMeta.blockedReason, 'rulesNotDeployed');
      cloud.newRulesDeployed = true;
      await a.restart(); // next app session
      await a.sync();
      expect(cloud.docs['d1']!['revision'], 1);
      expect(a.day('d1')!.syncMeta.isBlocked, isFalse);
    });

    test('offline: nothing changes, nothing is lost', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      cloud.offline = true;
      final report = await a.sync();
      expect(report.offline, isTrue);
      expect(names(a.day('d1')), ['bench']);
      cloud.offline = false;
      await a.sync();
      expect(cloud.docs['d1']!['revision'], 1);
    });

    test('an older build replaced a migrated day (old rules): conflict, both versions kept', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.sync();
      cloud.newRulesDeployed = false; // rules rolled back
      expect(cloud.legacyWrite('d1', legacyDoc('d1')), isTrue);
      cloud.newRulesDeployed = true;
      await a.edit('d1', (d) => d.copyWith(name: 'local'));
      await a.sync();
      expect(a.day('d1')!.syncMeta.conflictReason, SyncConflictReason.overwrittenByOlderBuild);
      await a.engine.keepMine('d1');
      await a.sync();
      expect(cloud.docs['d1']!['schemaVersion'], 2);
      expect([for (final x in cloud.docs['d1']!['activities'] as List) x['id']], ['bench']);
    });

    test('a malformed cloud document is skipped; the rest still syncs', () async {
      cloud.docs['bad'] = {'schemaVersion': 2, 'revision': 1, 'writeId': 'x'};
      cloud.docs['good'] = {
        ...newDay('good', ['bench']).toCloudContent(),
        'schemaVersion': 2,
        'revision': 1,
        'baseRevision': 0,
        'writeId': 'w',
        'contentHash': newDay('good', ['bench']).contentFingerprint,
      };
      final report = await b.sync();
      expect(report.skipped, 1);
      expect(names(b.day('good')), ['bench']);
      expect(b.day('bad'), isNull);
    });

    test('verification against the server: complete only when everything is confirmed', () async {
      await a.records.put('d1', newDay('d1', ['bench']));
      await a.records.put('d2', newDay('d2', ['row']));
      expect((await a.engine.verifyAgainstServer()).complete, isFalse);
      await a.sync();
      final verified = await a.engine.verifyAgainstServer();
      expect(verified.complete, isTrue);
      expect(verified.checked, 2);
      await a.edit('d1', (d) => d.copyWith(name: 'changed'));
      expect((await a.engine.verifyAgainstServer()).mismatches.single, startsWith('d1'));
      await a.engine.markDeleted('d2');
      expect((await a.engine.verifyAgainstServer()).mismatches, hasLength(2));
    });
  });
}
