import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The device's IANA time zone, validated against the IANA database
/// bundled with `package:timezone` (the same names the server's Intl
/// runtime knows). Returns `null` when the platform reports nothing usable
/// (e.g. a raw offset such as "GMT+03:00"), so callers keep the stored or
/// default zone instead of sending something the server would reject.
class DeviceTimeZone {
  DeviceTimeZone({Future<String> Function()? readPlatformZone, bool Function(String name)? isKnownZone})
    : _readPlatformZone = readPlatformZone ?? _platformZone,
      _isKnownZone = isKnownZone ?? _inIanaDatabase;

  final Future<String> Function() _readPlatformZone;
  final bool Function(String name) _isKnownZone;

  Future<String?> current() async {
    final String name;
    try {
      name = (await _readPlatformZone()).trim();
    } catch (_) {
      return null;
    }
    return IanaTimeZoneName.isWellFormed(name) && _isKnownZone(name) ? name : null;
  }

  static Future<String> _platformZone() async => (await FlutterTimezone.getLocalTimezone()).identifier;

  /// The device's zone as a `package:timezone` location, for scheduling;
  /// the app's default zone when the platform reports nothing usable.
  Future<tz.Location> currentLocation() async {
    ensureDatabaseLoaded();
    return tz.getLocation(await current() ?? IanaTimeZoneName.fallback);
  }

  static bool _databaseLoaded = false;

  /// Loads the bundled IANA database once.
  static void ensureDatabaseLoaded() {
    if (_databaseLoaded) return;
    tz_data.initializeTimeZones();
    _databaseLoaded = true;
  }

  static bool _inIanaDatabase(String name) {
    ensureDatabaseLoaded();
    return tz.timeZoneDatabase.locations.containsKey(name);
  }
}
