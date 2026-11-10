import 'dart:io';

import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// UNIT TIER — SessionStorage is deliberately given a real Hive [Box]
/// through its constructor (not `Hive.box('authBox')` internally), so
/// it can be tested against a real, disposable Hive instance without
/// requiring the production authBox or any Firebase setup. Mirrors the
/// existing `Hive.init(tempDir)` pattern already used by the workout
/// repository tests in this suite.
void main() {
  late Directory tempDir;
  late Box box;
  late SessionStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('session_storage_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox('authBox');
    storage = SessionStorage(box);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  group('A: persistLoggedInSession writes exactly the canonical session '
      'state', () {
    test('writes isLoggedIn=true and all 3 identity fields', () async {
      await storage.persistLoggedInSession(
        uid: 'uid-1',
        name: 'Ahmed',
        email: 'ahmed@example.com',
      );

      expect(box.get('isLoggedIn'), isTrue);
      expect(box.get('currentUserUid'), 'uid-1');
      expect(box.get('currentUserName'), 'Ahmed');
      expect(box.get('currentUserEmail'), 'ahmed@example.com');
    });

    test('read accessors reflect exactly what was written', () async {
      await storage.persistLoggedInSession(
        uid: 'uid-2',
        name: 'Sara',
        email: 'sara@example.com',
      );

      expect(storage.isLoggedIn, isTrue);
      expect(storage.currentUserUid, 'uid-2');
      expect(storage.currentUserName, 'Sara');
      expect(storage.currentUserEmail, 'sara@example.com');
    });

    test('defaults match the exact values every existing call site '
        'relied on before any session is ever persisted', () {
      expect(storage.isLoggedIn, isFalse);
      expect(storage.currentUserUid, '');
      expect(storage.currentUserName, '');
    });
  });

  group('B: clearSession resets/removes exactly the intended '
      'auth-session state', () {
    test('sets isLoggedIn to false (kept as an explicit key, not '
        'deleted) and deletes the identity keys, including a phone-era '
        "phone key — matches hom.dart's _logout() exactly", () async {
      await box.put('currentUserPhone', '+201055556666');
      await storage.persistLoggedInSession(
        uid: 'uid-3',
        name: 'Omar',
        email: 'omar@example.com',
      );

      await storage.clearSession();

      expect(box.containsKey('isLoggedIn'), isTrue);
      expect(box.get('isLoggedIn'), isFalse);
      expect(box.containsKey('currentUserUid'), isFalse);
      expect(box.containsKey('currentUserName'), isFalse);
      expect(box.containsKey('currentUserEmail'), isFalse);
      expect(box.containsKey('currentUserPhone'), isFalse);
    });

    test('the read accessors report the logged-out defaults after '
        'clearSession', () async {
      await storage.persistLoggedInSession(
        uid: 'uid-4',
        name: 'Laila',
        email: 'laila@example.com',
      );
      await storage.clearSession();

      expect(storage.isLoggedIn, isFalse);
      expect(storage.currentUserUid, '');
      expect(storage.currentUserName, '');
    });
  });

  group('markLoggedOut (hom.dart _initUserBox empty-uid branch)', () {
    test('sets isLoggedIn to false WITHOUT deleting the identity keys '
        '— narrower than clearSession, matching the exact original '
        'call site behavior', () async {
      await storage.persistLoggedInSession(
        uid: 'uid-5',
        name: 'Nour',
        email: 'nour@example.com',
      );

      await storage.markLoggedOut();

      expect(box.get('isLoggedIn'), isFalse);
      // Unlike clearSession, the identity keys are left untouched.
      expect(box.get('currentUserUid'), 'uid-5');
      expect(box.get('currentUserName'), 'Nour');
      expect(box.get('currentUserEmail'), 'nour@example.com');
    });
  });

  group('updateCurrentUserUid (hom.dart/_getWorkoutBox partial sync '
      'write)', () {
    test('writes only currentUserUid, leaving every other key '
        'untouched', () async {
      await storage.persistLoggedInSession(
        uid: 'old-uid',
        name: 'Kept Name',
        email: 'kept@example.com',
      );

      await storage.updateCurrentUserUid('new-uid');

      expect(box.get('currentUserUid'), 'new-uid');
      expect(box.get('currentUserName'), 'Kept Name');
      expect(box.get('isLoggedIn'), isTrue);
    });
  });

  group('Stage 3B: email-first sessions', () {
    test('an email session stores the email and no phone', () async {
      await storage.persistLoggedInSession(
        uid: 'uid-1',
        name: 'Ahmed',
        email: 'ahmed@example.com',
      );
      expect(storage.currentUserEmail, 'ahmed@example.com');
      expect(box.containsKey('currentUserPhone'), isFalse);
    });

    test('switching from a phone-era session to an email account never '
        "carries the previous user's phone or identity over", () async {
      // What a phone-era build left on an upgraded device.
      await box.put('isLoggedIn', true);
      await box.put('currentUserUid', 'legacy');
      await box.put('currentUserName', 'Old');
      await box.put('currentUserPhone', '+201012345678');
      await storage.persistLoggedInSession(
        uid: 'uid-2',
        name: 'New',
        email: 'new@example.com',
      );
      expect(storage.currentUserUid, 'uid-2');
      expect(storage.currentUserName, 'New');
      expect(box.containsKey('currentUserPhone'), isFalse);
    });

    test('clearSession removes the email too', () async {
      await storage.persistLoggedInSession(
        uid: 'uid-1',
        name: 'Ahmed',
        email: 'ahmed@example.com',
      );
      await storage.clearSession();
      expect(storage.isLoggedIn, isFalse);
      expect(box.containsKey('currentUserEmail'), isFalse);
      expect(storage.currentUserEmail, '');
    });

    test('nothing credential-like is ever written', () async {
      await storage.persistLoggedInSession(
        uid: 'uid-1',
        name: 'Ahmed',
        email: 'ahmed@example.com',
      );
      expect(box.keys.toSet(), {
        'isLoggedIn',
        'currentUserUid',
        'currentUserName',
        'currentUserEmail',
      });
    });
  });

  test('profile name update changes only the current saved name', () async {
    await storage.persistLoggedInSession(
      uid: 'profile-user',
      name: 'Before',
      email: 'profile@example.com',
    );
    await storage.updateCurrentUserName(uid: 'profile-user', name: 'After');

    expect(storage.currentUserName, 'After');
    expect(storage.currentUserUid, 'profile-user');
    expect(storage.currentUserEmail, 'profile@example.com');
    expect(storage.isLoggedIn, isTrue);

    await expectLater(
      storage.updateCurrentUserName(uid: 'another-user', name: 'Wrong'),
      throwsA(isA<StateError>()),
    );
    expect(storage.currentUserName, 'After');
  });
}
