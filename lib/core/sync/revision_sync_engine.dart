import 'dart:async';

import 'package:ae_coaching/core/sync/revision_cloud.dart';
import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// How a record type maps to the cloud (one per synced collection).
abstract class SyncAdapter<T extends Object> {
  String get kind;
  SyncMeta metaOf(T item);
  T withMeta(T item, SyncMeta meta);

  /// Fingerprint of the user-visible content (canonical SHA-256).
  String fingerprint(T item);

  /// The document body (without the sync fields the engine adds).
  Map<String, dynamic> cloudContent(T item);

  /// Extra fields written with the content (e.g. a recorded decision).
  Map<String, dynamic> extraCloudFields(T item) => const {};

  /// A record from a schema-2 document, with [meta].
  T fromCloud(CloudDoc doc, SyncMeta meta);

  /// A local record for an OLD-format document that this device does not
  /// have (null: ignore it). It gets `origin: serverLegacy`.
  T? fromLegacyCloud(CloudDoc doc) => null;

  /// The content of an OLD-format document in the cloud body format, for
  /// a conflict copy (null: not convertible).
  Map<String, dynamic>? legacyCloudContent(CloudDoc doc) => null;

  /// A record created only from an old-format document's header, with no
  /// content of its own yet.
  bool isLegacyShell(T item) => false;

  /// A never-migrated local record next to an OLD-format document.
  LegacyOutcome legacyPlan(T local, CloudDoc legacyDoc) =>
      const LegacyOutcome.migrate();

  /// Why the cloud could never accept [item] as it is (e.g. more activities
  /// than a day may hold), or null. Such a record is not sent: it is
  /// blocked with `local:<reason>` until the user fixes it here.
  String? cannotSync(T item) => null;
}

/// What to do with a never-migrated record whose cloud document is old.
class LegacyOutcome {
  /// Migrate the local content (local is authoritative); [candidate]: older
  /// cloud content kept available for a manual, confirmed restore.
  const LegacyOutcome.migrate({this.candidate}) : awaitUser = false;

  /// Do not migrate yet: the user must decide about [candidate] first.
  const LegacyOutcome.awaitUser(Map<String, Object?> this.candidate)
    : awaitUser = true;

  final bool awaitUser;
  final Map<String, Object?>? candidate;
}

class SyncReport {
  int pulled = 0;
  int pushed = 0;
  int removed = 0;
  int deleted = 0;
  int conflicts = 0;
  int awaitingUser = 0;
  int blocked = 0;
  int skipped = 0;
  bool offline = false;

  /// How the server was read: [PullKind.none] (push only),
  /// [PullKind.changes] (only what changed since the last pull) or
  /// [PullKind.full] (every document).
  PullKind pull = PullKind.none;

  @override
  String toString() =>
      'SyncReport(pull: ${pull.name}, pulled: $pulled, pushed: $pushed, '
      'removed: $removed, deleted: $deleted, conflicts: $conflicts, '
      'awaitingUser: $awaitingUser, blocked: $blocked, skipped: $skipped, '
      'offline: $offline)';
}

enum PullKind { none, changes, full }

class SyncVerification {
  const SyncVerification(this.checked, this.mismatches);
  final int checked;
  final List<String> mismatches;
  bool get complete => mismatches.isEmpty;
}

/// Conflict reasons (stored with the conflict copy and on the record).
abstract final class SyncConflictReason {
  /// Both sides changed the same record.
  static const editedElsewhere = 'editedElsewhere';

  /// Changed here, deleted on another device.
  static const deletedElsewhere = 'deletedElsewhere';

  /// Deleted here, changed on another device (the record is restored).
  static const deletedHereEditedElsewhere = 'deletedHereEditedElsewhere';

  /// A never-migrated local record differs from the migrated cloud copy.
  static const differsFromCloud = 'differsFromCloud';

  /// An older app build replaced a migrated document (old rules only).
  static const overwrittenByOlderBuild = 'overwrittenByOlderBuild';
}

