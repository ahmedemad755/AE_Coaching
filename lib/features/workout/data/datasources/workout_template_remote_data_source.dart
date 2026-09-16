import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Cloud backup for workout templates. Mirrors
/// WorkoutProgramRemoteDataSource exactly, writing to its own
/// Firestore subcollection so templates never mix with programs,
/// exercise_sets, or body_measurements.
abstract class WorkoutTemplateRemoteDataSource {
  Future<void> syncTemplate(String id, WorkoutTemplate template);
  Future<void> deleteTemplate(String id);
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteTemplates();
}

class WorkoutTemplateRemoteDataSourceImpl implements WorkoutTemplateRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  WorkoutTemplateRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _getUserCollection() {
    final uid = _auth.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    return _firestore.collection('users').doc(uid).collection('workout_templates');
  }

  @override
  Future<void> syncTemplate(String id, WorkoutTemplate template) async {
    await _getUserCollection().doc(id).set(template.toJson());
  }

  @override
  Future<void> deleteTemplate(String id) async {
    await _getUserCollection().doc(id).delete();
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteTemplates() async {
    final snapshot = await _getUserCollection().orderBy('createdAt', descending: true).get();
    return snapshot.docs;
  }
}
