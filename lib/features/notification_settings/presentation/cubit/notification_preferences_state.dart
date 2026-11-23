part of 'notification_preferences_cubit.dart';

enum NotificationPreferencesStatus {
  loading,

  /// The stored (or, for a new account, default) preference is known.
  ready,

  /// Offline and nothing confirmed for this account yet.
  offline,

  /// No verified account: preferences cannot be read or written.
  unavailable,
  failure,
}

/// What [NotificationPreferencesCubit.setEnabled] achieved. Only
/// [confirmed] may be reported as saved.
enum PreferenceSaveOutcome {
  confirmed,

  /// Stored on this device, waiting to reach the server.
  pendingSync,

  /// Refused by the server (security rules).
  rejected,
  failed,

  /// Another account is signed in now; nothing was written.
  accountChanged,

  /// A save is already running.
  busy,
}

class NotificationPreferencesState {
  const NotificationPreferencesState._({
    required this.status,
    this.stored,
    this.failure,
    this.saving = false,
  });

  const NotificationPreferencesState.loading() : this._(status: NotificationPreferencesStatus.loading);

  const NotificationPreferencesState.ready(StoredNotificationPreferences stored, {bool saving = false})
    : this._(status: NotificationPreferencesStatus.ready, stored: stored, saving: saving);

  const NotificationPreferencesState.offline({bool saving = false})
    : this._(status: NotificationPreferencesStatus.offline, saving: saving);

  const NotificationPreferencesState.unavailable() : this._(status: NotificationPreferencesStatus.unavailable);

  const NotificationPreferencesState.failure(NotificationPreferencesFailure failure)
    : this._(status: NotificationPreferencesStatus.failure, failure: failure);

  final NotificationPreferencesStatus status;
  final StoredNotificationPreferences? stored;
  final NotificationPreferencesFailure? failure;
  final bool saving;

  bool get enabled => stored?.preferences.inactivityRemindersEnabled ?? true;

  /// A change made on this device has not reached the server yet.
  bool get pendingSync => stored?.hasPendingWrites ?? false;

  bool get canToggle => status == NotificationPreferencesStatus.ready && !saving;

  NotificationPreferencesState copyWith({bool? saving}) =>
      NotificationPreferencesState._(status: status, stored: stored, failure: failure, saving: saving ?? this.saving);
}
