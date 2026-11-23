// End-to-end checks against the LOCAL Firebase Emulators (Firestore + Auth)
// with the real Firebase SDKs, the real firestore.rules, the sync engine and
// the account deletion code, on an Android device/emulator.
//
// It is a small app (no extra test dependency): it runs every scenario,
// prints `PASS`/`FAIL` lines and a summary, then exits.
//
// Never touches a real project: every Firebase call goes through a separate
// `demo-` app pointed at the emulators (a `demo-` project only exists inside
// the emulators); the app refuses to run otherwise.
//
// Run (Android emulator running), from the repository root:
//   firebase emulators:exec --only firestore,auth --project demo-ae-coaching \
//     "flutter run -t integration_test/emulator_suite.dart -d emulator-5554"
import 'dart:convert';
import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/sync/revision_cloud.dart';
import 'package:ae_coaching/core/sync/revision_sync_engine.dart';
import 'package:ae_coaching/features/account_deletion/data/firebase_account_deletion_repository.dart';
import 'package:ae_coaching/features/account_deletion/domain/account_deletion.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

const _host = '10.0.2.2'; // the development machine, seen from the emulator
const _projectId = 'demo-ae-coaching';
const _password = 'Emulator-only-1';

// ── Checks ────────────────────────────────────────────────────────────────

class CheckFailed implements Exception {
  CheckFailed(this.message);
  final String message;
  @override
  String toString() => 'CheckFailed: $message';
}

bool _deepEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}

void expectEq(Object? actual, Object? expected, String what) {
  if (!_deepEquals(actual, expected)) {
    throw CheckFailed('$what: expected <$expected>, got <$actual>');
  }
}

void expectTrue(bool value, String what) {
  if (!value) throw CheckFailed(what);
}

Future<T> expectThrows<T extends Object>(
  Future<Object?> future,
  String what,
) async {
  try {
    await future;
  } on T catch (error) {
    return error;
  } catch (error) {
    throw CheckFailed('$what: expected $T, got $error');
  }
  throw CheckFailed('$what: expected $T, nothing was thrown');
}

// ── The emulators' own REST endpoints (admin: bypass the rules) ───────────

final _http = HttpClient();

Future<Map<String, dynamic>?> _admin(
  String method,
  int port,
  String path, [
  Map<String, Object?>? body,
]) async {
  final request = await _http.openUrl(
    method,
    Uri.parse('http://$_host:$port$path'),
  );
  request.headers
    ..set('Authorization', 'Bearer owner')
    ..contentType = ContentType.json;
  if (body != null) request.write(jsonEncode(body));
  final response = await request.close();
  final text = await response.transform(utf8.decoder).join();
  if (response.statusCode == 404) return null;
  if (response.statusCode >= 400) {
    throw StateError('$method $path: ${response.statusCode} $text');
  }
  return text.isEmpty ? {} : jsonDecode(text) as Map<String, dynamic>;
}

const _docs = '/v1/projects/$_projectId/databases/(default)/documents';

Future<void> _clearEmulators() async {
  await _admin(
    'DELETE',
    8080,
    '/emulator/v1/projects/$_projectId/databases/(default)/documents',
  );
  await _admin('DELETE', 9099, '/emulator/v1/projects/$_projectId/accounts');
}

Map<String, Object?> _value(Object? v) => switch (v) {
  null => {'nullValue': null},
  bool b => {'booleanValue': b},
  int i => {'integerValue': '$i'},
  double d => {'doubleValue': d},
  String s => {'stringValue': s},
  DateTime t => {'timestampValue': t.toUtc().toIso8601String()},
  List l => {
    'arrayValue': {
      'values': [for (final e in l) _value(e)],
    },
  },
  Map m => {
    'mapValue': {
      'fields': {for (final e in m.entries) '${e.key}': _value(e.value)},
    },
  },
  _ => throw ArgumentError(v),
};

/// Writes a document as an older build or the server would (no rules).
Future<void> _seed(String path, Map<String, Object?> data) =>
    _admin('PATCH', 8080, '$_docs/$path', {
      'fields': {for (final e in data.entries) e.key: _value(e.value)},
    });

Future<bool> _exists(String path) async =>
    await _admin('GET', 8080, '$_docs/$path') != null;

/// Subcollections that still hold documents under [path].
Future<List<String>> _collectionsUnder(String path) async {
  final result = await _admin(
    'POST',
    8080,
    '$_docs/$path:listCollectionIds',
    {},
  );
  return [...?(result?['collectionIds'] as List?)?.cast<String>()];
}

