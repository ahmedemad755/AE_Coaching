import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class WorkoutRemoteDataSource {
  Future<void> syncSet(String key, ExerciseSet set);
  Future<void> deleteSet(String key);
  Future<void> deleteMultipleSets(List<String> keys);
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSets(); // الدالة الجديدة للمزامنة العكسية
}

class WorkoutRemoteDataSourceImpl implements WorkoutRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  WorkoutRemoteDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _getUserCollection() {
    final uid = _auth.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    return _firestore.collection('users').doc(uid).collection('exercise_sets');
  }

  @override
  Future<void> syncSet(String key, ExerciseSet set) async {
    await _getUserCollection().doc(key).set(set.toJson());
  }

  @override
  Future<void> deleteSet(String key) async {
    await _getUserCollection().doc(key).delete();
  }

  @override
  Future<void> deleteMultipleSets(List<String> keys) async {
    final batch = _firestore.batch();
    final collection = _getUserCollection();

    for (final key in keys) {
      batch.delete(collection.doc(key));
    }
    await batch.commit();
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemoteSets() async {
    // جلب الداتا مرتبة من الأحدث للأقدم بناءً على حقل الـ date الخارجي
    final snapshot = await _getUserCollection().orderBy('date', descending: true).get();
    return snapshot.docs;
  }
}
