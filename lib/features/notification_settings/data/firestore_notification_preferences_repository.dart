import 'dart:async';

import 'package:ae_coaching/features/notification_settings/data/notification_preferences_document.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

typedef PreferencesDocumentFor = DocumentReference<Map<String, dynamic>> Function(String uid);

/// Firestore implementation. With offline persistence, a write updates the
/// local cache at once but its Future completes only when the server
/// commits it. That is what tells "confirmed" from "queued": a write still
/// unconfirmed after [confirmTimeout] is reported as
/// [PreferenceSaveResult.pendingSync] and keeps syncing in the background.
class FirestoreNotificationPreferencesRepository implements NotificationPreferencesRepository {
  FirestoreNotificationPreferencesRepository({
    FirebaseFirestore? firestore,
    PreferencesDocumentFor? documentFor,
    this.confirmTimeout = const Duration(seconds: 8),
  }) : _documentFor =
           documentFor ??
           ((uid) => (firestore ?? FirebaseFirestore.instance)
               .collection('users')
               .doc(uid)
               .collection('settings')
               .doc('notifications'));

  final PreferencesDocumentFor _documentFor;
  final Duration confirmTimeout;

  @override
  Stream<StoredNotificationPreferences> watch(String uid) => _documentFor(uid)
      .snapshots(includeMetadataChanges: true)
      .map(_stored)
      .handleError((Object error) => throw _mapError(error));

  @override
  Future<bool> reconcile(
    String uid,
    NotificationPreferences? Function(StoredNotificationPreferences current) decide,
  ) async {
    final document = _documentFor(uid);
    try {
      return await document.firestore.runTransaction((transaction) async {
        final next = decide(_stored(await transaction.get(document)));
        if (next == null) return false;
        transaction.set(document, NotificationPreferencesDocument.toFirestore(next));
        return true;
      }, timeout: confirmTimeout);
    } catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<PreferenceSaveResult> save(String uid, NotificationPreferences preferences) async {
    final write = _documentFor(uid).set(NotificationPreferencesDocument.toFirestore(preferences));
    try {
      await write.timeout(confirmTimeout);
      return PreferenceSaveResult.confirmed;
    } on TimeoutException {
      // Still queued: never reported as saved. A later rejection reverts
      // the cached value, which every watcher then shows.
      unawaited(
        write.then<void>(
          (_) {},
          onError: (Object error) => debugPrint('Queued notification preference write failed: ${_mapError(error)}'),
        ),
      );
      return PreferenceSaveResult.pendingSync;
    } catch (error) {
      throw _mapError(error);
    }
  }

  static StoredNotificationPreferences _stored(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      StoredNotificationPreferences(
        preferences: NotificationPreferencesDocument.fromFirestore(snapshot.exists ? snapshot.data() : null),
        exists: snapshot.exists,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
        isFromCache: snapshot.metadata.isFromCache,
      );

  static NotificationPreferencesException _mapError(Object error) {
    if (error is NotificationPreferencesException) return error;
    if (error is FirebaseException) {
      return NotificationPreferencesException(switch (error.code) {
        'permission-denied' || 'unauthenticated' => NotificationPreferencesFailure.permissionDenied,
        'unavailable' || 'deadline-exceeded' => NotificationPreferencesFailure.unavailable,
        _ => NotificationPreferencesFailure.unknown,
      });
    }
    return const NotificationPreferencesException(NotificationPreferencesFailure.unknown);
  }
}
