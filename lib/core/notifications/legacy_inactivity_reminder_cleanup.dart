import 'package:ae_coaching/core/notifications/local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Retires the on-device 3-day inactivity reminder (replaced by
/// server-sent reminders).
///
/// Existing installations may still have:
/// - one scheduled local notification, id [legacyNotificationId];
/// - its bookkeeping keys in `authBox`;
/// - a per-account on/off choice (`inactivityRemindersEnabled:<uid>`).
///
/// [run] cancels only that notification id and deletes only the scheduling
/// keys, then records [retiredMarkerKey]. It is idempotent: if anything
/// fails, the marker is not written and it runs again next launch. The
/// on/off choice is kept until it has been carried over to the server
/// preference ([legacyEnabledFor] / [forgetUser]).
class LegacyInactivityReminderCleanup {
  LegacyInactivityReminderCleanup({required LocalNotificationsGateway notifications, Box? box})
    : _notifications = notifications,
      _box = box;

  static const legacyNotificationId = 7301;
  static const retiredMarkerKey = 'legacyInactivityReminderRetiredV1';
  static const _ownerKey = 'localInactivityNotificationUid';
  static const _enabledPrefix = 'inactivityRemindersEnabled:';
  static const _schedulingPrefixes = [
    'inactivityLanguage:',
    'inactivityLastCompletedAt:',
    'inactivityCycleId:',
    'inactivityScheduledCycleId:',
  ];

  final LocalNotificationsGateway _notifications;
  final Box? _box;
  Box get _store => _box ?? Hive.box('authBox');

  bool get isRetired => _store.get(retiredMarkerKey) == true;

  Future<void> run() async {
    if (isRetired) return;
    await _notifications.cancel(legacyNotificationId);
    final legacyKeys = _store.keys.whereType<String>().where(
      (key) => key == _ownerKey || _schedulingPrefixes.any(key.startsWith),
    );
    await _store.deleteAll(legacyKeys.toList());
    await _store.put(retiredMarkerKey, true);
  }

  /// The account's on-device choice from the retired feature, if any.
  bool? legacyEnabledFor(String uid) {
    final value = _store.get('$_enabledPrefix$uid');
    return value is bool ? value : null;
  }

  /// Drops the carried-over choice once the server preference exists.
  Future<void> forgetUser(String uid) => _store.delete('$_enabledPrefix$uid');
}