/// Revision-protected, offline-first sync of one Hive box with one cloud
/// collection.
///
/// Guarantees (with the security rules, which accept a write only if its
/// `baseRevision` equals the server's current `revision`):
/// - a local edit is sent based on the revision its content came from, and
///   that base only moves when the server confirms OUR write (writeId), when
///   server content is adopted wholesale, or on an explicit user choice;
///   stale content can never be relabelled as newer;
/// - a write that the server refuses is never retried blindly: the server
///   state decides (our own late write, identical content, conflict…);
/// - conflicts keep a full copy of the local version until the user
///   deletes it: nothing is lost silently;
/// - deletions are revision-checked tombstones, not raw deletes;
/// - every state change is one Hive `put` (+ flush), and every multi-step
///   change is ordered and idempotent, so a crash at any point resumes.
///
/// Local UI operations ([markDeleted], [keepMine], [keepServer]) never wait
/// for the network. Network work runs one at a time ([syncAll],
/// [pushChanges]).
///
/// Reads (Firebase Spark quotas): a local edit only PUSHES ([requestPush]),
/// which reads nothing unless the server refuses a write (then just that
/// document). A pull ([syncAll]) reads only the documents changed since the
/// previous pull (by `serverUpdatedAt`, with an overlap of [changeOverlap]);
/// every [fullPullInterval] (and the first time) it reads everything, which
/// also finds old-format documents written by older builds and documents
/// deleted outright. Without a [state] box every pull is full.
class RevisionSyncEngine<T extends Object> {
  RevisionSyncEngine({
    required this.records,
    required this.conflicts,
    required this.tombstones,
    required this.cloud,
    required this.adapter,
    required this.newWriteId,
    this.state,
    this.fullPullInterval = const Duration(hours: 24),
    this.changeOverlap = const Duration(minutes: 2),
    DateTime Function()? clock,
    @visibleForTesting this.faultHook,
  }) : _clock = clock ?? DateTime.now;

  final Box<T> records;
  final Box<Map> conflicts;
  final Box<Map> tombstones;
  final RevisionCloud cloud;
  final SyncAdapter<T> adapter;
  final String Function() newWriteId;

  /// Where the pull position is kept (the account's `sync_state` box).
  final Box<Map>? state;
  final Duration fullPullInterval;

  /// Re-read window before the newest change seen: a write whose server
  /// time is just before it may become visible slightly later.
  final Duration changeOverlap;
  final DateTime Function() _clock;

  /// Prefix of a block found on this device ([SyncAdapter.cannotSync]).
  static const localBlockPrefix = 'local:';

  /// Throws at named points to simulate a crash (tests only).
  final FutureOr<void> Function(String point)? faultHook;

  Future<void> _tail = Future.value();
  final Set<String> _retriedBlocked = {};

  String _tombstoneKey(String id) => '${adapter.kind}:$id';

