/// Per-record cloud sync state, stored INSIDE the record it describes (one
/// Hive `put` writes the content and its sync state together, so they can
/// never disagree after a crash).
///
/// Stored as a plain map of primitives (not a Hive type), so an older app
/// build reading the record simply ignores it.
///
/// "Has unsent changes" is not stored: it is derived from content
/// fingerprints (`contentHash(record) != syncedHash`). That catches every
/// write path, and an acknowledgement can never hide an edit made while
/// the write was in flight (it records the fingerprint that was SENT).
class SyncMeta {
  const SyncMeta({
    this.baseRevision,
    this.syncedHash,
    this.flightWriteId,
    this.flightHash,
    this.flightRevision,
    this.recentWriteIds = const [],
    this.conflictKey,
    this.conflictReason,
    this.blockedReason,
    this.origin,
    this.legacyDecision,
    this.legacyCandidate,
  });

  static const empty = SyncMeta();

  /// How many of this device's own write ids are remembered per record.
  static const int maxRecentWriteIds = 8;

  /// The server revision the local content is based on: `0` when the record
  /// is ready to be created in the cloud format, `null` when its cloud
  /// state is unknown (not migrated yet: decided against the server).
  final int? baseRevision;

  /// Fingerprint of the content the server last acknowledged (or that was
  /// adopted from the server). Null: nothing confirmed yet.
  final String? syncedHash;

  /// The write currently on its way to the server, if any.
  final String? flightWriteId;
  final String? flightHash;
  final int? flightRevision;

  /// This device's recent writes for the record (newest last). A rejected
  /// write that finds one of these on the server found its OWN earlier
  /// write (e.g. replayed by Firestore's offline queue after a restart),
  /// not another device's change.
  final List<String> recentWriteIds;

  /// Set while a conflict waits for the user: key of the saved local copy.
  final String? conflictKey;
  final String? conflictReason;

  /// Why pushing is paused (e.g. the security rules are not deployed yet).
  final String? blockedReason;

  /// `serverLegacy`: created on this device from an old-format cloud
  /// document (no local history of its own).
  final String? origin;

  /// `restored` / `dismissed`: the user's answer about older exercises.
  final String? legacyDecision;

  /// Older exercises found in an old-format cloud document:
  /// `{prompt: bool, savedAt: String?, items: [activity maps]}`.
  final Map<String, Object?>? legacyCandidate;

  bool get isMigrated => baseRevision != null;
  bool get hasFlight => flightWriteId != null;
  bool get hasConflict => conflictKey != null;
  bool get isBlocked => blockedReason != null;

  /// [writeId] was written by this device for this record.
  bool isOwnWrite(String? writeId) =>
      writeId != null &&
      (writeId == flightWriteId || recentWriteIds.contains(writeId));

  /// Content with fingerprint [hash] differs from what the cloud holds.
  bool hasUnsyncedChanges(String hash) => hash != syncedHash;

  SyncMeta _copy({
    Object? baseRevision = _keep,
    Object? syncedHash = _keep,
    Object? flightWriteId = _keep,
    Object? flightHash = _keep,
    Object? flightRevision = _keep,
    List<String>? recentWriteIds,
    Object? conflictKey = _keep,
    Object? conflictReason = _keep,
    Object? blockedReason = _keep,
    Object? origin = _keep,
    Object? legacyDecision = _keep,
    Object? legacyCandidate = _keep,
  }) => SyncMeta(
    baseRevision: _pick(baseRevision, this.baseRevision),
    syncedHash: _pick(syncedHash, this.syncedHash),
    flightWriteId: _pick(flightWriteId, this.flightWriteId),
    flightHash: _pick(flightHash, this.flightHash),
    flightRevision: _pick(flightRevision, this.flightRevision),
    recentWriteIds: recentWriteIds ?? this.recentWriteIds,
    conflictKey: _pick(conflictKey, this.conflictKey),
    conflictReason: _pick(conflictReason, this.conflictReason),
    blockedReason: _pick(blockedReason, this.blockedReason),
    origin: _pick(origin, this.origin),
    legacyDecision: _pick(legacyDecision, this.legacyDecision),
    legacyCandidate: _pick(legacyCandidate, this.legacyCandidate),
  );

