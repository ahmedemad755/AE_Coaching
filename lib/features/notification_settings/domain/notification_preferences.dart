/// The user's workout inactivity reminder preferences, exactly as the
/// server reads them from `users/{uid}/settings/notifications`
/// (functions/src/inactivity/domain/reminderPreferences.ts).
library;

/// Reminder language. Mirrors the app language; the server only knows
/// these two.
enum ReminderLanguage {
  ar,
  en;

  static ReminderLanguage? tryParse(Object? value) => switch (value) {
    'ar' => ReminderLanguage.ar,
    'en' => ReminderLanguage.en,
    _ => null,
  };

  /// `en`, `en-US` → [en]; anything else → [ar] (the app's default).
  static ReminderLanguage fromLocaleCode(String languageCode) =>
      languageCode.toLowerCase().split(RegExp('[-_]')).first == 'en'
      ? ReminderLanguage.en
      : ReminderLanguage.ar;
}

/// IANA time-zone names the server and firestore.rules accept.
abstract final class IanaTimeZoneName {
  /// Server default (functions reminderPolicy.ts).
  static const fallback = 'Africa/Cairo';
  static const maxLength = 64;

  /// Same pattern firestore.rules enforces ("Africa/Cairo",
  /// "America/Argentina/Buenos_Aires", "UTC", "Etc/GMT+2").
  static final _pattern = RegExp(r'^[A-Za-z][A-Za-z0-9_+-]*(/[A-Za-z0-9_+-]+){0,2}$');

  static bool isWellFormed(String value) =>
      value.isNotEmpty && value.length <= maxLength && _pattern.hasMatch(value);
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.inactivityRemindersEnabled,
    required this.language,
    required this.timeZone,
  });

  /// What the server assumes when the document is missing.
  static const defaults = NotificationPreferences(
    inactivityRemindersEnabled: true,
    language: ReminderLanguage.ar,
    timeZone: IanaTimeZoneName.fallback,
  );

  final bool inactivityRemindersEnabled;
  final ReminderLanguage language;
  final String timeZone;

  NotificationPreferences copyWith({
    bool? inactivityRemindersEnabled,
    ReminderLanguage? language,
    String? timeZone,
  }) => NotificationPreferences(
    inactivityRemindersEnabled:
        inactivityRemindersEnabled ?? this.inactivityRemindersEnabled,
    language: language ?? this.language,
    timeZone: timeZone ?? this.timeZone,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.inactivityRemindersEnabled == inactivityRemindersEnabled &&
      other.language == language &&
      other.timeZone == timeZone;

  @override
  int get hashCode => Object.hash(inactivityRemindersEnabled, language, timeZone);

  @override
  String toString() =>
      'NotificationPreferences($inactivityRemindersEnabled, ${language.name}, $timeZone)';
}

/// The stored preferences as last observed, with their sync state.
class StoredNotificationPreferences {
  const StoredNotificationPreferences({
    required this.preferences,
    required this.exists,
    this.hasPendingWrites = false,
    this.isFromCache = false,
  });

  /// Stored values, or [NotificationPreferences.defaults] when [exists] is
  /// false.
  final NotificationPreferences preferences;
  final bool exists;

  /// A local change is not yet confirmed by the server (offline).
  final bool hasPendingWrites;

  /// Read from the device cache, not confirmed by the server: it may be
  /// stale (offline), including "does not exist".
  final bool isFromCache;
}

/// The complete document to write. Every write sends all fields, so the
/// app language and a valid device time zone always reach the server.
///
/// - [enabled] (an explicit choice) wins; otherwise the stored value; for
///   a missing document, the legacy on-device choice, else the default.
/// - The time zone is the device's when it is valid, else the stored one,
///   else the server default.
NotificationPreferences resolveDesiredPreferences({
  required StoredNotificationPreferences stored,
  required ReminderLanguage language,
  required String? deviceTimeZone,
  bool? enabled,
  bool? legacyEnabled,
}) {
  final base = stored.preferences;
  final zone = deviceTimeZone != null && IanaTimeZoneName.isWellFormed(deviceTimeZone)
      ? deviceTimeZone
      : (IanaTimeZoneName.isWellFormed(base.timeZone)
            ? base.timeZone
            : IanaTimeZoneName.fallback);
  return NotificationPreferences(
    inactivityRemindersEnabled:
        enabled ??
        (stored.exists
            ? base.inactivityRemindersEnabled
            : (legacyEnabled ?? NotificationPreferences.defaults.inactivityRemindersEnabled)),
    language: language,
    timeZone: zone,
  );
}