  Future<R> _locked<R>(Future<R> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _fault(String point) async => faultHook?.call(point);

  Future<void> _put(String id, T value) async {
    await records.put(id, value);
    await records.flush();
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Settles in-flight writes, pulls (only the changes since the last pull
  /// when possible; everything with [fullPull]), pushes changes and
  /// deletions. Being offline is not an error (reported); other failures
  /// propagate.
  Future<SyncReport> syncAll({bool fullPull = false}) =>
      _locked(() => _run(pull: true, forceFull: fullPull));

  /// Pushes local changes and deletions only. Reads nothing unless a write
  /// is refused (then only that document, to find out why).
  Future<SyncReport> pushChanges() => _locked(() => _run(pull: false));

  Future<SyncReport>? _waiting;

  /// Fire-and-forget push for UI changes: requests made while one is
  /// waiting to start share it, and failures are logged, never thrown.
  Future<SyncReport> requestPush() {
    final waiting = _waiting;
    if (waiting != null) return waiting;
    final run =
        _locked(() {
          _waiting = null;
          return _run(pull: false);
        }).catchError((Object error, StackTrace stack) {
          // Boxes closed meanwhile (sign-out): the change waits for the
          // next sync of that account; nothing to report.
          if (kDebugMode && records.isOpen) {
            debugPrint('[Sync] ${adapter.kind} failed: $error');
          }
          return SyncReport();
        });
    _waiting = run;
    return run;
  }

  Future<SyncReport> _run({required bool pull, bool forceFull = false}) async {
    final report = SyncReport();
    try {
      await _completeInterruptedDeletes();
      if (pull) await _pull(report, forceFull: forceFull);
      for (final key in records.keys.toList()) {
        await _isolated(key as String, report, () => _push(key, report));
      }
      for (final key in tombstones.keys.toList()) {
        if ((key as String).startsWith('${adapter.kind}:')) {
          await _pushTombstone(key, report);
        }
      }
    } on CloudUnavailable {
      report.offline = true;
    }
    return report;
  }

  /// Runs [step] for one record; a malformed record is skipped (and kept
  /// as is) instead of stopping the whole sync. Being offline still stops.
  Future<void> _isolated(
    String id,
    SyncReport report,
    Future<void> Function() step,
  ) async {
    try {
      await step();
    } on CloudUnavailable {
      rethrow;
    } on Exception catch (error) {
      _skip(id, report, error);
    } on TypeError catch (error) {
      // A document with fields of the wrong type (malformed data).
      _skip(id, report, error);
    }
  }

  void _skip(String id, SyncReport report, Object error) {
    report.skipped++;
    if (kDebugMode) debugPrint('[Sync] ${adapter.kind} $id skipped: $error');
  }

  /// Deletes [id] here now, and in the cloud as a revision-checked
  /// tombstone on the next sync. Local only: never waits for the network.
  Future<void> markDeleted(String id) async {
    final item = records.get(id);
    if (item == null) return;
    final meta = adapter.metaOf(item);
    await tombstones.put(_tombstoneKey(id), <String, dynamic>{
      'kind': adapter.kind,
      'id': id,
      'baseRevision': meta.baseRevision ?? 0,
      if (meta.flightWriteId != null) 'pendingWriteId': meta.flightWriteId,
      if (meta.flightRevision != null) 'pendingRevision': meta.flightRevision,
      'recentWriteIds': meta.recentWriteIds,
      'content': adapter.cloudContent(item),
      'contentHash': adapter.fingerprint(item),
      'deletedAt': _clock().toUtc().toIso8601String(),
    });
    await tombstones.flush();
    await _fault('tombstoneRecorded');
    await records.delete(id);
    await records.flush();
  }

  /// Resolves a conflict in favour of this device's version.
  Future<void> keepMine(String id) async {
    final item = records.get(id);
    if (item == null) return;
    final meta = adapter.metaOf(item);
    final key = meta.conflictKey;
    if (key == null) return;
    if (meta.conflictReason == SyncConflictReason.deletedHereEditedElsewhere) {
      await _put(id, adapter.withMeta(item, meta.withoutConflict()));
      await markDeleted(id);
      return;
    }
    final copy = conflicts.get(key);
    if (copy == null) return;
    final content = Map<String, dynamic>.from(
      deepStringKeys(copy['content']) as Map,
    );
    // Based on the server revision recorded when the conflict was found:
    // the user's explicit choice is the only way content is re-based.
    final mine = adapter.fromCloud(
      CloudDoc(id, {...content, 'schemaVersion': 2}),
      meta.withoutConflict(),
    );
    await _put(id, mine);
  }

  /// Resolves a conflict in favour of the cloud version. The local copy
  /// stays available until [discardConflictCopy].
  Future<void> keepServer(String id) async {
    final item = records.get(id);
    if (item == null) return;
    final meta = adapter.metaOf(item);
    final key = meta.conflictKey;
    if (key == null) return;
    switch (meta.conflictReason) {
      case SyncConflictReason.deletedElsewhere:
        await records.delete(id);
        await records.flush();
      case SyncConflictReason.overwrittenByOlderBuild:
        final server = conflicts.get(key)?['serverLegacyContent'];
        if (server is Map) {
          await _put(
            id,
            adapter.fromCloud(
              CloudDoc(id, {
                ...Map<String, dynamic>.from(deepStringKeys(server) as Map),
                'schemaVersion': 2,
              }),
              meta.withoutConflict(),
            ),
          );
        } else {
          await _put(id, adapter.withMeta(item, meta.withoutConflict()));
        }
      default:
        // The record already holds the cloud version.
        await _put(id, adapter.withMeta(item, meta.withoutConflict()));
    }
  }

  Future<void> discardConflictCopy(String key) async {
    await conflicts.delete(key);
    await conflicts.flush();
  }

  /// Conflict copies of this record type, newest first.
  List<Map<String, dynamic>> conflictCopies() => [
    for (final entry in conflicts.toMap().entries)
      if (entry.value['kind'] == adapter.kind)
        {
          ...Map<String, dynamic>.from(deepStringKeys(entry.value) as Map),
          'key': entry.key,
        },
  ]..sort((a, b) => '${b['detectedAt']}'.compareTo('${a['detectedAt']}'));

  /// Re-reads every document from the server and checks that each local
  /// record is confirmed (same revision and fingerprint), or explicitly
  /// waiting for the user. Pending deletions and in-flight writes count as
  /// not complete.
  Future<SyncVerification> verifyAgainstServer() => _locked(() async {
    final docs = {for (final doc in await cloud.fetchAll()) doc.id: doc};
    final mismatches = <String>[];
    var checked = 0;
    for (final key in records.keys) {
      final id = key as String;
      final item = records.get(id)!;
      final meta = adapter.metaOf(item);
      checked++;
      if (meta.hasConflict) continue;
      final doc = docs[id];
      final hash = adapter.fingerprint(item);
      if (!meta.isMigrated) {
        mismatches.add('$id: not migrated');
      } else if (meta.hasFlight) {
        mismatches.add('$id: write in flight');
      } else if (doc == null || !doc.isV2 || doc.isTombstone) {
        mismatches.add('$id: missing in the cloud');
      } else if (doc.revision != meta.baseRevision ||
          doc.contentHash != meta.syncedHash ||
          hash != meta.syncedHash) {
        mismatches.add('$id: differs from the cloud');
      }
    }
    for (final key in tombstones.keys) {
      if ((key as String).startsWith('${adapter.kind}:')) {
        mismatches.add('$key: deletion pending');
      }
    }
    return SyncVerification(checked, mismatches);
  });

  // ── Pull ────────────────────────────────────────────────────────────────

  Future<void> _completeInterruptedDeletes() async {
    for (final key in tombstones.keys.toList()) {
      final id = tombstones.get(key)?['id'];
      if ((key as String).startsWith('${adapter.kind}:') &&
          id is String &&
          records.containsKey(id)) {
        await records.delete(id);
        await records.flush();
      }
    }
  }

  String get _pullStateKey => 'pull.${adapter.kind}';

  /// The server time to read changes from, or null when everything must be
  /// read: no [state] box, never pulled fully on this device, or the last
  /// full pull is older than [fullPullInterval] (or the clock moved back).
  DateTime? _changesSince() {
    final saved = state?.get(_pullStateKey);
    if (saved == null) return null;
    final fullAt = DateTime.tryParse('${saved['fullAt']}');
    if (fullAt == null) return null;
    final age = _clock().difference(fullAt);
    if (age.isNegative || age >= fullPullInterval) return null;
    final cursor =
        DateTime.tryParse('${saved['cursor']}') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return cursor.subtract(changeOverlap);
  }

  /// Saved only once the pull has been applied: an interrupted pull is
  /// read again.
  Future<void> _savePullState(List<CloudDoc> docs, {required bool full}) async {
    final box = state;
    if (box == null) return;
    final saved = box.get(_pullStateKey);
    var cursor = DateTime.tryParse('${saved?['cursor']}');
    for (final doc in docs) {
      final time = doc.serverUpdatedAt;
      if (time != null && (cursor == null || time.isAfter(cursor))) {
        cursor = time;
      }
    }
    await box.put(_pullStateKey, <String, dynamic>{
      'fullAt': full ? _clock().toUtc().toIso8601String() : saved?['fullAt'],
      if (cursor != null) 'cursor': cursor.toUtc().toIso8601String(),
    });
    await box.flush();
  }

  Future<void> _pull(SyncReport report, {required bool forceFull}) async {
    final since = forceFull ? null : _changesSince();
    final full = since == null;
    final docs = full
        ? await cloud.fetchAll()
        : await cloud.fetchChangedSince(since);
    report.pull = full ? PullKind.full : PullKind.changes;
    final byId = {for (final doc in docs) doc.id: doc};
    for (final key in records.keys.toList()) {
      final id = key as String;
      final item = records.get(id);
      if (item == null) continue;
      final meta = adapter.metaOf(item);
      if (meta.hasConflict) {
        report.conflicts++;
        continue;
      }
      final listed = full || byId.containsKey(id);
      // Not changed on the server since the last pull: nothing to do,
      // unless this device still has to find out about it (a write that
      // may or may not have landed, or a record never matched with the
      // cloud). Then only that document is read.
      if (!listed && meta.isMigrated && !meta.hasFlight) continue;
      await _isolated(id, report, () async {
        final doc = listed ? byId[id] : await cloud.fetch(id);
        if (meta.hasFlight) {
          await _settleFlight(id, doc, report);
        } else if (!meta.isMigrated) {
          await _migrateLocal(id, item, doc, report);
        } else {
          await _reconcile(id, item, meta, doc, report);
        }
      });
    }
    for (final doc in docs) {
      if (records.containsKey(doc.id) ||
          tombstones.containsKey(_tombstoneKey(doc.id)) ||
          doc.isTombstone) {
        continue;
      }
      await _isolated(doc.id, report, () => _pullNew(doc, report));
    }
    await _savePullState(docs, full: full);
  }

  /// A cloud document this device does not have yet.
  Future<void> _pullNew(CloudDoc doc, SyncReport report) async {
    if (doc.isV2) {
      final meta = SyncMeta.empty.adopted(
        revision: doc.revision,
        hash: doc.contentHash,
      );
      await _put(doc.id, adapter.fromCloud(doc, meta));
      report.pulled++;
      return;
    }
    final shell = adapter.fromLegacyCloud(doc);
    if (shell == null) return;
    final withOrigin = adapter.withMeta(
      shell,
      adapter.metaOf(shell).withOrigin('serverLegacy'),
    );
    await _put(doc.id, withOrigin);
    await _migrateLocal(doc.id, withOrigin, doc, report);
  }

  /// A migrated record with no write in flight vs the server document.
  Future<void> _reconcile(
    String id,
    T item,
    SyncMeta meta,
    CloudDoc? doc,
    SyncReport report,
  ) async {
    final hash = adapter.fingerprint(item);
    final dirty = meta.hasUnsyncedChanges(hash);
    if (doc == null) {
      if (meta.baseRevision == 0) return; // not created yet: push creates it
      if (dirty) {
        await _conflict(
          id,
          item,
          null,
          SyncConflictReason.deletedElsewhere,
          report,
        );
      } else {
        await records.delete(id);
        await records.flush();
        report.removed++;
      }
      return;
    }
    if (doc.isV2 && doc.revision == meta.baseRevision) {
      // In step with the server (including a deletion the user chose to
      // override): push sends any local changes.
      return;
    }
    if (doc.isTombstone) {
      if (dirty) {
        await _conflict(
          id,
          item,
          doc,
          SyncConflictReason.deletedElsewhere,
          report,
        );
      } else {
        await records.delete(id);
        await records.flush();
        report.removed++;
      }
      return;
    }
    if (!doc.isV2) {
      if (meta.baseRevision == 0) return; // push migrates it (revision 0)
      await _conflict(
        id,
        item,
        doc,
        SyncConflictReason.overwrittenByOlderBuild,
        report,
      );
      return;
    }
    final base = meta.baseRevision!;
    if (doc.revision == base) return; // in step: push sends local changes
    if (doc.revision < base) {
      await _put(id, adapter.withMeta(item, meta.blocked('serverBehind')));
      report.blocked++;
      return;
    }
    if (!dirty) {
      final adopted = meta.adopted(
        revision: doc.revision,
        hash: doc.contentHash,
      );
      await _put(id, adapter.fromCloud(doc, adopted));
      report.pulled++;
    } else if (doc.contentHash == hash || meta.isOwnWrite(doc.writeId)) {
      // Same content, or our own earlier write that landed late: re-base
      // on it (local edits remain unsynced and are pushed next).
      await _put(
        id,
        adapter.withMeta(
          item,
          meta.adopted(revision: doc.revision, hash: doc.contentHash),
        ),
      );
    } else {
      await _conflict(
        id,
        item,
        doc,
        SyncConflictReason.editedElsewhere,
        report,
      );
    }
  }

  /// A never-migrated record (cloud state unknown) vs the server document.
  Future<void> _migrateLocal(
    String id,
    T item,
    CloudDoc? doc,
    SyncReport report,
  ) async {
    final meta = adapter.metaOf(item);
    final hash = adapter.fingerprint(item);
    if (doc == null) {
      await _put(id, adapter.withMeta(item, meta.migratedAsNew()));
      return;
    }
    if (doc.isTombstone) {
      await _conflict(
        id,
        item,
        doc,
        SyncConflictReason.deletedElsewhere,
        report,
      );
      return;
    }
    if (doc.isV2) {
      if (doc.contentHash == hash || adapter.isLegacyShell(item)) {
        // Identical, or only an empty shell of an old document that
        // another device has migrated meanwhile: take the cloud version.
        final adopted = meta.adopted(
          revision: doc.revision,
          hash: doc.contentHash,
        );
        await _put(id, adapter.fromCloud(doc, adopted));
      } else {
        await _conflict(
          id,
          item,
          doc,
          SyncConflictReason.differsFromCloud,
          report,
        );
      }
      return;
    }
    final plan = adapter.legacyPlan(item, doc);
    if (plan.awaitUser) {
      await _put(
        id,
        adapter.withMeta(item, meta.withLegacyCandidate(plan.candidate!)),
      );
      report.awaitingUser++;
      return;
    }
    var next = meta.migratedAsNew();
    final candidate = plan.candidate;
    if (candidate != null) next = next.withLegacyCandidate(candidate);
    await _put(id, adapter.withMeta(item, next));
  }

  // ── Push ────────────────────────────────────────────────────────────────

  Future<void> _push(String id, SyncReport report, {int depth = 0}) async {
    final item = records.get(id);
    if (item == null) return;
    final meta = adapter.metaOf(item);
    if (meta.hasConflict || !meta.isMigrated || meta.hasFlight) return;
    // Content the server would always refuse: never sent, shown to the
    // user instead (re-checked on every push, so a fix syncs right away).
    final problem = adapter.cannotSync(item);
    if (problem != null) {
      final reason = '$localBlockPrefix$problem';
      if (meta.blockedReason != reason) {
        await _block(id, item, meta, reason, report);
      } else {
        report.blocked++;
      }
      return;
    }
    final localBlock = meta.blockedReason?.startsWith(localBlockPrefix);
    if (meta.isBlocked && localBlock != true) {
      if (_retriedBlocked.contains(id)) return;
      _retriedBlocked.add(id); // retried at most once per app session
    }
    final hash = adapter.fingerprint(item);
    if (!meta.hasUnsyncedChanges(hash)) return;

    final base = meta.baseRevision!;
    final writeId = newWriteId();
    final payload = <String, dynamic>{
      ...adapter.cloudContent(item),
      ...adapter.extraCloudFields(item),
      'schemaVersion': 2,
      'baseRevision': base,
      'revision': base + 1,
      'writeId': writeId,
      'contentHash': hash,
      'deleted': false,
    };
    // Recorded BEFORE sending (and flushed): after a crash we know which
    // write might be on the server.
    await _put(
      id,
      adapter.withMeta(
        item,
        meta.withFlight(writeId: writeId, hash: hash, revision: base + 1),
      ),
    );
    await _fault('flightRecorded');
    try {
      await cloud.write(id, payload);
    } on CloudWriteRejected {
      await _afterRejection(id, await cloud.fetch(id), report);
      // Re-based (our own earlier write, or identical content): send the
      // remaining edits now. Not after a conflict or a block.
      final after = records.get(id);
      if (depth == 0 && after != null) {
        final next = adapter.metaOf(after);
        if (next.isMigrated &&
            !next.hasConflict &&
            !next.isBlocked &&
            !next.hasFlight) {
          await _push(id, report, depth: 1);
        }
      }
      return;
    }
    await _fault('cloudWritten');
    await _acknowledge(id, writeId);
    report.pushed++;
  }

  Future<void> _acknowledge(String id, String writeId) async {
    final item = records.get(id);
    if (item == null) {
      // Deleted here while the write was in flight: the deletion must now
      // be based on the revision that write created.
      final key = _tombstoneKey(id);
      final intent = tombstones.get(key);
      if (intent != null && intent['pendingWriteId'] == writeId) {
        await tombstones.put(key, {
          ...intent,
          'baseRevision': intent['pendingRevision'],
          'pendingWriteId': null,
          'pendingRevision': null,
        });
        await tombstones.flush();
      }
      return;
    }
    final meta = adapter.metaOf(item);
    if (meta.flightWriteId != writeId) return;
    // Only the sync state changes: content edited during the flight is
    // kept, and stays unsynced (its fingerprint differs from the one sent).
    await _put(id, adapter.withMeta(item, meta.acknowledged()));
  }

  /// A write is in flight from an earlier run: find out what happened to
  /// it, using the server state.
  Future<void> _settleFlight(
    String id,
    CloudDoc? doc,
    SyncReport report,
  ) async {
    final item = records.get(id)!;
    final meta = adapter.metaOf(item);
    if (doc != null && doc.writeId == meta.flightWriteId) {
      await _acknowledge(id, meta.flightWriteId!);
      return;
    }
    final base = meta.baseRevision ?? 0;
    final serverStill = doc == null
        ? base == 0
        : (!doc.isTombstone && doc.revision == base);
    if (serverStill) {
      // Never landed (a replay of it would now be refused by the rules if
      // ours lands first, or recognised as ours if it lands first).
      await _put(id, adapter.withMeta(item, meta.withoutFlight()));
      return;
    }
    await _afterRejection(id, doc, report);
  }

  /// The server refused our write, or moved past its base: decide from the
  /// server state, never by retrying blindly.
  Future<void> _afterRejection(
    String id,
    CloudDoc? doc,
    SyncReport report,
  ) async {
    final item = records.get(id);
    if (item == null) return; // deleted here: the tombstone handles it
    final meta = adapter.metaOf(item);
    final hash = adapter.fingerprint(item);
    final base = meta.baseRevision ?? 0;

    if (doc != null && doc.isV2 && meta.isOwnWrite(doc.writeId)) {
      await _put(
        id,
        adapter.withMeta(
          item,
          meta.adopted(revision: doc.revision, hash: doc.contentHash),
        ),
      );
      return;
    }
    if (doc == null) {
      if (base == 0) {
        await _block(id, item, meta, 'rejected', report);
      } else {
        await _conflict(
          id,
          item,
          null,
          SyncConflictReason.deletedElsewhere,
          report,
        );
      }
      return;
    }
    if (doc.isTombstone) {
      await _conflict(
        id,
        item,
        doc,
        SyncConflictReason.deletedElsewhere,
        report,
      );
      return;
    }
    if (!doc.isV2) {
      if (base == 0) {
        // Correctly based on an old-format document, yet refused: the new
        // security rules are not deployed. Keep everything, retry later.
        await _block(id, item, meta, 'rulesNotDeployed', report);
      } else {
        await _conflict(
          id,
          item,
          doc,
          SyncConflictReason.overwrittenByOlderBuild,
          report,
        );
      }
      return;
    }
    if (doc.revision > base) {
      if (doc.contentHash == hash) {
        await _put(
          id,
          adapter.withMeta(
            item,
            meta.adopted(revision: doc.revision, hash: hash),
          ),
        );
      } else {
        await _conflict(
          id,
          item,
          doc,
          SyncConflictReason.editedElsewhere,
          report,
        );
      }
      return;
    }
    await _block(id, item, meta, 'rejected', report);
  }

  Future<void> _block(
    String id,
    T item,
    SyncMeta meta,
    String reason,
    SyncReport report,
  ) async {
    await _put(id, adapter.withMeta(item, meta.blocked(reason)));
    report.blocked++;
    if (kDebugMode) debugPrint('[Sync] ${adapter.kind} $id blocked: $reason');
  }

  /// Saves the local version as a conflict copy FIRST, then shows the cloud
  /// version (or keeps the local one when the cloud has none). Idempotent:
  /// the copy's key is derived from the local content.
  Future<void> _conflict(
    String id,
    T item,
    CloudDoc? doc,
    String reason,
    SyncReport report,
  ) async {
    var current = item;
    // Edits made while the copy was being saved get their own copy too.
    for (var attempt = 0; attempt < 3; attempt++) {
      final localHash = adapter.fingerprint(current);
      final key = '${adapter.kind}:$id:$localHash';
      if (!conflicts.containsKey(key)) {
        final serverLegacy = doc == null || doc.isV2
            ? null
            : adapter.legacyCloudContent(doc);
        await conflicts.put(key, <String, dynamic>{
          'kind': adapter.kind,
          'id': id,
          'reason': reason,
          'detectedAt': _clock().toUtc().toIso8601String(),
          'localHash': localHash,
          'content': adapter.cloudContent(current),
          if (doc != null) 'serverRevision': doc.revision,
          'serverLegacyContent': ?serverLegacy,
        });
        await conflicts.flush();
      }
      await _fault('conflictCopySaved');
      final latest = records.get(id) ?? current;
      if (adapter.fingerprint(latest) != localHash) {
        current = latest;
        continue;
      }
      final meta = adapter.metaOf(latest);
      if (doc != null && doc.isV2 && !doc.isTombstone) {
        await _put(
          id,
          adapter.fromCloud(
            doc,
            meta
                .adopted(revision: doc.revision, hash: doc.contentHash)
                .withConflict(key, reason),
          ),
        );
      } else {
        // Nothing usable in the cloud: keep the local version visible.
        await _put(
          id,
          adapter.withMeta(
            latest,
            meta
                .adopted(revision: doc?.revision ?? 0, hash: null)
                .withConflict(key, reason),
          ),
        );
      }
      report.conflicts++;
      return;
    }
  }

  // ── Tombstones ──────────────────────────────────────────────────────────

  Future<void> _pushTombstone(String key, SyncReport report) async {
    final raw = tombstones.get(key);
    if (raw == null) return;
    final intent = Map<String, dynamic>.from(deepStringKeys(raw) as Map);
    final id = intent['id'] as String;
    final base = (intent['baseRevision'] as num?)?.toInt() ?? 0;
    final writeId = newWriteId();
    final recent = [
      ...?(intent['recentWriteIds'] as List?)?.whereType<String>(),
      if (intent['pendingWriteId'] is String)
        intent['pendingWriteId'] as String,
      writeId,
    ];
    final updated = {
      ...intent,
      'recentWriteIds': recent,
      'flightWriteId': writeId,
    };
    await tombstones.put(key, updated);
    await tombstones.flush();
    final content = Map<String, dynamic>.from(intent['content'] as Map);
    try {
      await cloud.write(id, {
        ...content,
        'schemaVersion': 2,
        'baseRevision': base,
        'revision': base + 1,
        'writeId': writeId,
        'contentHash': intent['contentHash'],
        'deleted': true,
        'deletedAt': intent['deletedAt'],
      });
    } on CloudWriteRejected {
      await _afterTombstoneRejection(
        key,
        updated,
        await cloud.fetch(id),
        report,
      );
      return;
    }
    await tombstones.delete(key);
    await tombstones.flush();
    report.deleted++;
  }

  Future<void> _afterTombstoneRejection(
    String key,
    Map<String, dynamic> intent,
    CloudDoc? doc,
    SyncReport report,
  ) async {
    final id = intent['id'] as String;
    final base = (intent['baseRevision'] as num?)?.toInt() ?? 0;
    final own = ((intent['recentWriteIds'] as List?) ?? const [])
        .whereType<String>()
        .toSet();
    if (doc == null || doc.isTombstone) {
      // Already gone (deleted elsewhere, or by our own earlier attempt).
      await tombstones.delete(key);
      await tombstones.flush();
      report.deleted++;
      return;
    }
    if (doc.isV2 && own.contains(doc.writeId)) {
      // Our own write landed: delete based on it next time.
      await tombstones.put(key, {...intent, 'baseRevision': doc.revision});
      await tombstones.flush();
      return;
    }
    if (!doc.isV2 && base == 0) {
      await tombstones.put(key, {...intent, 'blocked': 'rulesNotDeployed'});
      await tombstones.flush();
      report.blocked++;
      return;
    }
    // Changed on another device after the version deleted here: restore
    // the cloud version, keep the deleted one as a copy, let the user say.
    final localHash = intent['contentHash'] as String;
    final copyKey = '${adapter.kind}:$id:$localHash';
    await conflicts.put(copyKey, <String, dynamic>{
      'kind': adapter.kind,
      'id': id,
      'reason': SyncConflictReason.deletedHereEditedElsewhere,
      'detectedAt': _clock().toUtc().toIso8601String(),
      'localHash': localHash,
      'content': intent['content'],
      'serverRevision': doc.revision,
    });
    await conflicts.flush();
    if (doc.isV2) {
      final meta = SyncMeta.empty
          .adopted(revision: doc.revision, hash: doc.contentHash)
          .withConflict(copyKey, SyncConflictReason.deletedHereEditedElsewhere);
      await _put(id, adapter.fromCloud(doc, meta));
    } else {
      final legacy = adapter.fromLegacyCloud(doc);
      if (legacy != null) {
        await _put(
          id,
          adapter.withMeta(
            legacy,
            SyncMeta.empty.withConflict(
              copyKey,
              SyncConflictReason.deletedHereEditedElsewhere,
            ),
          ),
        );
      }
    }
    await tombstones.delete(key);
    await tombstones.flush();
    report.conflicts++;
  }
}
