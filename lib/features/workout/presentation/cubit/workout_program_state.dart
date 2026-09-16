part of 'workout_program_cubit.dart';

enum WorkoutProgramOperation { load, create, rename, setActive, archive, delete }

abstract class WorkoutProgramState {
  const WorkoutProgramState();
}

class WorkoutProgramInitial extends WorkoutProgramState {
  const WorkoutProgramInitial();
}

class WorkoutProgramLoading extends WorkoutProgramState {
  final WorkoutProgramOperation operation;

  const WorkoutProgramLoading({required this.operation});
}

class WorkoutProgramLoaded extends WorkoutProgramState {
  final Box<WorkoutProgram> box;

  const WorkoutProgramLoaded({required this.box});
}

class WorkoutProgramError extends WorkoutProgramState {
  final WorkoutProgramOperation operation;
  final String message;

  const WorkoutProgramError({
    required this.operation,
    required this.message,
  });
}
