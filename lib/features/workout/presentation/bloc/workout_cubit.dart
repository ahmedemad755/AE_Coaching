import 'package:ae_coaching/features/workout/data/models/Exercise_Set.dart';
import 'package:ae_coaching/core/errors/exception_message_mapper.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/domain/repositories/workout_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'workout_state.dart';

class WorkoutCubit extends Cubit<WorkoutState> {
  final WorkoutRepository repository;
  final SessionStorage sessionStorage;
  final UserStorageManager storageManager;
  late final UserBox<ExerciseSet> _userBox = UserBox<ExerciseSet>(
    manager: storageManager,
    prefix: 'sets',
  );

  // Stage 7: the four use cases this Cubit used to depend on
  // (SaveAndSyncWorkoutUseCase, DeleteAndSyncWorkoutUseCase,
  // DeleteMultipleAndSyncUseCase, FetchAndSyncFromRemoteUseCase) were
  // each a pure single-repository-method pass-through with no
  // validation/transformation/orchestration of their own — and, unlike
  // every Auth use case (which uniformly wraps 100% of that feature's
  // operations), they were the only place left in the whole Workout
  // feature still using this indirection; every newer workout Cubit
  // (Program/Template/Session/SessionExercise/...) already injects its
  // repository directly. Removed; repository injected directly instead.
  WorkoutCubit({
    required this.repository,
    required this.sessionStorage,
    required this.storageManager,
  }) : super(const WorkoutInitial());

  // 1. جلب وتحميل الـ Box ومزامنته السحابية الكاملة لضمان جلب بيانات الأجهزة الأخرى
  Future<void> loadWorkoutBox() async {
    emit(const WorkoutLoading(operation: WorkoutOperation.load));

    try {
      final box = await _getWorkoutBox();

      // إشارة نجاح أولية عشان الـ UI يعرض الداتا المحلية الكاش فوراً لو موجودة (Offline-First)
      emit(
        WorkoutSuccess(
          operation: WorkoutOperation.load,
          box: box,
          message: 'Local workout box cached successfully.',
        ),
      );

      // الآن نعمل الـ Sync الصامت لجلب أي تمارين جديدة تمت من أي جهاز أخر
      emit(const WorkoutLoading(operation: WorkoutOperation.sync));
      await repository.fetchAndSyncFromRemote(box);

      // تأكيد النجاح الكامل والنهائي بعد مزامنة داتا الفايرستور والـ Hive معاً
      emit(
        WorkoutSuccess(
          operation: WorkoutOperation.sync,
          box: box,
          message: 'Workout box updated and synced with cloud database.',
        ),
      );
    } catch (error) {
      emit(
        WorkoutError(
          operation: WorkoutOperation.load,
          message: mapGenericExceptionToMessage(error),
        ),
      );
    }
  }

  // 2. حفظ وتحديث تمرين
  Future<void> saveWorkout({required ExerciseSet set, String? key}) async {
    emit(const WorkoutLoading(operation: WorkoutOperation.save));

    try {
      final box = await _getWorkoutBox();
      final resolvedKey = _resolveWorkoutKey(key, set);

      await repository.saveAndSyncWorkout(box, resolvedKey, set);

      emit(
        WorkoutSuccess(
          operation: WorkoutOperation.save,
          box: box,
          message: 'Workout saved and synced successfully.',
          affectedKeys: [resolvedKey],
        ),
      );
    } catch (error) {
      emit(
        WorkoutError(
          operation: WorkoutOperation.save,
          message: mapGenericExceptionToMessage(error),
        ),
      );
    }
  }

  // 3. مسح تمرين فردي
  Future<void> deleteWorkout({required ExerciseSet set}) async {
    emit(const WorkoutLoading(operation: WorkoutOperation.delete));

    try {
      final box = await _getWorkoutBox();
      final String? key = set.key?.toString();

      if (key == null || key.isEmpty) {
        throw Exception('Workout set is not stored in Hive.');
      }

      await repository.deleteAndSyncWorkout(set);

      emit(
        WorkoutSuccess(
          operation: WorkoutOperation.delete,
          box: box,
          message: 'Workout deleted and synced successfully.',
          affectedKeys: [key],
        ),
      );
    } catch (error) {
      emit(
        WorkoutError(
          operation: WorkoutOperation.delete,
          message: mapGenericExceptionToMessage(error),
        ),
      );
    }
  }

  // 4. مسح مجموعة تمارين (Swipe to Delete)
  Future<void> deleteMultipleWorkouts({required List<String> keys}) async {
    emit(const WorkoutLoading(operation: WorkoutOperation.deleteMultiple));

    try {
      final box = await _getWorkoutBox();
      final formattedKeys = keys
          .map((key) => key.trim())
          .where((key) => key.isNotEmpty)
          .toList(growable: false);

      if (formattedKeys.isEmpty) {
        throw Exception('No workout sets selected for deletion.');
      }

      await repository.deleteMultipleAndSync(box, formattedKeys);

      emit(
        WorkoutSuccess(
          operation: WorkoutOperation.deleteMultiple,
          box: box,
          message: 'Workout sets deleted and synced successfully.',
          affectedKeys: formattedKeys,
        ),
      );
    } catch (error) {
      emit(
        WorkoutError(
          operation: WorkoutOperation.deleteMultiple,
          message: mapGenericExceptionToMessage(error),
        ),
      );
    }
  }

  // Helpers الأقوياء بتوعك
  //
  // Stage 3: box selection/opening now goes entirely through the
  // shared UserStorageManager via _userBox — this Cubit no longer
  // duplicates the 'sets_$uid' open-or-reuse logic that also lived
  // (independently) in SessionExerciseRepository and hom.dart. The
  // sessionStorage.updateCurrentUserUid side effect (Stage 1) and the
  // exact historical empty-uid check/exception are preserved unchanged.
  Future<Box<ExerciseSet>> _getWorkoutBox() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      throw Exception('User not authenticated');
    }

    await sessionStorage.updateCurrentUserUid(uid);

    return _userBox.getUserBox();
  }

  String _resolveWorkoutKey(String? eventKey, ExerciseSet set) {
    final key = eventKey?.trim();
    if (key != null && key.isNotEmpty) {
      return key;
    }

    final String? hiveKey = set.key?.toString();
    if (hiveKey != null && hiveKey.isNotEmpty) {
      return hiveKey;
    }

    return 'workout_${DateTime.now().microsecondsSinceEpoch}';
  }
}
