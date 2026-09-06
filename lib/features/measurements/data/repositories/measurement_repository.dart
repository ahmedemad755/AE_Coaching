import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/features/measurements/data/datasources/measurement_remote_data_source.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Handles all Hive + Firestore access for body measurement check-ins.
///
/// Mirrors the per-user box pattern already used for workouts
/// (`sets_$uid`) but keeps measurements completely separate in their
/// own `measurements_$uid` box / `body_measurements` Firestore
/// subcollection so the two features never mix data.
///
/// Local Hive is the fast/offline-first source of truth for the UI;
/// every write is also pushed to Firestore under
/// `users/{uid}/body_measurements` so a check-in survives logout, app
/// kill, or a full uninstall/reinstall — the same guarantee the
/// existing Workout feature already has.
class MeasurementRepository {
  final MeasurementRemoteDataSource remoteDataSource;

  MeasurementRepository({MeasurementRemoteDataSource? remoteDataSource})
      : remoteDataSource = remoteDataSource ?? MeasurementRemoteDataSourceImpl();

  /// Opens (or returns the already-open) Hive box that belongs to the
  /// currently signed-in Firebase user.
  Future<Box<BodyMeasurement>> getUserBox() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    final boxName = 'measurements_$uid';
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<BodyMeasurement>(boxName);
    }

    return Hive.openBox<BodyMeasurement>(boxName);
  }

  Future<void> addMeasurement(BodyMeasurement measurement) async {
    final box = await getUserBox();
    final key = await box.add(measurement);

    try {
      await remoteDataSource.syncMeasurement(key.toString(), measurement);
    } catch (error, stackTrace) {
      debugPrint('Measurement remote sync failed: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> updateMeasurement(dynamic key, BodyMeasurement measurement) async {
    final box = await getUserBox();
    await box.put(key, measurement);

    try {
      await remoteDataSource.syncMeasurement(key.toString(), measurement);
    } catch (error, stackTrace) {
      debugPrint('Measurement remote sync failed: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<void> deleteMeasurement(dynamic key) async {
    final box = await getUserBox();
    await box.delete(key);

    try {
      await remoteDataSource.deleteMeasurement(key.toString());
    } catch (error, stackTrace) {
      debugPrint('Measurement remote delete failed: $error\n$stackTrace');
      rethrow;
    }
  }

  /// Pulls every check-in stored in the cloud into the local box (so a
  /// fresh install / different device catches up), then pushes up any
  /// local check-in the cloud doesn't know about yet (e.g. one added
  /// while offline).
  Future<void> fetchAndSyncFromRemote(Box<BodyMeasurement> box) async {
    try {
      final remoteDocs = await remoteDataSource.fetchAllRemoteMeasurements();
      final remoteKeys = remoteDocs.map((doc) => doc.id).toSet();

      for (final doc in remoteDocs) {
        final data = doc.data();
        final String docKey = doc.id;
        final measurement = BodyMeasurement.fromJson(data);

        final intKey = int.tryParse(docKey);
        if (intKey != null && box.containsKey(intKey)) {
          await box.put(intKey, measurement);
        } else {
          await box.put(docKey, measurement);
        }
      }

      for (final localKey in box.keys) {
        final remoteKey = localKey.toString();
        final localMeasurement = box.get(localKey);

        if (localMeasurement == null || remoteKeys.contains(remoteKey)) {
          continue;
        }

        await remoteDataSource.syncMeasurement(remoteKey, localMeasurement);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch and sync measurements from cloud: $error\n$stackTrace');
      rethrow;
    }
  }

  /// Returns every stored check-in for the current user, newest first.
  List<BodyMeasurement> getAllSorted(Box<BodyMeasurement> box) {
    final all = box.values.toList();
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }
}
