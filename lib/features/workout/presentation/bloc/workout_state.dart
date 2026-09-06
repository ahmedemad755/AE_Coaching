part of 'workout_cubit.dart';

enum WorkoutOperation {
  load,
  save,
  delete,
  deleteMultiple,
  sync, // العملية الجديدة للمزامنة السحابية الكاملة
}

abstract class WorkoutState {
  const WorkoutState();
}

class WorkoutInitial extends WorkoutState {
  const WorkoutInitial();
}

class WorkoutLoading extends WorkoutState {
  final WorkoutOperation operation;

  const WorkoutLoading({required this.operation});
}

class WorkoutSuccess extends WorkoutState {
  final WorkoutOperation operation;
  final Box<ExerciseSet> box;
  final String message;
  final List<String> affectedKeys;

  const WorkoutSuccess({
    required this.operation,
    required this.box,
    required this.message,
    this.affectedKeys = const [],
  });
}

class WorkoutError extends WorkoutState {
  final WorkoutOperation operation;
  final String message;

  const WorkoutError({
    required this.operation,
    required this.message,
  });
}