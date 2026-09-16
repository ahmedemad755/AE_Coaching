import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Cloud backup for workout programs. Mirrors WorkoutRemoteDataSource /
/// MeasurementRemoteDataSource exactly, writing to its own Firestore
/// subcollection so programs never mix with exercise_sets or
/// body_measurements.
abstract class WorkoutProgramRemoteDataSource {
  Future<void> syncProgram(String id, WorkoutProgram program);
  Future<void> deleteProgram(String id);
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemotePrograms();
}

class WorkoutProgramRemoteDataSourceImpl implements WorkoutProgramRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  WorkoutProgramRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _getUserCollection() {
    final uid = _auth.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    return _firestore.collection('users').doc(uid).collection('workout_programs');
  }

  @override
  Future<void> syncProgram(String id, WorkoutProgram program) async {
    await _getUserCollection().doc(id).set(program.toJson());
  }

  @override
  Future<void> deleteProgram(String id) async {
    await _getUserCollection().doc(id).delete();
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemotePrograms() async {
    final snapshot = await _getUserCollection().orderBy('createdAt', descending: true).get();
    return snapshot.docs;
  }
}
