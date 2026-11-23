import 'package:ae_coaching/core/notifications/legacy_inactivity_reminder_cleanup.dart';
import 'package:ae_coaching/features/notification_settings/data/device_time_zone.dart';
import 'package:ae_coaching/features/notification_settings/data/verified_account.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences_repository.dart';
import 'package:flutter/foundation.dart';

/// Keeps the server preference document in step with this device, without
/// any UI: on each signed-in session start and on app-language changes.
///
/// - Writes only when something differs (language, a valid device time
///   zone), or when the document does not exist yet.
/// - Never changes the on/off choice of an existing document. A missing
///   document adopts the account's choice from the retired on-device
///   reminder (if it was turned off), else the default.
/// - Decides inside a server transaction, never from cached data: offline,
///   a stale cached value (or a stale "does not exist") could otherwise
///   overwrite a newer choice made on another device or on the Settings
///   screen a moment earlier.
/// - Bound to the verified account at start and re-checked before writing.
/// - Best effort: offline or rejected writes are logged and retried at the
///   next session start; nothing is reported to the user.
class NotificationPreferencesSync {
  NotificationPreferencesSync({
    required NotificationPreferencesRepository repository,
    required DeviceTimeZone deviceTimeZone,
    required VerifiedAccount account,
    required LegacyInactivityReminderCleanup legacy,
  }) : _repository = repository,
       _deviceTimeZone = deviceTimeZone,
       _account = account,
       _legacy = legacy;

  final NotificationPreferencesRepository _repository;
  final DeviceTimeZone _deviceTimeZone;
  final VerifiedAccount _account;
  final LegacyInactivityReminderCleanup _legacy;
  Future<void> _queue = Future<void>.value();

  /// Serialized; never throws.
  Future<void> syncCurrentAccount({required String languageCode}) {
    final run = _queue.then((_) => _sync(languageCode));
    _queue = run.catchError((Object error) => debugPrint('Notification preference sync failed: $error'));
    return _queue;
  }

  Future<void> _sync(String languageCode) async {
    final uid = _account.currentUid();
    if (uid == null) return;

    final language = ReminderLanguage.fromLocaleCode(languageCode);
    final deviceTimeZone = await _deviceTimeZone.current();
    final legacyEnabled = _legacy.legacyEnabledFor(uid);
    if (_account.currentUid() != uid) return; // signed out or switched meanwhile
    try {
      await _repository.reconcile(uid, (current) {
        final desired = resolveDesiredPreferences(
          stored: current,
          language: language,
          deviceTimeZone: deviceTimeZone,
          legacyEnabled: legacyEnabled,
        );
        return current.exists && desired == current.preferences ? null : desired;
      });
    } on NotificationPreferencesException catch (error) {
      debugPrint('Notification preference sync skipped: $error'); // next session retries
      return;
    }
    // The server document now exists for this account.
    await _legacy.forgetUser(uid);
  }
}