Future<bool> _authAccountExists(String uid) async {
  final result = await _admin(
    'POST',
    9099,
    '/identitytoolkit.googleapis.com/v1/projects/$_projectId/accounts:lookup',
    {
      'localId': [uid],
    },
  );
  return (result?['users'] as List?)?.isNotEmpty ?? false;
}

// ── Two "phones" of the same account: two Firebase apps ─────────────────────

class Device {
  Device(this.name);
  final String name;
  late FirebaseFirestore firestore;
  late FirebaseAuth auth;

  Future<void> init() async {
    final app = await Firebase.initializeApp(
      name: 'emulator-$name',
      options: const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:1234567890:android:0000000000000000',
        messagingSenderId: '1234567890',
        projectId: _projectId,
      ),
    );
    // Hard stop if this could ever reach a real project.
    if (!app.options.projectId.startsWith('demo-')) {
      throw StateError('Refusing to run against a non-demo project.');
    }
    firestore = FirebaseFirestore.instanceFor(app: app)
      ..useFirestoreEmulator(_host, 8080);
    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(_host, 9099);
  }

  Future<void> signIn(String email) async {
    await auth.signInWithEmailAndPassword(email: email, password: _password);
    await auth.currentUser!.getIdToken(true);
  }
}

/// A new account with a verified email (the rules require it).
Future<String> _verifiedAccount(Device device, String email) async {
  final credential = await device.auth.createUserWithEmailAndPassword(
    email: email,
    password: _password,
  );
  final uid = credential.user!.uid;
  await _admin(
    'POST',
    9099,
    '/identitytoolkit.googleapis.com/v1/projects/$_projectId/accounts:update',
    {'localId': uid, 'emailVerified': true},
  );
  await credential.user!.reload();
  await credential.user!.getIdToken(true);
  return uid;
}

/// The profile the app confirms (or recovers) at each sign-in.
Future<void> _seedProfile() => _seed('users/$uid', {
  'uid': uid,
  'name': 'Emulator user',
  'email': email,
  'createdAt': DateTime.utc(2026, 11),
  'updatedAt': DateTime.utc(2026, 11),
});

String _hash(String seed) => sha256.convert(utf8.encode(seed)).toString();

Map<String, dynamic> _v2(
  String id,
  int base,
  String writeId, {
  String name = 'Push',
}) => {
  'id': id,
  'programId': 'p1',
  'name': name,
  'createdAt': '2026-11-17T08:00:00.000Z',
  'updatedAt': null,
  'isArchived': false,
  'orderIndex': 0,
  'activities': [
    {
      'id': 'a1',
      'type': 'strength',
      'exerciseId': 'repdb:bench',
      'referenceType': 'builtIn',
      'name': 'Bench press',
      'strength': {'sets': 3, 'repsMin': 8, 'repsMax': 12},
    },
  ],
  'schemaVersion': 2,
  'baseRevision': base,
  'revision': base + 1,
  'writeId': writeId,
  'contentHash': _hash('$id-$base-$writeId'),
  'deleted': false,
};

// ── The suite ─────────────────────────────────────────────────────────────

final a = Device('a');
final b = Device('b');
late UserStorageManager storage;
var run = 0;
late String email;
late String uid;
final results = <String, String?>{};
final status = ValueNotifier<String>('Starting…');

void log(String line) {
  final time = DateTime.now().toIso8601String().substring(11, 19);
  // ignore: avoid_print
  print('EMULATOR-SUITE [$time] $line');
  status.value = line;
}

/// Known gaps (awaiting a decision): run and reported, never counted as a
/// regression. Reported as closed as soon as the check passes.
final knownGaps = <String, String?>{};

Future<void> knownGap(String name, Future<void> Function() body) async {
  await scenario(name, body);
  final failure = results.remove(name);
  knownGaps[name] = failure;
  log(
    failure == null
        ? 'GAP CLOSED  $name'
        : 'KNOWN GAP  $name (expected until the proposed fix is approved)',
  );
}

/// `--dart-define=SUITE_FILTER=<text>` runs only the scenarios whose name
/// contains it (re-running just what a change affects).
const _filter = String.fromEnvironment('SUITE_FILTER');

