part of 'workout_template_cubit.dart';

enum WorkoutTemplateOperation { load, create, rename, archive, reorder, restore, delete }

abstract class WorkoutTemplateState {
  const WorkoutTemplateState();
}

class WorkoutTemplateInitial extends WorkoutTemplateState {
  const WorkoutTemplateInitial();
}

class WorkoutTemplateLoading extends WorkoutTemplateState {
  final WorkoutTemplateOperation operation;

  const WorkoutTemplateLoading({required this.operation});
}

class WorkoutTemplateLoaded extends WorkoutTemplateState {
  final Box<WorkoutTemplate> box;

  const WorkoutTemplateLoaded({required this.box});
}

class WorkoutTemplateError extends WorkoutTemplateState {
  final WorkoutTemplateOperation operation;
  final String message;

  const WorkoutTemplateError({required this.operation, required this.message});
}
