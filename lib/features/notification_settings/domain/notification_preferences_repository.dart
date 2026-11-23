import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';

/// Outcome of a write the caller may report to the user.
enum PreferenceSaveResult {
  /// The server accepted it.
  confirmed,

  /// Stored on this device and queued; the server has not confirmed it
  /// yet (offline or slow). It may still be rejected later, in which case
  /// the stored value reverts.
  pendingSync,
}

enum NotificationPreferencesFailure {
  /// Rules rejected it (not the verified owner, or invalid document).
  permissionDenied,

  /// No connection and nothing cached.
  unavailable,
  unknown,
}

class NotificationPreferencesException implements Exception {
  const NotificationPreferencesException(this.failure);

  final NotificationPreferencesFailure failure;

  @override
  String toString() => 'NotificationPreferencesException(${failure.name})';
}

/// `users/{uid}/settings/notifications`. Every method is scoped to one
/// account; callers pass the uid they verified.
abstract interface class NotificationPreferencesRepository {
  /// Current value and sync state, then every change (including local,
  /// not-yet-confirmed writes). Errors are [NotificationPreferencesException].
  Stream<StoredNotificationPreferences> watch(String uid);

  /// Atomically reads the SERVER value and writes [decide]'s result when it
  /// is not null (a transaction: retried on concurrent changes, fails
  /// offline instead of acting on cached data). True if it wrote.
  Future<bool> reconcile(
    String uid,
    NotificationPreferences? Function(StoredNotificationPreferences current) decide,
  );

  /// Writes the complete document. Throws [NotificationPreferencesException]
  /// when the write is rejected; never reports a success it has not seen.
  Future<PreferenceSaveResult> save(String uid, NotificationPreferences preferences);
}
