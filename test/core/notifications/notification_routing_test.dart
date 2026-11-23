import 'dart:io';

import 'package:ae_coaching/core/bootstrap/startup_destination.dart';
import 'package:ae_coaching/core/notifications/fcm_device_service.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _NoFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoMessaging implements FirebaseMessaging {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PushCounter extends NavigatorObserver {
  final List<String?> pushed = [];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route.settings.name);
}

void main() {
  late Directory directory;
  late Box box;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('notification_routing_test_');
    Hive.init(directory.path);
    box = await Hive.openBox('authBox');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<_PushCounter> pumpApp(WidgetTester tester) async {
    final observer = _PushCounter();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppRouter.navigatorKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('Signed in screen')),
        routes: {AppNavigator.home: (_) => const Scaffold(body: Text('Home destination'))},
      ),
    );
    observer.pushed.clear();
    return observer;
  }

  FcmDeviceService service() =>
      FcmDeviceService(auth: MockFirebaseAuth(), firestore: _NoFirestore(), messaging: _NoMessaging(), localBox: box);

  testWidgets('an inactivity reminder tap opens Home once, even if delivered twice', (tester) async {
    final observer = await pumpApp(tester);
    final fcm = service();
    const message = RemoteMessage(messageId: 'm-1', data: {'type': 'inactivity_reminder'});

    fcm.handleNotificationTapForTesting(message); // getInitialMessage
    fcm.handleNotificationTapForTesting(message); // onMessageOpenedApp, same tap
    await tester.pumpAndSettle();
    expect(observer.pushed, [AppNavigator.home]);
    expect(find.text('Home destination'), findsOneWidget);

    fcm.handleNotificationTapForTesting(
      const RemoteMessage(messageId: 'm-2', data: {'type': 'inactivity_reminder'}),
    );
    await tester.pumpAndSettle();
    expect(observer.pushed, [AppNavigator.home, AppNavigator.home]); // a new reminder
  });

  testWidgets('other notification types are not routed', (tester) async {
    final observer = await pumpApp(tester);
    service().handleNotificationTapForTesting(const RemoteMessage(messageId: 'x', data: {'type': 'promo'}));
    service().handleNotificationTapForTesting(const RemoteMessage(messageId: 'y'));
    await tester.pumpAndSettle();
    expect(observer.pushed, isEmpty);
  });

  testWidgets('a tap before the navigator exists is replayed once it is ready', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink()); // no navigator yet (cold start)
    service().handleNotificationTapForTesting(
      const RemoteMessage(messageId: 'cold', data: {'type': 'inactivity_reminder'}),
    );
    await pumpApp(tester);
    AppRouter.flushPendingNotificationNavigation(); // what MyApp.builder does
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
  });

  group('account isolation of the Home route', () {
    // The notification carries no account data; Home itself is guarded.
    const signedOut = StartupAuthSnapshot(firebaseUid: null);
    const unverified = StartupAuthSnapshot(firebaseUid: 'u', firebaseEmail: 'a@b.co');
    const verified = StartupAuthSnapshot(firebaseUid: 'u', firebaseEmail: 'a@b.co', firebaseEmailVerified: true);

    test('signed out or unverified: the tap lands on the startup check, not Home', () {
      expect(AppRouter.guardedRouteName(AppNavigator.home, signedOut), AppNavigator.initial);
      expect(AppRouter.guardedRouteName(AppNavigator.home, unverified), AppNavigator.initial);
    });

    test('the currently signed-in verified account opens its own Home', () {
      expect(AppRouter.guardedRouteName(AppNavigator.home, verified), AppNavigator.home);
      expect(hasVerifiedEmailIdentity(verified), isTrue);
      expect(hasVerifiedEmailIdentity(unverified), isFalse);
      expect(FcmDeviceService.isEligibleForTokenRegistration(verified), isTrue);
      expect(FcmDeviceService.isEligibleForTokenRegistration(unverified), isFalse);
    });
  });
}
