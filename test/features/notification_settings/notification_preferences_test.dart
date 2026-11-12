import 'package:ae_coaching/features/notification_settings/data/notification_preferences_document.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_settings_fakes.dart';

const _stored = NotificationPreferences(
  inactivityRemindersEnabled: false,
  language: ReminderLanguage.ar,
  timeZone: 'Asia/Riyadh',
);

void main() {
  group('ReminderLanguage', () {
    test('parses only the two server languages', () {
      expect(ReminderLanguage.tryParse('ar'), ReminderLanguage.ar);
      expect(ReminderLanguage.tryParse('en'), ReminderLanguage.en);
      for (final bad in ['fr', 'AR', '', null, 1]) {
        expect(ReminderLanguage.tryParse(bad), isNull);
      }
    });

    test('follows the app locale code', () {
      expect(ReminderLanguage.fromLocaleCode('en'), ReminderLanguage.en);
      expect(ReminderLanguage.fromLocaleCode('en-US'), ReminderLanguage.en);
      expect(ReminderLanguage.fromLocaleCode('en_GB'), ReminderLanguage.en);
      expect(ReminderLanguage.fromLocaleCode('ar'), ReminderLanguage.ar);
      expect(ReminderLanguage.fromLocaleCode('de'), ReminderLanguage.ar);
    });
  });

  group('IANA time-zone names (same pattern as firestore.rules)', () {
    test('accepts IANA names', () {
      for (final zone in [
        'Africa/Cairo',
        'America/Argentina/Buenos_Aires',
        'America/Port-au-Prince',
        'UTC',
        'Etc/GMT+2',
        'Etc/GMT-14',
      ]) {
        expect(IanaTimeZoneName.isWellFormed(zone), isTrue, reason: zone);
      }
    });

    test('rejects raw offsets, paths and oversized names', () {
      for (final zone in [
        '',
        'GMT+03:00',
        'Africa Cairo',
        '../../etc',
        '/Africa/Cairo',
        'A/B/C/D',
        'Zone/${'x' * 60}',
      ]) {
        expect(IanaTimeZoneName.isWellFormed(zone), isFalse, reason: zone);
      }
    });
  });

  group('resolveDesiredPreferences', () {
    StoredNotificationPreferences stored({bool exists = true, NotificationPreferences value = _stored}) =>
        StoredNotificationPreferences(preferences: exists ? value : NotificationPreferences.defaults, exists: exists);

    test('an existing choice is kept; language and a valid device zone are refreshed', () {
      expect(
        resolveDesiredPreferences(stored: stored(), language: ReminderLanguage.en, deviceTimeZone: 'Europe/Paris'),
        const NotificationPreferences(
          inactivityRemindersEnabled: false,
          language: ReminderLanguage.en,
          timeZone: 'Europe/Paris',
        ),
      );
    });

    test('an explicit choice wins over everything', () {
      final desired = resolveDesiredPreferences(
        stored: stored(),
        language: ReminderLanguage.ar,
        deviceTimeZone: null,
        enabled: true,
        legacyEnabled: false,
      );
      expect(desired.inactivityRemindersEnabled, isTrue);
    });

    test('a missing document adopts the retired on-device choice, else the default', () {
      expect(
        resolveDesiredPreferences(
          stored: stored(exists: false),
          language: ReminderLanguage.ar,
          deviceTimeZone: 'Africa/Cairo',
          legacyEnabled: false,
        ).inactivityRemindersEnabled,
        isFalse,
      );
      expect(
        resolveDesiredPreferences(
          stored: stored(exists: false),
          language: ReminderLanguage.ar,
          deviceTimeZone: 'Africa/Cairo',
        ).inactivityRemindersEnabled,
        isTrue,
      );
    });

    test('an unusable device zone keeps the stored zone, then the server default', () {
      expect(
        resolveDesiredPreferences(stored: stored(), language: ReminderLanguage.ar, deviceTimeZone: 'GMT+03:00').timeZone,
        'Asia/Riyadh',
      );
      expect(
        resolveDesiredPreferences(stored: stored(exists: false), language: ReminderLanguage.ar, deviceTimeZone: null)
            .timeZone,
        'Africa/Cairo',
      );
    });
  });

  group('Firestore document', () {
    test('writes exactly the four approved fields with a server timestamp', () {
      final data = NotificationPreferencesDocument.toFirestore(_stored);
      expect(data.keys.toSet(), {'inactivityRemindersEnabled', 'language', 'timeZone', 'updatedAt'});
      expect(data['inactivityRemindersEnabled'], false);
      expect(data['language'], 'ar');
      expect(data['timeZone'], 'Asia/Riyadh');
      expect(data['updatedAt'], isA<FieldValue>()); // FieldValue.serverTimestamp()
    });

    test('never builds a document the rules would reject', () {
      expect(
        () => NotificationPreferencesDocument.toFirestore(_stored.copyWith(timeZone: 'GMT+03:00')),
        throwsArgumentError,
      );
    });

    test('reads stored values the way the server does', () {
      expect(
        NotificationPreferencesDocument.fromFirestore({
          'inactivityRemindersEnabled': false,
          'language': 'en',
          'timeZone': 'Europe/London',
        }),
        const NotificationPreferences(
          inactivityRemindersEnabled: false,
          language: ReminderLanguage.en,
          timeZone: 'Europe/London',
        ),
      );
      // Only an explicit boolean false disables; invalid values fall back.
      expect(
        NotificationPreferencesDocument.fromFirestore({
          'inactivityRemindersEnabled': 'false',
          'language': 'fr',
          'timeZone': 'GMT+03:00',
        }),
        NotificationPreferences.defaults,
      );
      expect(
        NotificationPreferencesDocument.fromFirestore({'timeZone': 'Mars Base'}),
        NotificationPreferences.defaults,
      );
      expect(NotificationPreferencesDocument.fromFirestore(null), NotificationPreferences.defaults);
    });
  });

  group('DeviceTimeZone', () {
    test('returns IANA names known to the time-zone database', () async {
      for (final zone in ['Africa/Cairo', 'America/Argentina/Buenos_Aires', 'Asia/Riyadh', 'UTC']) {
        expect(await fakeDeviceTimeZone(zone).current(), zone);
      }
      expect(await fakeDeviceTimeZone(' Europe/Paris ').current(), 'Europe/Paris');
    });

    test('returns null for anything the server could not use', () async {
      for (final zone in ['GMT+03:00', 'Mars/Olympus_Mons', '', 'Local']) {
        expect(await fakeDeviceTimeZone(zone).current(), isNull, reason: zone);
      }
      expect(await fakeDeviceTimeZone(null).current(), isNull); // platform failure
    });
  });
}
