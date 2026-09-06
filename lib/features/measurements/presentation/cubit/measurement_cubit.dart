import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/features/measurements/data/repositories/measurement_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'measurement_state.dart';

/// Dedicated Cubit for the Body Measurements feature.
///
/// Kept completely separate from [WorkoutCubit] / workout Hive boxes:
/// this Cubit only ever reads/writes the current user's
/// `measurements_$uid` box via [MeasurementRepository].
class MeasurementCubit extends Cubit<MeasurementState> {
  final MeasurementRepository repository;

  MeasurementCubit({MeasurementRepository? repository})
      : repository = repository ?? MeasurementRepository(),
        super(const MeasurementInitial());

  /// Offline-first load: shows whatever is cached on-device immediately,
  /// then silently syncs with Firestore in the background so the latest
  /// check-ins from other devices (or a fresh reinstall) catch up.
  Future<void> loadMeasurements() async {
    emit(const MeasurementLoading(operation: MeasurementOperation.load));
    try {
      final box = await repository.getUserBox();

      emit(
        MeasurementSuccess(
          operation: MeasurementOperation.load,
          box: box,
          message: 'Measurements loaded from device.',
        ),
      );

      emit(const MeasurementLoading(operation: MeasurementOperation.sync));
      await repository.fetchAndSyncFromRemote(box);

      emit(
        MeasurementSuccess(
          operation: MeasurementOperation.sync,
          box: box,
          message: 'Measurements synced with cloud.',
        ),
      );
    } catch (error) {
      emit(
        MeasurementError(
          operation: MeasurementOperation.load,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  Future<void> addMeasurement(BodyMeasurement measurement) async {
    emit(const MeasurementLoading(operation: MeasurementOperation.add));
    try {
      await repository.addMeasurement(measurement);
      final box = await repository.getUserBox();
      emit(
        MeasurementSuccess(
          operation: MeasurementOperation.add,
          box: box,
          message: 'Measurement check-in added successfully.',
        ),
      );
    } catch (error) {
      emit(
        MeasurementError(
          operation: MeasurementOperation.add,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  Future<void> updateMeasurement(dynamic key, BodyMeasurement measurement) async {
    emit(const MeasurementLoading(operation: MeasurementOperation.update));
    try {
      await repository.updateMeasurement(key, measurement);
      final box = await repository.getUserBox();
      emit(
        MeasurementSuccess(
          operation: MeasurementOperation.update,
          box: box,
          message: 'Measurement check-in updated successfully.',
        ),
      );
    } catch (error) {
      emit(
        MeasurementError(
          operation: MeasurementOperation.update,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  Future<void> deleteMeasurement(dynamic key) async {
    emit(const MeasurementLoading(operation: MeasurementOperation.delete));
    try {
      await repository.deleteMeasurement(key);
      final box = await repository.getUserBox();
      emit(
        MeasurementSuccess(
          operation: MeasurementOperation.delete,
          box: box,
          message: 'Measurement check-in deleted successfully.',
        ),
      );
    } catch (error) {
      emit(
        MeasurementError(
          operation: MeasurementOperation.delete,
          message: _mapExceptionToMessage(error),
        ),
      );
    }
  }

  String _mapExceptionToMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