Future<void> scenario(String name, Future<void> Function() body) async {
  if (_filter.isNotEmpty && !name.contains(_filter)) return;
  run++;
  try {
    for (final device in [a, b]) {
      await device.firestore.enableNetwork();
      await device.auth.signOut();
    }
    await _clearEmulators();
    email = 'user$run@example.com';
    uid = await _verifiedAccount(a, email);
    await _seedProfile();
    await b.signIn(email);
    await body();
    results[name] = null;
    log('PASS  $name');
  } catch (error, stack) {
    results[name] = '$error';
    log('FAIL  $name\n    $error\n$stack');
  } finally {
    for (final device in [a, b]) {
      try {
        await device.firestore.enableNetwork();
        await device.firestore.waitForPendingWrites().timeout(
          const Duration(seconds: 20),
        );
      } catch (_) {}
    }
  }
}

WorkoutTemplateRemoteDataSourceImpl daysCloud(Device device) =>
    WorkoutTemplateRemoteDataSourceImpl(
      firestore: device.firestore,
      auth: device.auth,
      timeout: const Duration(seconds: 5),
    );

/// The app's repository on [device] (its own local boxes).
WorkoutTemplateRepository days(Device device) => WorkoutTemplateRepository(
  remoteDataSource: daysCloud(device),
  storageManager: storage,
  uidOverride: () => '${device.name}-$run',
);

CustomExerciseRepository customs(Device device) => CustomExerciseRepository(
  storageManager: storage,
  remoteDataSource: CustomExerciseRemoteDataSourceImpl(
    firestore: device.firestore,
    auth: device.auth,
    timeout: const Duration(seconds: 5),
  ),
  uidOverride: () => '${device.name}-$run',
);

Future<void> pull(WorkoutTemplateRepository repository) async =>
    repository.fetchAndSyncFromRemote(await repository.getUserBox());

Future<Map<String, dynamic>> cloudDay(String dayId) async =>
    (await a.firestore
            .doc('users/$uid/workout_templates/$dayId')
            .get(const GetOptions(source: Source.server)))
        .data()!;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (_, value, _) =>
                Padding(padding: const EdgeInsets.all(24), child: Text(value)),
          ),
        ),
      ),
    ),
  );
  await a.init();
  await b.init();
  final dir = await getTemporaryDirectory();
  Hive.init(
    '${dir.path}/emulator_suite_${DateTime.now().microsecondsSinceEpoch}',
  );
  Hive.registerAdapter(WorkoutTemplateAdapter());
  Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
  Hive.registerAdapter(CustomExerciseAdapter());
  storage = UserStorageManager();

  await cloudScenarios();
  await engineScenarios();
  await deletionScenarios();

  final failed = results.values.whereType<String>().length;
  final open = knownGaps.values.whereType<String>().length;
  log(
    'SUMMARY ${results.length - failed} passed, $failed failed; '
    'known gaps: $open open, ${knownGaps.length - open} closed',
  );
  log('END');
  await Future<void>.delayed(const Duration(seconds: 2));
  exit(failed == 0 ? 0 : 1);
}

