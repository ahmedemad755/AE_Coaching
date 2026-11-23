import 'dart:io';

import 'package:ae_coaching/core/sync/revision_sync_engine.dart';
import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/sync/workout_sync_adapters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../support/fake_revision_cloud.dart';

/// Firebase Spark bills every document read. These tests pin down how many
/// reads each kind of sync costs, with the production defaults (a 2-minute
/// overlap, a full pull at most once a day), and that reading less never
/// misses a change from another device or weakens the conflict protection.

/// One phone with a pull position ([state]) and its own clock.
class Phone {
  Phone(this.name, this.cloud);

  final String name;
  final FakeRevisionCloud cloud;
  late Box<WorkoutTemplate> records;
  late RevisionSyncEngine<WorkoutTemplate> engine;
  DateTime now = DateTime.utc(2026, 11, 17, 8);
  var _writes = 0;

  Future<Phone> open() async {
    records = await Hive.openBox<WorkoutTemplate>('templates_$name');
    engine = RevisionSyncEngine<WorkoutTemplate>(
      records: records,
      conflicts: await Hive.openBox<Map>('conflicts_$name'),
      tombstones: await Hive.openBox<Map>('tombstones_$name'),
      state: await Hive.openBox<Map>('state_$name'),
      cloud: cloud,
      adapter: WorkoutTemplateSyncAdapter(),
      newWriteId: () => '$name-${++_writes}',
      clock: () => now,
    );
    return this;
  }

  Future<void> add(String id, {String name = 'Day'}) => records.put(
    id,
    WorkoutTemplate(
      id: id,
      programId: 'p1',
      name: name,
      createdAt: DateTime.utc(2026, 11, 1),
      exerciseAssignments: [
        WorkoutTemplateExerciseAssignment(
          assignmentId: '$id-bench',
          exerciseId: 'repdb:bench',
          exerciseNameSnapshot: 'Bench press',
          referenceType: 'builtIn',
          workingSets: 3,
          targetRepsMin: 8,
          targetRepsMax: 12,
        ),
      ],
      syncData: SyncMeta.empty.migratedAsNew().toMap(),
    ),
  );

  Future<void> rename(String id, String name) =>
      records.put(id, records.get(id)!.copyWith(name: name));

  /// Reads billed for [action].
  Future<int> readsOf(Future<void> Function() action) async {
    final before = cloud.reads;
    await action();
    return cloud.reads - before;
  }
}

