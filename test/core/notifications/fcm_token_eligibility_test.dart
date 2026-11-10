// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:io';

import 'package:ae_coaching/core/bootstrap/startup_destination.dart';
import 'package:ae_coaching/core/notifications/fcm_device_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

// ── Test doubles ────────────────────────────────────────────────────────────

class _PasswordProvider implements UserInfo {
  @override
  String get providerId => 'password';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MockUser _user({
  required String uid,
  required String email,
  required bool verified,
}) => MockUser(
  uid: uid,
  email: email,
  isEmailVerified: verified,
  providerData: [_PasswordProvider()],
);

NotificationSettings _settings(AuthorizationStatus status) =>
    NotificationSettings(
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.disabled,
      authorizationStatus: status,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.disabled,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      timeSensitive: AppleNotificationSetting.disabled,
      criticalAlert: AppleNotificationSetting.disabled,
      sound: AppleNotificationSetting.enabled,
      providesAppNotificationSettings: AppleNotificationSetting.disabled,
    );

class _FakeMessaging implements FirebaseMessaging {
  int permissionRequests = 0;
  int tokenReads = 0;
  String token = 'device-token-1';

  @override
  Future<NotificationSettings> getNotificationSettings() async =>
      _settings(AuthorizationStatus.authorized);

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    permissionRequests++;
    return _settings(AuthorizationStatus.authorized);
  }

