import 'dart:async';

import 'package:ae_coaching/features/notification_settings/data/device_time_zone.dart';
import 'package:ae_coaching/features/notification_settings/data/verified_account.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences_repository.dart';

/// The verified account, switchable by tests (null = none / unverified).
class FakeVerifiedAccount extends VerifiedAccount {
  FakeVerifiedAccount(this.uid);

  String? uid;
  int reads = 0;

  @override
  String? currentUid() {
    reads += 1;
    return uid;
  }
}

/// A device time zone without platform channels; the real IANA check runs.
DeviceTimeZone fakeDeviceTimeZone(String? zone) => DeviceTimeZone(
  readPlatformZone: () async => zone ?? (throw StateError('no zone')),
);

/// In-memory `users/{uid}/settings/notifications`, one document per uid.
class FakeNotificationPreferencesRepository implements NotificationPreferencesRepository {
  final Map<String, NotificationPreferences> documents = {};
  final List<(String, NotificationPreferences)> writes = [];
  final _changes = StreamController<(String, StoredNotificationPreferences)>.broadcast();

  /// What a successful save reports.
  PreferenceSaveResult saveResult = PreferenceSaveResult.confirmed;
  NotificationPreferencesException? saveError;
  NotificationPreferencesException? watchError;
  NotificationPreferencesException? reconcileError;

  /// Offline: snapshots come from the device cache.
  bool fromCache = false;

  /// Holds a save in flight until completed.
  Completer<void>? saveGate;

  StoredNotificationPreferences current(String uid, {bool pending = false}) => StoredNotificationPreferences(
    preferences: documents[uid] ?? NotificationPreferences.defaults,
    exists: documents.containsKey(uid),
    hasPendingWrites: pending,
    isFromCache: fromCache,
  );

  @override
  Stream<StoredNotificationPreferences> watch(String uid) => Stream.multi((controller) {
    final error = watchError;
    if (error != null) {
      controller.addError(error);
      return;
    }
    controller.add(current(uid));
    final subscription = _changes.stream.where((change) => change.$1 == uid).listen((change) => controller.add(change.$2));
    controller.onCancel = subscription.cancel;
  });

  @override
  Future<PreferenceSaveResult> save(String uid, NotificationPreferences preferences) async {
    final gate = saveGate;
    if (gate != null) await gate.future;
    final error = saveError;
    if (error != null) throw error;
    documents[uid] = preferences;
    writes.add((uid, preferences));
    _changes.add((uid, current(uid, pending: saveResult == PreferenceSaveResult.pendingSync)));
    return saveResult;
  }

  @override
  Future<bool> reconcile(
    String uid,
    NotificationPreferences? Function(StoredNotificationPreferences current) decide,
  ) async {
    final error = reconcileError;
    if (error != null) throw error;
    final next = decide(current(uid));
    if (next == null) return false;
    documents[uid] = next;
    writes.add((uid, next));
    _changes.add((uid, current(uid)));
    return true;
  }

  Future<void> dispose() => _changes.close();
}
