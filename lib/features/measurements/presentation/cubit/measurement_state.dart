part of 'measurement_cubit.dart';

enum MeasurementOperation { load, add, update, delete, sync }

abstract class MeasurementState {
  const MeasurementState();
}

class MeasurementInitial extends MeasurementState {
  const MeasurementInitial();
}

class MeasurementLoading extends MeasurementState {
  final MeasurementOperation operation;

  const MeasurementLoading({required this.operation});
}

class MeasurementSuccess extends MeasurementState {
  final MeasurementOperation operation;
  final Box<BodyMeasurement> box;
  final String message;

  const MeasurementSuccess({
    required this.operation,
    required this.box,
    required this.message,
  });
}

class MeasurementError extends MeasurementState {
  final MeasurementOperation operation;
  final String message;

  const MeasurementError({
    required this.operation,
    required this.message,
  });
}