void main() {
  late Directory dir;
  late FakeRevisionCloud cloud;
  late Phone a;
  late Phone b;

  setUpAll(() {
    Hive.registerAdapter(WorkoutTemplateAdapter());
    Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sync_reads_');
    Hive.init(dir.path);
    cloud = FakeRevisionCloud()
      // Days are built over time, not all within the overlap window.
      ..writeSpacing = const Duration(minutes: 10);
    a = await Phone('a', cloud).open();
    b = await Phone('b', cloud).open();
    for (var i = 0; i < 30; i++) {
      await a.add('day$i');
    }
    await a.engine.pushChanges();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('the first sync on a device reads everything once; the next one '
      'reads only what changed', () async {
    late SyncReport first;
    expect(await b.readsOf(() async => first = await b.engine.syncAll()), 30);
    expect(first.pull, PullKind.full);
    expect(b.records.length, 30);

    late SyncReport second;
    final reads = await b.readsOf(
      () async => second = await b.engine.syncAll(),
    );
    expect(second.pull, PullKind.changes);
    // Only the documents inside the 2-minute overlap (the newest one).
    expect(reads, lessThanOrEqualTo(1));
  });

  test(
    'an edit on another device is found by reading the changes only',
    () async {
      await b.engine.syncAll();
      await a.rename('day7', 'Legs (heavy)');
      await a.engine.pushChanges();

      late SyncReport report;
      final reads = await b.readsOf(
        () async => report = await b.engine.syncAll(),
      );
      expect(report.pull, PullKind.changes);
      expect(reads, lessThanOrEqualTo(2)); // the edit + the overlap
      expect(b.records.get('day7')!.name, 'Legs (heavy)');
    },
  );

  test('a local edit is pushed without reading anything', () async {
    await b.engine.syncAll();
    await b.rename('day3', 'Pull');
    final accepted = cloud.accepted;
    final reads = await b.readsOf(() async => b.engine.pushChanges());
    expect(reads, 0);
    expect(cloud.accepted, accepted + 1);
    expect(cloud.docs['day3']!['name'], 'Pull');
  });

  test('push only, yet still protected: a stale write is refused and '
      'only that day is read to show the conflict', () async {
    await b.engine.syncAll();
    await a.rename('day3', 'From A');
    await a.engine.pushChanges();
    await b.rename('day3', 'From B'); // B has not seen A's edit

    late SyncReport report;
    final reads = await b.readsOf(
      () async => report = await b.engine.pushChanges(),
    );
    expect(reads, 1);
    expect(report.conflicts, 1);
    expect(cloud.docs['day3']!['name'], 'From A'); // never overwritten
    expect(b.records.get('day3')!.syncMeta.hasConflict, isTrue);
    final copy = b.engine.conflictCopies().single;
    expect((copy['content'] as Map)['name'], 'From B'); // nothing lost
  });

  test('a deletion on another device arrives with the changes', () async {
    await b.engine.syncAll();
    await a.engine.markDeleted('day5');
    await a.engine.pushChanges();

    final reads = await b.readsOf(() async => b.engine.syncAll());
    expect(reads, lessThanOrEqualTo(2));
    expect(b.records.get('day5'), isNull);
  });

  test('a write that may not have landed is checked by reading only that '
      'day', () async {
    await b.engine.syncAll();
    await b.rename('day2', 'Offline edit');
    cloud.offline = true;
    await b.engine.pushChanges(); // never reached the server
    cloud.offline = false;
    cloud.serverTime = cloud.serverTime.add(const Duration(hours: 1));

    final reads = await b.readsOf(() async => b.engine.syncAll());
    // The (empty) change query + that one day.
    expect(reads, 2);
    expect(cloud.docs['day2']!['name'], 'Offline edit');
  });

  test('once a day the whole collection is read again: old-format days '
      'from older builds and outright deletions are found', () async {
    await b.engine.syncAll();
    // An older build creates a day (old format: no serverUpdatedAt).
    cloud.legacyWrite('old-build-day', {
      'id': 'old-build-day',
      'programId': 'p1',
      'name': 'From the old app',
      'createdAt': '2026-11-17T09:00:00.000Z',
      'isArchived': false,
    });
    await b.engine.syncAll();
    expect(b.records.get('old-build-day'), isNull); // not in the changes

    b.now = b.now.add(const Duration(hours: 25));
    final report = await b.engine.syncAll();
    expect(report.pull, PullKind.full);
    expect(b.records.get('old-build-day')!.name, 'From the old app');
  });

  test('a full pull can be forced, and a clock moved back means a full '
      'pull', () async {
    await b.engine.syncAll();
    expect((await b.engine.syncAll(fullPull: true)).pull, PullKind.full);
    b.now = b.now.subtract(const Duration(days: 2));
    expect((await b.engine.syncAll()).pull, PullKind.full);
  });

  test('an interrupted pull is read again (the position is saved only '
      'after it was applied)', () async {
    await b.engine.syncAll();
    await a.rename('day9', 'Changed');
    await a.engine.pushChanges();
    // Offline in the middle of the next sync: the change query fails.
    cloud.offline = true;
    expect((await b.engine.syncAll()).offline, isTrue);
    cloud.offline = false;
    await b.engine.syncAll();
    expect(b.records.get('day9')!.name, 'Changed');
  });

  test('a quiet collection costs one read per sync', () async {
    await b.engine.syncAll();
    cloud.serverTime = cloud.serverTime.add(const Duration(hours: 3));
    await b.engine.syncAll(); // past the overlap of the last change
    expect(await b.readsOf(() async => b.engine.syncAll()), 1);
  });
}
