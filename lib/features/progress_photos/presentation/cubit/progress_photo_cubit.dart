import 'dart:io';

import 'package:ae_coaching/features/progress_photos/data/models/progress_photo.dart';
import 'package:ae_coaching/features/progress_photos/data/repositories/progress_photo_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'progress_photo_state.dart';

/// Dedicated Cubit for the Progress Photos feature — completely
/// separate from MeasurementCubit/WorkoutCubit. Only ever reads/writes
/// the current user's `progress_photos_$uid` Hive box via
/// [ProgressPhotoRepository].
class ProgressPhotoCubit extends Cubit<ProgressPhotoState> {
  final ProgressPhotoRepository repository;

  ProgressPhotoCubit({ProgressPhotoRepository? repository})
      : repository = repository ?? ProgressPhotoRepository(),
        super(const ProgressPhotoInitial());

  Future<void> loadPhotos() async {
    emit(const ProgressPhotoLoading(operation: ProgressPhotoOperation.load));
    try {
      final box = await repository.getUserBox();
      emit(
        ProgressPhotoSuccess(
          operation: ProgressPhotoOperation.load,
          box: box,
          message: 'Progress photos loaded successfully.',
        ),
      );
    } catch (error) {
      emit(
        ProgressPhotoError(
          operation: ProgressPhotoOperation.load,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  Future<void> addPhoto({
    required File sourceFile,
    required DateTime date,
    String? note,
  }) async {
    emit(const ProgressPhotoLoading(operation: ProgressPhotoOperation.add));
    try {
      await repository.addPhoto(sourceFile: sourceFile, date: date, note: note);
      final box = await repository.getUserBox();
      emit(
        ProgressPhotoSuccess(
          operation: ProgressPhotoOperation.add,
          box: box,
          message: 'Progress photo added successfully.',
        ),
      );
    } catch (error) {
      emit(
        ProgressPhotoError(
          operation: ProgressPhotoOperation.add,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  Future<void> deletePhoto(ProgressPhoto photo) async {
    emit(const ProgressPhotoLoading(operation: ProgressPhotoOperation.delete));
    try {
      await repository.deletePhoto(photo);
      final box = await repository.getUserBox();
      emit(
        ProgressPhotoSuccess(
          operation: ProgressPhotoOperation.delete,
          box: box,
          message: 'Progress photo deleted successfully.',
        ),
      );
    } catch (error) {
      emit(
        ProgressPhotoError(
          operation: ProgressPhotoOperation.delete,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  String _mapExceptionToMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
