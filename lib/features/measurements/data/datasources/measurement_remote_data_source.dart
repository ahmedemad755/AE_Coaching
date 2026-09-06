import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Cloud backup for body measurement check-ins.
///
/// Mirrors the WorkoutRemoteDataSource pattern exactly, but writes to
/// its own Firestore subcollection (`body_measurements`) so measurement
/// data never mixes with `exercise_sets`.
abstract class MeasurementRemoteDataSource {
  Future<void> syncMeasurement(String key, BodyMeasurement measurement);
  Future<void> deleteMeasurement(String key);
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchAllRemoteMeasurements();
}

class MeasurementRemoteDataSourceImpl implements MeasurementRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  MeasurementRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _getUserCollection() {
    final uid = _auth.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    return _firestore.collection('users').doc(uid).collection('body_measurements');
  }

  @override
  Future<void> syncMeasurement(String key, BodyMeasurement measurement) async {
    await _getUserCollection().doc(key).set(measurement.toJson());
  }

  @override
  Future<void> deleteMeasurement(String key) async {
    await _getUserCollection().doc(key).delete();
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchAllRemoteMeasurements() async {
    final snapshot = await _getUserCollection().orderBy('date', descending: true).get();
    return snapshot.docs;
  }
}
