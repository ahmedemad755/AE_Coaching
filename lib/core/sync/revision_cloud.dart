/// A document as the SERVER holds it (never a cache read).
class CloudDoc {
  CloudDoc(this.id, Map<String, dynamic> data, {this.serverUpdatedAt})
    : data = Map.unmodifiable(data);

  final String id;

  /// The document's fields, without `serverUpdatedAt` (see below).
  final Map<String, dynamic> data;

  /// The server time of the document's last schema-2 write (null for
  /// old-format documents). Used only to find what changed since a pull.
  final DateTime? serverUpdatedAt;

  /// Cloud format version: 2 = revision-protected. Older documents have none.
  bool get isV2 => data['schemaVersion'] == 2;

  /// The revision the next write must be based on (0 for old documents).
  int get revision => isV2 ? (data['revision'] as num?)?.toInt() ?? 0 : 0;

  bool get isTombstone => isV2 && data['deleted'] == true;
  String? get writeId => data['writeId'] as String?;
  String? get contentHash => data['contentHash'] as String?;
}

/// The server refused the write (security rules): typically a stale
/// `baseRevision`, an old-format document overwritten by an older build,
/// or rules that are not deployed yet. Never retried blindly.
class CloudWriteRejected implements Exception {
  const CloudWriteRejected([this.message = 'Rejected by the server.']);
  final String message;
  @override
  String toString() => 'CloudWriteRejected: $message';
}

/// No confirmed answer from the server (offline, timeout, signed out).
/// The write may still land later: callers keep it as "in flight".
class CloudUnavailable implements Exception {
  const CloudUnavailable([this.message = 'The server could not be reached.']);
  final String message;
  @override
  String toString() => 'CloudUnavailable: $message';
}

/// The server refused a READ (security rules): the rules for this collection
/// are not deployed yet, or the account may not read it (e.g. an unverified
/// email). Nothing is known about the server state, exactly like being
/// offline, so it is handled the same way: everything is kept and retried.
class CloudReadDenied extends CloudUnavailable {
  const CloudReadDenied([super.message = 'Reading was refused.']);
  @override
  String toString() => 'CloudReadDenied: $message';
}

/// One cloud collection with revision-protected documents.
abstract interface class RevisionCloud {
  /// The server's current document (bypassing any local cache), or null.
  Future<CloudDoc?> fetch(String id);

  /// Every document of the collection, from the server.
  Future<List<CloudDoc>> fetchAll();

  /// The schema-2 documents written at or after [since] (server time),
  /// from the server. Old-format documents (no `serverUpdatedAt`) and
  /// hard-deleted ones are not included: a full [fetchAll] finds those.
  Future<List<CloudDoc>> fetchChangedSince(DateTime since);

  /// Merge-writes [data] (fields not in [data] are kept, e.g. old-format
  /// backups); the server time is added as `serverUpdatedAt`. Throws
  /// [CloudWriteRejected] or [CloudUnavailable].
  Future<void> write(String id, Map<String, dynamic> data);
}
