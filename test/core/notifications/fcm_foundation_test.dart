import 'package:ae_coaching/core/notifications/fcm_device_service.dart';
import 'package:ae_coaching/core/notifications/fcm_notification_routing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FCM session ownership', () {
    test('allows token registration only for the matching active session', () {
      expect(
        FcmDeviceService.sessionOwnsAuthenticatedUser(
          authenticatedUid: 'user-a',
          sessionUid: 'user-a',
          isLoggedIn: true,
        ),
        isTrue,
      );
      expect(
        FcmDeviceService.sessionOwnsAuthenticatedUser(
          authenticatedUid: 'user-a',
          sessionUid: 'user-b',
          isLoggedIn: true,
        ),
        isFalse,
      );
      expect(
        FcmDeviceService.sessionOwnsAuthenticatedUser(
          authenticatedUid: 'user-a',
          sessionUid: 'user-a',
          isLoggedIn: false,
        ),
        isFalse,
      );
    });

    test('uses a stable non-raw document id for a device token', () {
      const token = 'sample-fcm-registration-token';
      final id = FcmDeviceService.tokenDocumentId(token);

      expect(id, FcmDeviceService.tokenDocumentId(token));
      expect(id, isNot(token));
      expect(id, hasLength(64));
    });
  });

  group('FCM notification tap routing', () {
    test('routes inactivity reminder taps to Home', () {
      expect(
        FcmNotificationRouting.destinationForData({
          'type': 'inactivity_reminder',
        }),
        FcmNotificationDestination.home,
      );
    });

    test('does not route unrelated notification types', () {
      expect(
        FcmNotificationRouting.destinationForData({'type': 'coach_message'}),
        isNull,
      );
      expect(FcmNotificationRouting.destinationForData(const {}), isNull);
    });
  });
}