  @override
  Future<String?> getToken({
    String? serviceWorkerScriptPath,
    String? vapidKey,
  }) async {
    tokenReads++;
    return token;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records every token write the service sends to Firestore.
class _Writes {
  final sets = <String, Map<String, Object?>>{};
  final deletes = <String>[];
  int commits = 0;
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.exists);
  @override
  final bool exists;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Doc implements DocumentReference<Map<String, dynamic>> {
  _Doc(this.path, this.writes);
  @override
  final String path;
  final _Writes writes;

  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      _Collection('$path/$name', writes);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(writes.sets.containsKey(path));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.path, this.writes);
  @override
  final String path;
  final _Writes writes;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Doc('$path/$id', writes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Batch implements WriteBatch {
  _Batch(this.writes);
  final _Writes writes;
  final _pendingSets = <String, Map<String, Object?>>{};
  final _pendingDeletes = <String>[];

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    _pendingSets[document.path] = Map<String, Object?>.from(data as Map);
  }

  @override
  void delete(DocumentReference document) => _pendingDeletes.add(document.path);

  @override
  Future<void> commit() async {
    writes.sets.addAll(_pendingSets);
    writes.deletes.addAll(_pendingDeletes);
    writes.commits++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestore implements FirebaseFirestore {
  final writes = _Writes();

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(path, writes);

  @override
  WriteBatch batch() => _Batch(writes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('isEligibleForTokenRegistration (pure policy)', () {
    StartupAuthSnapshot s({
      String? uid = 'uid-1',
      String email = 'user@example.com',
      bool verified = true,
      bool password = true,
    }) => StartupAuthSnapshot(
      firebaseUid: uid,
      firebaseEmail: email,
      firebaseEmailVerified: verified,
      firebaseUsesPassword: password,
    );

    test('a signed-in, email-verified user is eligible', () {
      expect(FcmDeviceService.isEligibleForTokenRegistration(s()), isTrue);
    });

    test('no identity is never eligible', () {
      expect(
        FcmDeviceService.isEligibleForTokenRegistration(s(uid: null)),
        isFalse,
      );
      expect(
        FcmDeviceService.isEligibleForTokenRegistration(s(uid: '  ')),
        isFalse,
      );
    });

    test('an unverified email is never eligible', () {
      expect(
        FcmDeviceService.isEligibleForTokenRegistration(s(verified: false)),
        isFalse,
      );
    });

    test('an unverified non-password identity is still not eligible '
        '(stricter than the route guard)', () {
      final snapshot = s(verified: false, password: false);
      expect(canEnterProtectedRoute(snapshot), isTrue);
      expect(
        FcmDeviceService.isEligibleForTokenRegistration(snapshot),
        isFalse,
      );
    });

    test('a phone-era (synthetic email) account is never eligible, even '
        'when flagged verified', () {
      expect(
        FcmDeviceService.isEligibleForTokenRegistration(
          s(email: '201012345678@ae-coaching.app'),
        ),
        isFalse,
      );
    });
  });

  group('FcmDeviceService token registration', () {
    late Directory dir;
    late Box box;
    late _FakeMessaging messaging;
    late _FakeFirestore firestore;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fcm_eligibility_');
      Hive.init(dir.path);
      box = await Hive.openBox('fcm_eligibility_auth');
      messaging = _FakeMessaging();
      firestore = _FakeFirestore();
    });

    tearDown(() async {
      await box.deleteFromDisk();
      await Hive.close();
      await dir.delete(recursive: true);
    });

    Future<FcmDeviceService> serviceFor(MockUser user) async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: user);
      // The local session marker the app writes on entry (enterApp).
      await box.put('isLoggedIn', true);
      await box.put('currentUserUid', user.uid);
      return FcmDeviceService(
        auth: auth,
        firestore: firestore,
        messaging: messaging,
        localBox: box,
      );
    }

    String tokenPath(String uid, String token) =>
        'users/$uid/fcmTokens/${FcmDeviceService.tokenDocumentId(token)}';

    test(
      'a verified user registers exactly one owned token document',
      () async {
        final service = await serviceFor(
          _user(uid: 'alice', email: 'alice@example.com', verified: true),
        );

        await service.syncTokenForTesting();

        expect(firestore.writes.commits, 1);
        final doc = firestore.writes.sets[tokenPath('alice', 'device-token-1')];
        expect(doc, isNotNull);
        expect(doc!.keys.toSet(), {
          'token',
          'updatedAt',
          'platform',
          'createdAt',
        });
        expect(doc['token'], 'device-token-1');
        expect(doc['updatedAt'], isA<FieldValue>());
        expect(doc['createdAt'], isA<FieldValue>());
        expect(box.get('fcmTokenOwnerUid'), 'alice');
      },
    );

    test('an unverified user registers nothing and is never prompted for '
        'notification permission', () async {
      final service = await serviceFor(
        _user(uid: 'bob', email: 'bob@example.com', verified: false),
      );

      await service.syncTokenForTesting();

      expect(firestore.writes.commits, 0);
      expect(firestore.writes.sets, isEmpty);
      expect(messaging.permissionRequests, 0);
      expect(messaging.tokenReads, 0);
      expect(box.get('fcmTokenOwnerUid'), isNull);
    });

    test('a phone-era account with a stale local session marker registers '
        'nothing', () async {
      final service = await serviceFor(
        _user(
          uid: 'legacy',
          email: '201012345678@ae-coaching.app',
          verified: true,
        ),
      );

      await service.syncTokenForTesting();

      expect(firestore.writes.commits, 0);
      expect(messaging.tokenReads, 0);
    });

    test('a verified user without a matching local session registers '
        'nothing', () async {
      final service = await serviceFor(
        _user(uid: 'carol', email: 'carol@example.com', verified: true),
      );
      await box.put('currentUserUid', 'someone-else');

      await service.syncTokenForTesting();

      expect(firestore.writes.commits, 0);
    });

    test('repeated triggers do not rewrite the same token', () async {
      final service = await serviceFor(
        _user(uid: 'alice', email: 'alice@example.com', verified: true),
      );

      await service.syncTokenForTesting();
      await service.syncTokenForTesting();
      await service.syncTokenForTesting();

      expect(firestore.writes.commits, 1);
    });

    test(
      'a rotated token replaces the previous document (token refresh)',
      () async {
        final service = await serviceFor(
          _user(uid: 'alice', email: 'alice@example.com', verified: true),
        );
        await service.syncTokenForTesting();

        messaging.token = 'device-token-2';
        await service.syncTokenForTesting();

        expect(firestore.writes.commits, 2);
        expect(
          firestore.writes.sets.containsKey(
            tokenPath('alice', 'device-token-2'),
          ),
          isTrue,
        );
        expect(firestore.writes.deletes, [
          tokenPath('alice', 'device-token-1'),
        ]);
      },
    );
  });
}