  /// A write with [writeId] (content [hash]) is about to be sent as
  /// [revision] (= baseRevision + 1).
  SyncMeta withFlight({
    required String writeId,
    required String hash,
    required int revision,
  }) {
    final recent = [...recentWriteIds, writeId];
    return _copy(
      flightWriteId: writeId,
      flightHash: hash,
      flightRevision: revision,
      recentWriteIds: recent.length > maxRecentWriteIds
          ? recent.sublist(recent.length - maxRecentWriteIds)
          : recent,
      blockedReason: null,
    );
  }

  /// The server confirmed the in-flight write: it is now the base.
  SyncMeta acknowledged() => _copy(
    baseRevision: flightRevision,
    syncedHash: flightHash,
    flightWriteId: null,
    flightHash: null,
    flightRevision: null,
  );

  SyncMeta withoutFlight() =>
      _copy(flightWriteId: null, flightHash: null, flightRevision: null);

  /// Now based on the server's [revision] holding content [hash].
  SyncMeta adopted({required int revision, required String? hash}) => _copy(
    baseRevision: revision,
    syncedHash: hash,
    flightWriteId: null,
    flightHash: null,
    flightRevision: null,
    blockedReason: null,
  );

  SyncMeta withConflict(String key, String reason) => _copy(
    conflictKey: key,
    conflictReason: reason,
    flightWriteId: null,
    flightHash: null,
    flightRevision: null,
  );

  SyncMeta withoutConflict() => _copy(conflictKey: null, conflictReason: null);

  SyncMeta blocked(String reason) => _copy(
    blockedReason: reason,
    flightWriteId: null,
    flightHash: null,
    flightRevision: null,
  );

  SyncMeta unblocked() => _copy(blockedReason: null);

  SyncMeta migratedAsNew() => _copy(baseRevision: 0);

  SyncMeta withOrigin(String value) => _copy(origin: value);

  SyncMeta withLegacyCandidate(Map<String, Object?> candidate) =>
      _copy(legacyCandidate: candidate);

  SyncMeta withLegacyDecision(String decision) =>
      _copy(legacyDecision: decision, legacyCandidate: null);

  Map<String, dynamic>? toMap() {
    final map = <String, dynamic>{
      if (baseRevision != null) 'baseRevision': baseRevision,
      if (syncedHash != null) 'syncedHash': syncedHash,
      if (flightWriteId != null) 'flightWriteId': flightWriteId,
      if (flightHash != null) 'flightHash': flightHash,
      if (flightRevision != null) 'flightRevision': flightRevision,
      if (recentWriteIds.isNotEmpty) 'recentWriteIds': recentWriteIds,
      if (conflictKey != null) 'conflictKey': conflictKey,
      if (conflictReason != null) 'conflictReason': conflictReason,
      if (blockedReason != null) 'blockedReason': blockedReason,
      if (origin != null) 'origin': origin,
      if (legacyDecision != null) 'legacyDecision': legacyDecision,
      if (legacyCandidate != null) 'legacyCandidate': legacyCandidate,
    };
    return map.isEmpty ? null : map;
  }

  factory SyncMeta.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return empty;
    T? read<T>(String key) {
      final value = map[key];
      return value is T ? value : null;
    }

    final candidate = map['legacyCandidate'];
    final recent = map['recentWriteIds'];
    return SyncMeta(
      baseRevision: read<int>('baseRevision'),
      syncedHash: read<String>('syncedHash'),
      flightWriteId: read<String>('flightWriteId'),
      flightHash: read<String>('flightHash'),
      flightRevision: read<int>('flightRevision'),
      recentWriteIds: recent is List
          ? List.unmodifiable(recent.whereType<String>())
          : const [],
      conflictKey: read<String>('conflictKey'),
      conflictReason: read<String>('conflictReason'),
      blockedReason: read<String>('blockedReason'),
      origin: read<String>('origin'),
      legacyDecision: read<String>('legacyDecision'),
      legacyCandidate: candidate is Map
          ? deepStringKeys(candidate) as Map<String, Object?>
          : null,
    );
  }
}

const Object _keep = Object();

T? _pick<T>(Object? value, T? current) =>
    identical(value, _keep) ? current : value as T?;

/// Hive returns nested maps as `Map<dynamic, dynamic>`; restores
/// `Map<String, Object?>` all the way down.
Object? deepStringKeys(Object? value) => switch (value) {
  Map() => <String, Object?>{
    for (final entry in value.entries)
      entry.key.toString(): deepStringKeys(entry.value),
  },
  List() => [for (final item in value) deepStringKeys(item)],
  _ => value,
};