// ───────────────────────────────────────────────────────────────────────────
Future<void> cloudScenarios() async {
  await scenario('cloud: merge writes keep the old exercise list; server time '
      'is separate; reads come from the server', () async {
    final legacyList = [
      {
        'assignmentId': 'sq',
        'exerciseId': 'repdb:squat',
        'exerciseNameSnapshot': 'Squat',
        'referenceType': 'builtIn',
      },
    ];
    await _seed('users/$uid/workout_templates/day1', {
      'id': 'day1',
      'programId': 'p1',
      'name': 'Legs',
      'createdAt': '2026-09-01T00:00:00.000Z',
      'isArchived': false,
      'exerciseAssignments': legacyList,
    });
    final cloud = daysCloud(a);
    final old = (await cloud.fetch('day1'))!;
    expectEq(old.isV2, false, 'old document is schema 1');
    expectEq(old.revision, 0, 'old document revision');
    expectEq(old.serverUpdatedAt, null, 'old document has no server time');

    final before = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
    await cloud.write('day1', _v2('day1', 0, 'w1'));
    final doc = (await cloud.fetch('day1'))!;
    expectEq(doc.isV2, true, 'migrated to schema 2');
    expectEq(doc.revision, 1, 'revision after migration');
    expectEq(doc.writeId, 'w1', 'write id');
    expectEq(doc.data['exerciseAssignments'], legacyList, 'old list kept');
    expectEq(doc.data.containsKey('serverUpdatedAt'), false, 'no raw stamp');
    expectTrue(doc.serverUpdatedAt!.isAfter(before), 'server time is set');
  });

  await scenario('cloud: an outdated revision or a reused write id is refused '
      '(CloudWriteRejected) and changes nothing', () async {
    final cloud = daysCloud(a);
    await cloud.write('day1', _v2('day1', 0, 'w1'));
    await expectThrows<CloudWriteRejected>(
      cloud.write('day1', _v2('day1', 0, 'w2', name: 'Stale')),
      'outdated base',
    );
    await expectThrows<CloudWriteRejected>(
      cloud.write('day1', _v2('day1', 1, 'w1', name: 'Reused id')),
      'reused write id',
    );
    final doc = (await cloud.fetch('day1'))!;
    expectEq(doc.revision, 1, 'revision unchanged');
    expectEq(doc.data['name'], 'Push', 'name unchanged');
  });

  await scenario('cloud: offline reads fail at once (never the cache); a '
      'queued write lands later and is recognised by its write id', () async {
    final cloud = daysCloud(a);
    await cloud.write('day1', _v2('day1', 0, 'w1'));
    await a.firestore.disableNetwork();
    await expectThrows<CloudUnavailable>(cloud.fetch('day1'), 'offline read');
    await expectThrows<CloudUnavailable>(
      cloud.write('day1', _v2('day1', 1, 'w-offline', name: 'Offline')),
      'offline write (unconfirmed)',
    );
    await a.firestore.enableNetwork();
    await a.firestore.waitForPendingWrites();
    final doc = (await cloud.fetch('day1'))!;
    expectEq(doc.writeId, 'w-offline', 'queued write landed');
    expectEq(doc.revision, 2, 'revision');
  });

  await scenario('cloud: a write queued offline that became outdated is '
      'refused on arrival; the newer version stays', () async {
    await daysCloud(a).write('day1', _v2('day1', 0, 'w1'));
    await a.firestore.disableNetwork();
    await expectThrows<CloudUnavailable>(
      daysCloud(a).write('day1', _v2('day1', 1, 'a-offline', name: 'A')),
      'queued on A',
    );
    await daysCloud(b).write('day1', _v2('day1', 1, 'b-online', name: 'B'));
    await a.firestore.enableNetwork();
    await a.firestore.waitForPendingWrites();
    final doc = (await daysCloud(b).fetch('day1'))!;
    expectEq(doc.writeId, 'b-online', 'B kept');
    expectEq(doc.data['name'], 'B', 'name');
    expectEq(doc.revision, 2, 'revision');
  });

  await scenario(
    'cloud: only what changed since a server time is read',
    () async {
      final cloud = daysCloud(a);
      await cloud.write('d1', _v2('d1', 0, 'w1'));
      await cloud.write('d2', _v2('d2', 0, 'w2'));
      final since = (await cloud.fetch(
        'd2',
      ))!.serverUpdatedAt!.add(const Duration(milliseconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await cloud.write('d3', _v2('d3', 0, 'w3'));
      final changed = await cloud.fetchChangedSince(since);
      expectEq([for (final d in changed) d.id], ['d3'], 'changed documents');
      final all = {for (final d in await cloud.fetchAll()) d.id};
      expectEq(all.length, 3, 'full read');
    },
  );

  await scenario('cloud: a refused read is CloudReadDenied; signed out is '
      'CloudUnavailable', () async {
    await b.auth.signOut();
    await b.auth.createUserWithEmailAndPassword(
      email: 'unverified$run@example.com',
      password: _password,
    ); // NOT verified: the rules refuse workout data
    await expectThrows<CloudReadDenied>(
      daysCloud(b).fetchAll(),
      'unverified full read',
    );
    await expectThrows<CloudReadDenied>(
      daysCloud(b).fetchChangedSince(DateTime.utc(2026)),
      'unverified changes read',
    );
    await b.auth.signOut();
    await expectThrows<CloudUnavailable>(
      daysCloud(b).fetch('day1'),
      'signed out',
    );
  });
}

// ───────────────────────────────────────────────────────────────────────────
Future<void> engineScenarios() async {
  await scenario('engine: strength + cardio day reaches the other phone; '
      'simultaneous edits become one conflict, nothing lost; a deletion '
      'arrives', () async {
    final onA = days(a);
    final onB = days(b);
    final day = await onA.createTemplate(programId: 'p1', name: 'Push');
    await onA.addExerciseAssignment(
      templateId: day.id,
      exerciseId: 'repdb:bench',
      exerciseNameSnapshot: 'Bench press',
      referenceType: WorkoutExerciseReferenceType.builtIn,
    );
    await onA.addExerciseAssignment(
      templateId: day.id,
      exerciseId: 'cardio:treadmill',
      exerciseNameSnapshot: 'Treadmill',
      referenceType: WorkoutExerciseReferenceType.builtIn,
    );
    final boxA = await onA.getUserBox();
    final current = boxA.get(day.id)!;
    await boxA.put(
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
    await pull(onA);
    await pull(onB);
    final received = (await onB.getUserBox()).get(day.id)!;
    expectEq(
      [for (final x in received.exerciseAssignments) x.exerciseNameSnapshot],
      ['Bench press', 'Treadmill'],
      'activities on B',
    );
    expectEq(
      received.exerciseAssignments[1].cardio!.durationSeconds,
      1200,
      'cardio plan on B',
    );

    await onA.updateTemplate(templateId: day.id, name: 'From A');
    await pull(onA);
    await onB.updateTemplate(templateId: day.id, name: 'From B');
    await pull(onB);
    expectEq((await cloudDay(day.id))['name'], 'From A', 'never overwritten');
    final issues = await onB.syncIssues();
    expectEq(issues.length, 1, 'one issue on B');
    expectTrue(issues.single.isConflict, 'it is a conflict');
    expectEq(issues.single.myVersion!.name, 'From B', "B's version kept");

    await onB.keepMyVersion(day.id);
    await onB.syncWithCloud();
    expectEq((await cloudDay(day.id))['name'], 'From B', 'kept mine');
    await pull(onA);
    expectEq((await onA.getUserBox()).get(day.id)!.name, 'From B', 'A follows');

    await onA.deleteTemplate(day.id);
    await onA.syncWithCloud();
    expectEq((await cloudDay(day.id))['deleted'], true, 'tombstone');
    await pull(onB);
    expectEq((await onB.getUserBox()).get(day.id), null, 'removed on B');
  });

  await scenario('engine: an edit queued offline that became outdated is '
      'refused on arrival, then shown as a conflict; nothing lost', () async {
    final onA = days(a);
    final onB = days(b);
    final day = await onA.createTemplate(programId: 'p1', name: 'Legs');
    await pull(onA);
    await pull(onB);

    await b.firestore.disableNetwork();
    await onB.updateTemplate(templateId: day.id, name: 'Offline on B');
    // The edit already started a background push; this one waits for it.
    // Offline, the write is queued by Firestore and stays unconfirmed.
    await (await onB.syncEngine()).pushChanges();
    expectTrue(
      (await onB.getUserBox()).get(day.id)!.syncMeta.hasFlight,
      'write recorded as in flight (unconfirmed)',
    );

    await onA.updateTemplate(templateId: day.id, name: 'Online on A');
    await pull(onA);
    await b.firestore.enableNetwork();
    await b.firestore.waitForPendingWrites();

    await pull(onB);
    expectEq((await cloudDay(day.id))['name'], 'Online on A', 'A kept');
    final issues = await onB.syncIssues();
    expectEq(issues.length, 1, 'one issue on B');
    expectTrue(issues.single.isConflict, 'conflict');
    expectEq(issues.single.myVersion!.name, 'Offline on B', "B's edit kept");
  });

  await scenario("engine: an offline edit that lands later is this phone's "
      'own: no false conflict', () async {
    final onB = days(b);
    final day = await onB.createTemplate(programId: 'p1', name: 'Pull');
    await pull(onB);
    await b.firestore.disableNetwork();
    await onB.updateTemplate(templateId: day.id, name: 'Pull (offline)');
    await (await onB.syncEngine()).pushChanges();
    await b.firestore.enableNetwork();
    await b.firestore.waitForPendingWrites();
    await pull(onB);
    expectEq((await onB.syncIssues()).length, 0, 'no conflict');
    expectEq((await cloudDay(day.id))['name'], 'Pull (offline)', 'landed');
    expectTrue(await onB.isConfirmedInCloud([day.id]), 'confirmed');
  });

  await scenario('engine: after the first full pull, a pull reads only the '
      'changes (real index and rules)', () async {
    final onA = days(a);
    final onB = days(b);
    final day = await onA.createTemplate(programId: 'p1', name: 'Arms');
    await pull(onA);
    final first = await onB.syncWithCloud();
    expectEq(first.pull, PullKind.full, 'first pull');
    await onA.updateTemplate(templateId: day.id, name: 'Arms (new)');
    await pull(onA);
    final next = await onB.syncWithCloud();
    expectEq(next.pull, PullKind.changes, 'next pull');
    expectEq(
      (await onB.getUserBox()).get(day.id)!.name,
      'Arms (new)',
      'got it',
    );
  });

  await scenario('engine: custom exercises are created once, never '
      'duplicated', () async {
    final onA = customs(a);
    final onB = customs(b);
    final made = await onA.createExercise(name: 'Sled push');
    await onA.syncWithCloud();
    await onB.syncWithCloud();
    await onB.syncWithCloud();
    final list = await onB.getAllExercises();
    expectEq([for (final e in list) e.id], [made.id], 'one exercise on B');
    final docs = await a.firestore
        .collection('users/$uid/custom_exercises')
        .get(const GetOptions(source: Source.server));
    expectEq(docs.docs.length, 1, 'one document');
  });
}

// ───────────────────────────────────────────────────────────────────────────
/// A full account: old-format and synced days, a tombstone, a custom
/// exercise, every other collection, the profile and settings. Returns a
/// synced day's id.
Future<String> seedAccount() async {
  final onA = days(a);
  final live = await onA.createTemplate(programId: 'p1', name: 'Live');
  final gone = await onA.createTemplate(programId: 'p1', name: 'Gone');
  await pull(onA);
  await onA.deleteTemplate(gone.id);
  await onA.syncWithCloud(); // a tombstone stays in the cloud
  final custom = customs(a);
  await custom.createExercise(name: 'Sled push');
  await custom.syncWithCloud();
  final u = 'users/$uid';
  await _seed('$u/workout_templates/legacy', {
    'id': 'legacy',
    'programId': 'p1',
    'name': 'Old app day',
    'createdAt': '2026-09-01T00:00:00.000Z',
    'isArchived': false,
  });
  await _seed('$u/exercise_sets/s1', {
    'exerciseName': 'Bench press',
    'weight': 80.0,
    'reps': 8,
    'date': '2026-11-10T10:00:00.000',
  });
  await _seed('$u/workout_sessions/w1', {
    'id': 'w1',
    'programId': 'p1',
    'workoutTemplateId': live.id,
    'workoutNameSnapshot': 'Live',
    'date': '2026-11-10T10:00:00.000',
    'startedAt': '2026-11-10T10:00:00.000',
    'status': 'completed',
    'totalVolume': 640.0,
  });
  await _seed('$u/workout_programs/p1', {
    'id': 'p1',
    'name': 'PPL',
    'createdAt': '2026-11-01T00:00:00.000',
    'isActive': true,
  });
  await _seed('$u/body_measurements/m1', {
    'date': '2026-11-10T10:00:00.000',
    'waist': 80.0,
  });
  await _seed('$u/fcmTokens/${_hash('token-$run')}', {
    'token': 'token-$run',
    'platform': 'android',
    'createdAt': DateTime.utc(2026, 11),
    'updatedAt': DateTime.utc(2026, 11),
  });
  await _seed('$u/settings/notifications', {
    'inactivityRemindersEnabled': true,
    'language': 'ar',
    'timeZone': 'Africa/Cairo',
    'updatedAt': DateTime.utc(2026, 11),
  });
  final seeded = (await _collectionsUnder(u)).toSet();
  for (final name in [
    'workout_templates',
    'custom_exercises',
    'exercise_sets',
    'workout_sessions',
    'workout_programs',
    'body_measurements',
    'fcmTokens',
    'settings',
  ]) {
    expectTrue(seeded.contains(name), 'seeded $name');
  }
  return live.id;
}

Future<void> expectEverythingGone() async {
  expectEq(await _collectionsUnder('users/$uid'), <String>[], 'no data left');
  expectEq(await _exists('users/$uid'), false, 'profile deleted');
  expectEq(await _authAccountExists(uid), false, 'Auth account deleted');
}

Future<void> deletionScenarios() async {
  await scenario('deletion: removes every document of the account (synced '
      'days tombstoned first), then the Auth account', () async {
    await seedAccount();
    final steps = <String>[];
    final repository = FirebaseAccountDeletionRepository(
      auth: a.auth,
      firestore: a.firestore,
      serverTimeout: const Duration(seconds: 10),
      debugStep: (step) async => steps.add(step),
    );
    await repository.reauthenticate(_password);
    await repository.deleteAccount(uid);
    await expectEverythingGone();
    expectEq(steps.last, 'auth', 'Auth account goes last');
    expectTrue(
      steps.contains('tombstones:workout_templates') &&
          steps.contains('tombstones:custom_exercises'),
      'synced documents were tombstoned first: $steps',
    );
  });

  await scenario('deletion: interrupted part-way (offline): the Auth account '
      'is NOT deleted; finishing later removes everything', () async {
    await seedAccount();
    final interrupted = FirebaseAccountDeletionRepository(
      auth: a.auth,
      firestore: a.firestore,
      serverTimeout: const Duration(seconds: 5),
      debugStep: (step) async {
        if (step == 'collection:workout_templates') {
          await a.firestore.disableNetwork();
        }
      },
    );
    await interrupted.reauthenticate(_password);
    final error = await expectThrows<AccountDeletionException>(
      interrupted.deleteAccount(uid),
      'interrupted deletion',
    );
    expectEq(error.failure, AccountDeletionFailure.offline, 'reported offline');
    expectEq(await _authAccountExists(uid), true, 'Auth account kept');
    expectEq(await _exists('users/$uid'), true, 'profile kept');
    final left = await _collectionsUnder('users/$uid');
    expectTrue(!left.contains('exercise_sets'), 'sets removed before the cut');
    expectTrue(left.contains('workout_templates'), 'days not reached yet');
    final profileData = (await _admin('GET', 8080, '$_docs/users/$uid'))!;
    expectTrue(
      (profileData['fields'] as Map).containsKey('deletionStartedAt'),
      'the account was locked first',
    );
    // Locked: phone B (online) creates nothing, but still reads.
    final onB = days(b);
    await pull(onB);
    final madeOnB = await onB.createTemplate(programId: 'p1', name: 'New on B');
    await (await onB.syncEngine()).pushChanges();
    expectEq(
      await _exists('users/$uid/workout_templates/${madeOnB.id}'),
      false,
      'nothing new while the deletion is incomplete',
    );
    expectTrue(
      (await onB.getUserBox()).get(madeOnB.id) != null,
      "B's day kept on the phone",
    );

    await a.firestore.enableNetwork();
    await a.firestore.waitForPendingWrites();
    final resumed = FirebaseAccountDeletionRepository(
      auth: a.auth,
      firestore: a.firestore,
      serverTimeout: const Duration(seconds: 10),
    );
    await resumed.deleteAccount(uid);
    await expectEverythingGone();
  });

  await scenario('deletion: another phone keeps changing a synced day: '
      'retried; if it never settles it stops before the Auth account; then '
      'completes', () async {
    final dayId = await seedAccount();
    final onB = days(b);
    await pull(onB);
    var edits = 0;
    Future<void> editOnB() async {
      await onB.updateTemplate(templateId: dayId, name: 'Edit ${++edits}');
      await (await onB.syncEngine()).pushChanges();
    }

    final neverSettles = FirebaseAccountDeletionRepository(
      auth: a.auth,
      firestore: a.firestore,
      serverTimeout: const Duration(seconds: 10),
      debugStep: (step) async {
        if (step == 'tombstones:workout_templates') await editOnB();
      },
    );
    await neverSettles.reauthenticate(_password);
    final error = await expectThrows<AccountDeletionException>(
      neverSettles.deleteAccount(uid),
      'never-settling deletion',
    );
    expectEq(error.failure, AccountDeletionFailure.unknown, 'reported');
    expectEq(await _authAccountExists(uid), true, 'Auth account kept');
    expectEq((await cloudDay(dayId))['name'], 'Edit $edits', 'B edits kept');

    var once = false;
    final settlesAfterOne = FirebaseAccountDeletionRepository(
      auth: a.auth,
      firestore: a.firestore,
      serverTimeout: const Duration(seconds: 10),
      debugStep: (step) async {
        if (step == 'tombstones:workout_templates' && !once) {
          once = true;
          await editOnB();
        }
      },
    );
    await settlesAfterOne.deleteAccount(uid);
    await expectEverythingGone();
  });

  await scenario('deletion: another phone still signed in, with changes '
      'made offline, does not bring the data back afterwards', () async {
    final dayId = await seedAccount();
    final onB = days(b);
    await pull(onB);
    await b.firestore.disableNetwork();
    await onB.createTemplate(programId: 'p1', name: 'Made offline on B');
    await onB.updateTemplate(templateId: dayId, name: 'Edited offline on B');
    await (await onB.syncEngine()).pushChanges(); // queued by Firestore

    final repository = FirebaseAccountDeletionRepository(
      auth: a.auth,
      firestore: a.firestore,
      serverTimeout: const Duration(seconds: 10),
    );
    await repository.reauthenticate(_password);
    await repository.deleteAccount(uid);
    await expectEverythingGone();

    // Phone B comes back online and syncs as usual.
    await b.firestore.enableNetwork();
    try {
      await b.firestore.waitForPendingWrites().timeout(
        const Duration(seconds: 20),
      );
    } catch (_) {}
    try {
      await pull(onB);
    } catch (_) {}
    final left = await _collectionsUnder('users/$uid');
    expectEq(left, <String>[], 'data written back by phone B');
  });

  await scenario('deletion: another phone online DURING the deletion creates '
      'nothing (refused); the deletion completes', () async {
    await seedAccount();
    final onB = days(b);
    await pull(onB);
    final customB = customs(b);
    String? madeOnB;
    final repository = FirebaseAccountDeletionRepository(
      auth: a.auth,
      firestore: a.firestore,
      serverTimeout: const Duration(seconds: 10),
      debugStep: (step) async {
        if (step == 'collection:custom_exercises') {
          // Days already removed: B makes a new day and a new exercise.
          madeOnB = (await onB.createTemplate(programId: 'p1', name: 'B')).id;
          await (await onB.syncEngine()).pushChanges();
          await customB.createExercise(name: 'Made on B');
          await customB.syncWithCloud();
        }
      },
    );
    await repository.reauthenticate(_password);
    await repository.deleteAccount(uid);
    await expectEverythingGone();
    expectTrue(madeOnB != null, 'B tried to create');
    expectTrue(
      (await onB.getUserBox()).get(madeOnB!)!.syncMeta.isBlocked,
      "B's refused day is kept and flagged, not lost or retried blindly",
    );
  });

  await scenario('deletion: an old phone-era account (historical profile '
      'fields) is locked and deleted completely', () async {
    await _seed('users/$uid', {
      'uid': uid,
      'name': 'Phone-era user',
      'phoneNumber': '+201000000000',
      'authEmail': email,
    });
    await seedAccount();
    final repository = FirebaseAccountDeletionRepository(
      auth: a.auth,
      firestore: a.firestore,
      serverTimeout: const Duration(seconds: 10),
    );
    await repository.reauthenticate(_password);
    await repository.deleteAccount(uid);
    await expectEverythingGone();
  });

  await scenario('deletion: an account whose profile is already gone (an '
      'earlier attempt) still completes; nothing can be created', () async {
    await seedAccount();
    await _admin('DELETE', 8080, '$_docs/users/$uid');
    await expectThrows<CloudWriteRejected>(
      daysCloud(a).write('nothing', _v2('nothing', 0, 'w-no-profile')),
      'create without a profile',
    );
    final repository = FirebaseAccountDeletionRepository(
      auth: a.auth,
      firestore: a.firestore,
      serverTimeout: const Duration(seconds: 10),
    );
    await repository.reauthenticate(_password);
    await repository.deleteAccount(uid);
    await expectEverythingGone();
  });

  // Also run against the rules BEFORE Stage 2.2/Stage 2 (rollout: the build
  // reaches a phone before the rules are deployed): the lock is refused
  // there, and the deletion must still complete.
  await scenario('deletion: an account with old-format data only completes '
      '(also under the previous rules)', () async {
    final u = 'users/$uid';
    await _seed('$u/workout_templates/old', {
      'id': 'old',
      'programId': 'p1',
      'name': 'Old day',
      'createdAt': '2026-09-01T00:00:00.000Z',
      'isArchived': false,
    });
    await _seed('$u/exercise_sets/s1', {
      'exerciseName': 'Bench press',
      'weight': 80.0,
      'reps': 8,
      'date': '2026-11-10T10:00:00.000',
    });
    await _seed('$u/settings/notifications', {
      'inactivityRemindersEnabled': true,
      'language': 'ar',
      'timeZone': 'Africa/Cairo',
      'updatedAt': DateTime.utc(2026, 11),
    });
    final repository = FirebaseAccountDeletionRepository(
      auth: a.auth,
      firestore: a.firestore,
      serverTimeout: const Duration(seconds: 10),
    );
    await repository.reauthenticate(_password);
    await repository.deleteAccount(uid);
    await expectEverythingGone();
  });
}
