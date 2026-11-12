import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Wire format of `users/{uid}/settings/notifications`. firestore.rules
/// accept exactly these four fields, all present, with `updatedAt` equal
/// to the server time of the write.
abstract final class NotificationPreferencesDocument {
  static const enabledField = 'inactivityRemindersEnabled';
  static const languageField = 'language';
  static const timeZoneField = 'timeZone';
  static const updatedAtField = 'updatedAt';

  /// The complete document. Refuses values the rules would reject, so an
  /// invalid write never leaves the device.
  static Map<String, Object> toFirestore(NotificationPreferences preferences) {
    if (!IanaTimeZoneName.isWellFormed(preferences.timeZone)) {
      throw ArgumentError.value(preferences.timeZone, 'timeZone', 'Not an IANA time-zone name');
    }
    return {
      enabledField: preferences.inactivityRemindersEnabled,
      languageField: preferences.language.name,
      timeZoneField: preferences.timeZone,
      updatedAtField: FieldValue.serverTimestamp(),
    };
  }

  /// Reads stored values the way the server does: a missing or invalid
  /// field falls back to its default; only an explicit `false` disables.
  static NotificationPreferences fromFirestore(Map<String, dynamic>? data) {
    const defaults = NotificationPreferences.defaults;
    if (data == null) return defaults;
    final enabled = data[enabledField];
    final timeZone = data[timeZoneField];
    return NotificationPreferences(
      inactivityRemindersEnabled: enabled is bool ? enabled : defaults.inactivityRemindersEnabled,
      language: ReminderLanguage.tryParse(data[languageField]) ?? defaults.language,
      timeZone: timeZone is String && IanaTimeZoneName.isWellFormed(timeZone)
          ? timeZone
          : defaults.timeZone,
    );
  }
}
