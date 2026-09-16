import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Cloud backup for workout sessions. Mirrors
/// WorkoutTemplateRemoteDataSource / WorkoutProgramRemoteDataSource,
/// writing to its own Firestore subcollection.
abstract class WorkoutSessionRemoteDataSource {
  Future<void> syncSession(String id, WorkoutSession session);
  Future<void> deleteSession(String id);
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSessions();
}

class WorkoutSessionRemoteDataSourceImpl implements WorkoutSessionRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  WorkoutSessionRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _getUserCollection() {
    final uid = _auth.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    return _firestore.collection('users').doc(uid).collection('workout_sessions');
  }

  @override
  Future<void> syncSession(String id, WorkoutSession session) async {
    await _getUserCollection().doc(id).set(session.toJson());
  }

  @override
  Future<void> deleteSession(String id) async {
    await _getUserCollection().doc(id).delete();
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSessions() async {
    final snapshot = await _getUserCollection().orderBy('date', descending: true).get();
    return snapshot.docs;
  }
}
