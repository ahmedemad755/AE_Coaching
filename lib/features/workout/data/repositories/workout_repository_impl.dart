import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/Exercise_Set.dart';
import 'package:ae_coaching/features/workout/domain/repositories/workout_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final WorkoutRemoteDataSource remoteDataSource;

  WorkoutRepositoryImpl({required this.remoteDataSource});

  @override
  Future<void> saveAndSyncWorkout(
    Box<ExerciseSet> box,
    String key,
    ExerciseSet set,
  ) async {
    await box.put(_resolveLocalKey(box, key), set);

    try {
      await remoteDataSource.syncSet(key, set);
    } catch (error, stackTrace) {
      debugPrint('Remote sync failed: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> deleteAndSyncWorkout(ExerciseSet set) async {
    final key = set.key.toString();
    await set.delete();

    try {
      await remoteDataSource.deleteSet(key);
    } catch (error, stackTrace) {
      debugPrint('Remote delete failed: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> deleteMultipleAndSync(
    Box<ExerciseSet> box,
    List<String> keys,
  ) async {
    final localKeys = keys.map((key) => _resolveLocalKey(box, key));
    await box.deleteAll(localKeys);

    try {
      await remoteDataSource.deleteMultipleSets(keys);
    } catch (error, stackTrace) {
      debugPrint('Remote batch delete failed: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> fetchAndSyncFromRemote(Box<ExerciseSet> box) async {
    try {
      final remoteDocs = await remoteDataSource.fetchAllRemoteSets();
      final remoteKeys = remoteDocs.map((doc) => doc.id).toSet();
      
      // لتجنب تكرار الداتا لو نزلها تاني، بنعمل تحديث للـ Box بناءً على الـ IDs اللي جاية من السيرفر
      for (final doc in remoteDocs) {
        final data = doc.data();
        final String docKey = doc.id;
        final exerciseSet = ExerciseSet.fromJson(data);
        
        final intKey = int.tryParse(docKey);
        if (intKey != null && box.containsKey(intKey)) {
          await box.put(intKey, exerciseSet);
        } else {
          await box.put(docKey, exerciseSet);
        }
      }

      for (final localKey in box.keys) {
        final remoteKey = localKey.toString();
        final localSet = box.get(localKey);

        if (localSet == null || remoteKeys.contains(remoteKey)) {
          continue;
        }

        await remoteDataSource.syncSet(remoteKey, localSet);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to fetch and sync from cloud database: $error\n$stackTrace');
      rethrow; // بنعمل rethrow عشان الـ Cubit يلقط المشكلة ويعرض الـ Error State المناسبة
    }
  }

  dynamic _resolveLocalKey(Box<ExerciseSet> box, String key) {
    if (box.containsKey(key)) {
      return key;
    }

    final intKey = int.tryParse(key);
    if (intKey != null && box.containsKey(intKey)) {
      return intKey;
    }

    return key;
  }
}
