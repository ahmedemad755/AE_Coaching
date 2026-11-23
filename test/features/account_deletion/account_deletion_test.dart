import 'dart:async';
import 'dart:io';

import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/account_deletion/application/account_deletion_lifecycle.dart';
import 'package:ae_coaching/features/account_deletion/application/local_account_data_wiper.dart';
import 'package:ae_coaching/features/account_deletion/domain/account_deletion.dart';
import 'package:ae_coaching/features/account_deletion/presentation/cubit/account_deletion_cubit.dart';
import 'package:ae_coaching/features/profile/data/local_profile_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'account_deletion_fakes.dart';

void main() {
  late Directory directory;
  late Box box;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('account_deletion_test_');
    Hive.init('${directory.path}/hive');
    box = await Hive.openBox('authBox');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  group('LocalAccountDataWiper (device data of ONE account)', () {
    late Directory documents;
    late UserStorageManager storage;
    late LocalAccountDataWiper wiper;
    late List<String> hookCalls;

    Future<void> seedAccount(String uid) async {
      for (final prefix in UserStorageManager.supportedBoxes.keys) {
        final userBox = await Hive.openBox(UserStorageManager.boxNameFor(prefix, uid));
        await userBox.put('k', 'v');
        await userBox.close();
      }
      await File('${documents.path}/progress_photos/${uid}_1.jpg').create(recursive: true);
      await box.putAll({'themeMode.$uid': 'dark', 'inactivityRemindersEnabled:$uid': false});
    }

    setUp(() async {
      documents = await Directory('${directory.path}/docs').create();
      storage = UserStorageManager();
      hookCalls = [];
      wiper = LocalAccountDataWiper(
        storage: storage,
        profilePhotos: LocalProfilePhotoStore(box, documentsDirectory: () async => documents),
        authBox: box,
        session: SessionStorage(box),
        documentsDirectory: () async => documents,
        accountHooks: [
          (uid) async => hookCalls.add('reminders:$uid'),
          (uid) async => hookCalls.add('fcm:$uid'),
        ],
      );
      await seedAccount('alice');
      await seedAccount('bob');
    });

    test('removes only that account: boxes, photos, preferences, its session', () async {
      await SessionStorage(box).persistLoggedInSession(uid: 'alice', name: 'A', email: 'a@x.co');
      await wiper.wipe('alice');

      for (final prefix in UserStorageManager.supportedBoxes.keys) {
        expect(await Hive.boxExists(UserStorageManager.boxNameFor(prefix, 'alice')), isFalse, reason: prefix);
        expect(await Hive.boxExists(UserStorageManager.boxNameFor(prefix, 'bob')), isTrue, reason: prefix);
      }
      expect(File('${documents.path}/progress_photos/alice_1.jpg').existsSync(), isFalse);
      expect(File('${documents.path}/progress_photos/bob_1.jpg').existsSync(), isTrue);
      expect(box.containsKey('themeMode.alice'), isFalse);
      expect(box.get('themeMode.bob'), 'dark');
      expect(SessionStorage(box).currentUserUid, '');
      expect(hookCalls, ['reminders:alice', 'fcm:alice']);
      expect(box.get(LocalAccountDataWiper.clearFirestoreCacheKey), isTrue);
      await wiper.wipe('alice'); // idempotent
    });

    test("another account's session is never cleared", () async {
      await SessionStorage(box).persistLoggedInSession(uid: 'bob', name: 'B', email: 'b@x.co');
      await wiper.wipe('alice');
      expect(SessionStorage(box).currentUserUid, 'bob');
    });

    test('a failing step does not stop the others, and is reported', () async {
      final failing = LocalAccountDataWiper(
        storage: storage,
        profilePhotos: LocalProfilePhotoStore(box, documentsDirectory: () async => documents),
        authBox: box,
        session: SessionStorage(box),
        documentsDirectory: () async => documents,
        accountHooks: [(_) async => throw StateError('plugin unavailable')],
      );
      await expectLater(failing.wipe('alice'), throwsStateError);
      expect(await Hive.boxExists(UserStorageManager.boxNameFor('sets', 'alice')), isFalse);
    });
  });

  group('AccountDeletionLifecycle (across app restarts)', () {
    late FakeAccountDeletionRepository repository;
    late RecordingWiper wiper;
    late List<String> events;
    String? signedIn;

    AccountDeletionLifecycle lifecycle() => AccountDeletionLifecycle(
      authBox: box,
      repository: repository,
      wiper: wiper,
      currentUid: () => signedIn,
      signOut: () async => events.add('signOut'),
      clearFirestoreCache: () async => events.add('clearCache'),
    );

    setUp(() {
      repository = FakeAccountDeletionRepository();
      wiper = RecordingWiper(box);
      events = [];
      signedIn = 'alice';
    });

    test('no deletion on this device: nothing happens', () async {
      expect(await lifecycle().finalizeIfCompleted(), DeletionCompletion.none);
      expect(wiper.wiped, isEmpty);
    });

    test('completing locally removes device data, clears the marker, signs out', () async {
      await lifecycle().markStarted('alice');
      await lifecycle().completeLocally('alice');
      expect(wiper.wiped, ['alice']);
      expect(events, ['signOut']);
      expect(lifecycle().inProgressUid, isNull);
    });

    test('a failed local cleanup still signs out and keeps the marker for the next start', () async {
      await lifecycle().markStarted('alice');
      wiper.fail = true;
      await expectLater(lifecycle().completeLocally('alice'), throwsStateError);
      expect(events, ['signOut']);
      expect(lifecycle().inProgressUid, 'alice');
    });

    test('interrupted while the account still exists (or offline): incomplete, nothing wiped', () async {
      await lifecycle().markStarted('alice');
      repository.stillExists = true;
      expect(await lifecycle().finalizeIfCompleted(), DeletionCompletion.incomplete);
      repository.stillExists = null;
      expect(await lifecycle().finalizeIfCompleted(), DeletionCompletion.incomplete);
      expect(wiper.wiped, isEmpty);
      expect(lifecycle().isInProgress('alice'), isTrue);
      expect(lifecycle().isInProgress('bob'), isFalse);
    });

    test('reopened after the account was deleted but before the local cleanup', () async {
      await lifecycle().markStarted('alice');
      repository.stillExists = false;
      expect(
        await lifecycle().completeAtStartup(waitForAuthRestore: () async {}),
        DeletionCompletion.accountDeleted,
      );
      expect(wiper.wiped, ['alice']);
      expect(events, contains('signOut'));
      expect(lifecycle().inProgressUid, isNull);
    });

    test('the deleting account is no longer signed in: only its local data is removed', () async {
      await lifecycle().markStarted('alice');
      signedIn = 'bob';
      expect(await lifecycle().finalizeIfCompleted(), DeletionCompletion.localDataRemoved);
      expect(wiper.wiped, ['alice']); // never bob's
      expect(events, isEmpty); // bob stays signed in
      expect(lifecycle().inProgressUid, isNull);
    });

    test('a failed cleanup at start keeps the marker and is retried', () async {
      await lifecycle().markStarted('alice');
      signedIn = null;
      wiper.fail = true;
      expect(await lifecycle().completeAtStartup(waitForAuthRestore: () async {}), DeletionCompletion.none);
      expect(lifecycle().inProgressUid, 'alice');
      wiper.fail = false;
      expect(
        await lifecycle().completeAtStartup(waitForAuthRestore: () async {}),
        DeletionCompletion.localDataRemoved,
      );
      expect(lifecycle().inProgressUid, isNull);
    });

    test('the Firestore cache is cleared at start only after a cleanup asked for it', () async {
      await lifecycle().completeAtStartup(waitForAuthRestore: () async {});
      expect(events, isEmpty);
      await box.put(LocalAccountDataWiper.clearFirestoreCacheKey, true);
      await lifecycle().completeAtStartup(waitForAuthRestore: () async {});
      expect(events, ['clearCache']);
      expect(box.containsKey(LocalAccountDataWiper.clearFirestoreCacheKey), isFalse);
    });
  });

  group('AccountDeletionCubit', () {
    late FakeAccountDeletionRepository repository;
    late RecordingWiper wiper;
    late AccountDeletionLifecycle lifecycle;
    late int started;
    late List<String> events;
    String? signedIn;

    AccountDeletionCubit cubit() => AccountDeletionCubit(
      repository: repository,
      lifecycle: lifecycle,
      currentUid: () => signedIn,
      onStarted: () async => started += 1,
    );

    setUp(() {
      repository = FakeAccountDeletionRepository();
      wiper = RecordingWiper(box);
      signedIn = 'alice';
      started = 0;
      events = [];
      lifecycle = AccountDeletionLifecycle(
        authBox: box,
        repository: repository,
        wiper: wiper,
        currentUid: () => signedIn,
        signOut: () async => events.add('signOut'),
        clearFirestoreCache: () async {},
      );
    });

    test('success: the account is deleted, then this device data, then signed out', () async {
      final c = cubit();
      await c.load();
      expect(c.state.status, AccountDeletionStatus.ready);
      expect(c.state.incomplete, isFalse);
      expect(await c.deleteAccount('right-password'), AccountDeletionOutcome.deleted);
      expect(repository.deleted, ['alice']);
      expect(wiper.wiped, ['alice']);
      expect(events, ['signOut']);
      expect(started, 1); // local reminders stopped first
      expect(c.state.status, AccountDeletionStatus.accountDeleted);
      expect(lifecycle.inProgressUid, isNull);
      await c.close();
    });

    test('wrong password: nothing deleted, nothing marked, the form stays', () async {
      final c = cubit();
      await c.load();
      expect(await c.deleteAccount('nope'), AccountDeletionOutcome.wrongPassword);
      expect(repository.deleted, isEmpty);
      expect(started, 0);
      expect(lifecycle.inProgressUid, isNull);
      expect(c.state.status, AccountDeletionStatus.ready);
      expect(c.state.submitting, isFalse);
      expect(c.state.incomplete, isFalse);
      await c.close();
    });

    test('too many attempts is reported; nothing deleted', () async {
      final c = cubit();
      await c.load();
      repository.reauthFailure = AccountDeletionFailure.tooManyAttempts;
      expect(await c.deleteAccount('right-password'), AccountDeletionOutcome.tooManyAttempts);
      expect(repository.deleted, isEmpty);
      expect(c.state.incomplete, isFalse);
      await c.close();
    });

    test('interrupted part-way (offline, stale sign-in): incomplete, device data kept, retry completes', () async {
      final c = cubit();
      await c.load();
      repository.deleteFailure = AccountDeletionFailure.offline;
      expect(await c.deleteAccount('right-password'), AccountDeletionOutcome.offline);
      expect(c.state.status, AccountDeletionStatus.ready);
      expect(c.state.incomplete, isTrue);
      expect(wiper.wiped, isEmpty); // kept until the account is really gone
      expect(events, isEmpty); // still signed in to finish it

      repository.deleteFailure = AccountDeletionFailure.recentSignInRequired;
      expect(await c.deleteAccount('right-password'), AccountDeletionOutcome.recentSignInRequired);
      expect(c.state.incomplete, isTrue);

      repository.deleteFailure = null;
      expect(await c.deleteAccount('right-password'), AccountDeletionOutcome.deleted);
      expect(c.state.status, AccountDeletionStatus.accountDeleted);
      expect(wiper.wiped, ['alice']);
      await c.close();
    });

    test('the account is deleted even if the local cleanup fails (retried at next start)', () async {
      final c = cubit();
      await c.load();
      wiper.fail = true;
      expect(await c.deleteAccount('right-password'), AccountDeletionOutcome.deleted);
      expect(events, ['signOut']);
      expect(lifecycle.inProgressUid, 'alice');
      await c.close();
    });

    test('one submission at a time', () async {
      final c = cubit();
      await c.load();
      repository.deleteGate = Completer<void>();
      final first = c.deleteAccount('right-password');
      await pumpEventQueue();
      expect(c.state.submitting, isTrue);
      expect(await c.deleteAccount('right-password'), AccountDeletionOutcome.busy);
      repository.deleteGate!.complete();
      expect(await first, AccountDeletionOutcome.deleted);
      expect(repository.deleted, ['alice']);
      await c.close();
    });

    test('opening the screen after an interrupted deletion shows it as incomplete', () async {
      await lifecycle.markStarted('alice');
      final c = cubit();
      await c.load();
      expect(c.state.status, AccountDeletionStatus.ready);
      expect(c.state.incomplete, isTrue);
      await c.close();
    });

    test('opening the screen after the account was already deleted', () async {
      await lifecycle.markStarted('alice');
      repository.stillExists = false;
      final c = cubit();
      await c.load();
      expect(c.state.status, AccountDeletionStatus.accountDeleted);
      expect(wiper.wiped, ['alice']);
      await c.close();
    });

    test('signed out: unavailable', () async {
      signedIn = null;
      final c = cubit();
      await c.load();
      expect(c.state.status, AccountDeletionStatus.unavailable);
      await c.close();
    });
  });
}
