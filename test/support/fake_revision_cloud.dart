import 'dart:convert';

import 'package:ae_coaching/core/sync/revision_cloud.dart';
import 'package:ae_coaching/features/workout/domain/workout_limits.dart';

/// An in-memory cloud collection that applies the SAME acceptance rules as
/// `firestore.rules` (schema 2): revision compare-and-set, a new writeId per
/// write, the old-format `exerciseAssignments` field immutable, the
/// activity limit, older builds unable to overwrite or delete schema-2
/// documents. The Firebase Emulator tests check the real rules against the
/// same cases.
class FakeRevisionCloud implements RevisionCloud {
  FakeRevisionCloud({this.maxActivities = WorkoutLimits.maxActivitiesPerDay});

  final int maxActivities;
  final Map<String, Map<String, dynamic>> docs = {};

  /// No server reachable: every call throws [CloudUnavailable].
  bool offline = false;

  /// false: the OLD rules are deployed (schema-2 writes are refused, older
  /// builds may replace anything).
  bool newRulesDeployed = true;

  /// The write is applied but its acknowledgement is lost.
  bool loseNextAck = false;

  /// Runs just before a write is evaluated (e.g. another device writes
  /// first: a race).
  Future<void> Function(String id)? beforeWrite;

  /// Billed document reads, like Firestore: one per document returned, and
  /// at least one per query.
  int reads = 0;
  int accepted = 0;
  int rejected = 0;

  /// The server clock: each accepted write is stamped with it
  /// (`serverUpdatedAt`) and moves it on by [writeSpacing].
  DateTime serverTime = DateTime.utc(2026, 11, 1);
  Duration writeSpacing = const Duration(seconds: 1);

  Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  CloudDoc _doc(String id, Map<String, dynamic> stored) {
    final data = _copy(stored);
    final stamp = data.remove('serverUpdatedAt');
    return CloudDoc(
      id,
      data,
      serverUpdatedAt: stamp is String ? DateTime.parse(stamp) : null,
    );
  }

  @override
  Future<CloudDoc?> fetch(String id) async {
    if (offline) throw const CloudUnavailable();
    reads++;
    final doc = docs[id];
    return doc == null ? null : _doc(id, doc);
  }

  @override
  Future<List<CloudDoc>> fetchAll() async {
    if (offline) throw const CloudUnavailable();
    reads += docs.isEmpty ? 1 : docs.length;
    return [for (final e in docs.entries) _doc(e.key, e.value)];
  }

  int changeQueries = 0;

  @override
  Future<List<CloudDoc>> fetchChangedSince(DateTime since) async {
    if (offline) throw const CloudUnavailable();
    changeQueries++;
    final changed = [
      for (final e in docs.entries)
        if (e.value['serverUpdatedAt'] is String &&
            !DateTime.parse(
              e.value['serverUpdatedAt'] as String,
            ).isBefore(since))
          _doc(e.key, e.value),
    ];
    reads += changed.isEmpty ? 1 : changed.length;
    return changed;
  }

  @override
  Future<void> write(String id, Map<String, dynamic> data) async {
    if (offline) throw const CloudUnavailable();
    await beforeWrite?.call(id);
    final existing = docs[id];
    serverTime = serverTime.add(writeSpacing);
    final merged = {
      ...?existing,
      ..._copy(data),
      'serverUpdatedAt': serverTime.toIso8601String(),
    };
    if (!_acceptV2(existing, merged)) {
      rejected++;
      throw const CloudWriteRejected();
    }
    docs[id] = merged;
    accepted++;
    if (loseNextAck) {
      loseNextAck = false;
      throw const CloudUnavailable('acknowledgement lost');
    }
  }

  bool _acceptV2(Map<String, dynamic>? existing, Map<String, dynamic> merged) {
    if (!newRulesDeployed) return false; // old rules: unknown fields refused
    if (merged['schemaVersion'] != 2) return false;
    final current = existing == null || existing['schemaVersion'] != 2
        ? 0
        : existing['revision'] as int;
    final base = merged['baseRevision'];
    final revision = merged['revision'];
    if (base is! int || revision is! int) return false;
    if (base != current || revision != base + 1) return false;
    final writeId = merged['writeId'];
    if (writeId is! String || writeId.isEmpty || writeId.length > 64) {
      return false;
    }
    if (existing != null && existing['writeId'] == writeId) return false;
    final hash = merged['contentHash'];
    if (hash is! String || hash.length != 64) return false;
    final activities = merged['activities'];
    if (activities != null &&
        (activities is! List || activities.length > maxActivities)) {
      return false;
    }
    if (jsonEncode(existing?['exerciseAssignments']) !=
        jsonEncode(merged['exerciseAssignments'])) {
      return false;
    }
    return true;
  }

  // ── Older app builds (what the current production app does) ────────────

  /// A full `set()` in the old format. New rules: only over old-format (or
  /// missing) documents.
  bool legacyWrite(String id, Map<String, dynamic> data) {
    final existing = docs[id];
    if (newRulesDeployed &&
        existing != null &&
        existing['schemaVersion'] == 2) {
      rejected++;
      return false;
    }
    docs[id] = _copy(data);
    accepted++;
    return true;
  }

  /// A raw delete. New rules: old-format documents, or tombstones only.
  bool hardDelete(String id) {
    final existing = docs[id];
    if (newRulesDeployed &&
        existing != null &&
        existing['schemaVersion'] == 2 &&
        existing['deleted'] != true) {
      rejected++;
      return false;
    }
    docs.remove(id);
    return true;
  }
}
