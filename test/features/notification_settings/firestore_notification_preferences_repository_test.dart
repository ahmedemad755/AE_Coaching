// Hand-rolled Firestore test doubles: cloud_firestore marks these types
// @sealed/@immutable for production code, and the project has no Firestore
// fake package (no new dependency for one repository test).
// ignore_for_file: subtype_of_sealed_class, must_be_immutable
import 'dart:async';

import 'package:ae_coaching/features/notification_settings/data/firestore_notification_preferences_repository.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _Metadata implements SnapshotMetadata {
  _Metadata({this.hasPendingWrites = false, this.isFromCache = false});
  @override
  final bool hasPendingWrites;
  @override
  final bool isFromCache;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this._data, {bool pending = false, bool cache = false})
    : metadata = _Metadata(hasPendingWrites: pending, isFromCache: cache);
  final Map<String, dynamic>? _data;
  @override
  final SnapshotMetadata metadata;
  @override
  bool get exists => _data != null;
  @override
  Map<String, dynamic>? data() => _data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// One document. Writes complete when [writeResult] completes (like the
/// real SDK, which completes on server commit).
class _Document implements DocumentReference<Map<String, dynamic>> {
  _Document(this.firestoreFake);
  final _Firestore firestoreFake;
  final List<Map<String, dynamic>> writes = [];
  Completer<void> writeResult = Completer<void>()..complete();
  Map<String, dynamic>? stored;
  final snapshotsController = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
  bool? requestedMetadataChanges;

  @override
  FirebaseFirestore get firestore => firestoreFake;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) {
    writes.add(data);
    return writeResult.future;
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    requestedMetadataChanges = includeMetadataChanges;
    return snapshotsController.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  _Transaction(this.document);
  final _Document document;
  final List<Map<String, dynamic>> sets = [];

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(DocumentReference<T> documentReference) async =>
      _Snapshot(document.stored) as DocumentSnapshot<T>;

  @override
  Transaction set<T>(DocumentReference<T> documentReference, T data, [SetOptions? options]) {
    sets.add(data as Map<String, dynamic>);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firestore implements FirebaseFirestore {
  late _Document document;
  _Transaction? lastTransaction;
  Object? transactionError;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final error = transactionError;
    if (error != null) throw error;
    final transaction = lastTransaction = _Transaction(document);
    return transactionHandler(transaction);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _prefs = NotificationPreferences(
  inactivityRemindersEnabled: false,
  language: ReminderLanguage.en,
  timeZone: 'Europe/Paris',
);

void main() {
  late _Firestore firestore;
  late _Document document;
  late List<String> requestedUids;
  late FirestoreNotificationPreferencesRepository repository;

  setUp(() {
    firestore = _Firestore();
    document = firestore.document = _Document(firestore);
    requestedUids = [];
    repository = FirestoreNotificationPreferencesRepository(
      documentFor: (uid) {
        requestedUids.add(uid);
        return document;
      },
      confirmTimeout: const Duration(milliseconds: 50),
    );
  });

  tearDown(() => document.snapshotsController.close());

  group('save', () {
    test('confirmed only when the server commits; writes the full document for that uid', () async {
      expect(await repository.save('user-a', _prefs), PreferenceSaveResult.confirmed);
      expect(requestedUids, ['user-a']);
      expect(document.writes.single.keys.toSet(), {
        'inactivityRemindersEnabled',
        'language',
        'timeZone',
        'updatedAt',
      });
      expect(document.writes.single['inactivityRemindersEnabled'], false);
    });

    test('offline: a queued write is reported as pending, never as saved', () async {
      document.writeResult = Completer<void>(); // the server never answers (yet)
      expect(await repository.save('user-a', _prefs), PreferenceSaveResult.pendingSync);
      // A later rejection of the queued write is absorbed, not an unhandled error.
      document.writeResult.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
      await pumpEventQueue();
    });

    test('a rejected write is an error, mapped by cause', () async {
      for (final (code, failure) in [
        ('permission-denied', NotificationPreferencesFailure.permissionDenied),
        ('unauthenticated', NotificationPreferencesFailure.permissionDenied),
        ('unavailable', NotificationPreferencesFailure.unavailable),
        ('internal', NotificationPreferencesFailure.unknown),
      ]) {
        document.writeResult = Completer<void>()
          ..completeError(FirebaseException(plugin: 'cloud_firestore', code: code));
        await expectLater(
          repository.save('user-a', _prefs),
          throwsA(isA<NotificationPreferencesException>().having((e) => e.failure, 'failure', failure)),
        );
      }
    });

    test('an invalid time zone never reaches Firestore', () async {
      await expectLater(repository.save('user-a', _prefs.copyWith(timeZone: 'GMT+03:00')), throwsArgumentError);
      expect(document.writes, isEmpty);
    });
  });

  group('watch', () {
    test('reports the value with its sync state, including cache and pending writes', () async {
      final emitted = <StoredNotificationPreferences>[];
      final subscription = repository.watch('user-a').listen(emitted.add);
      document.snapshotsController
        ..add(_Snapshot(null, cache: true))
        ..add(_Snapshot({'inactivityRemindersEnabled': false, 'language': 'en', 'timeZone': 'Europe/Paris'}, pending: true))
        ..add(_Snapshot({'inactivityRemindersEnabled': false, 'language': 'en', 'timeZone': 'Europe/Paris'}));
      await pumpEventQueue();
      expect(document.requestedMetadataChanges, isTrue);
      expect(emitted.map((s) => (s.exists, s.isFromCache, s.hasPendingWrites)), [
        (false, true, false),
        (true, false, true),
        (true, false, false),
      ]);
      expect(emitted.first.preferences, NotificationPreferences.defaults);
      expect(emitted.last.preferences, _prefs);
      await subscription.cancel();
    });

    test('listener errors become typed failures', () async {
      final errors = <Object>[];
      final subscription = repository.watch('user-a').listen((_) {}, onError: errors.add);
      document.snapshotsController.addError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
      await pumpEventQueue();
      expect(errors.single, isA<NotificationPreferencesException>());
      expect((errors.single as NotificationPreferencesException).failure, NotificationPreferencesFailure.permissionDenied);
      await subscription.cancel();
    });
  });

  group('reconcile (transaction)', () {
    test('decides on the server value and writes only when asked', () async {
      document.stored = {'inactivityRemindersEnabled': false, 'language': 'ar', 'timeZone': 'Africa/Cairo'};
      StoredNotificationPreferences? seen;
      final wrote = await repository.reconcile('user-a', (current) {
        seen = current;
        return null;
      });
      expect(wrote, isFalse);
      expect(seen!.exists, isTrue);
      expect(seen!.preferences.inactivityRemindersEnabled, isFalse);
      expect(firestore.lastTransaction!.sets, isEmpty);

      expect(await repository.reconcile('user-a', (_) => _prefs), isTrue);
      expect(firestore.lastTransaction!.sets.single['timeZone'], 'Europe/Paris');
    });

    test('offline or rejected transactions fail with a typed error', () async {
      firestore.transactionError = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      await expectLater(
        repository.reconcile('user-a', (_) => _prefs),
        throwsA(isA<NotificationPreferencesException>().having(
          (e) => e.failure,
          'failure',
          NotificationPreferencesFailure.unavailable,
        )),
      );
    });
  });
}
