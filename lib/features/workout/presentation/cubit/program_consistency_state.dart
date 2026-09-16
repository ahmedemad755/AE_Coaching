part of 'program_consistency_cubit.dart';

abstract class ProgramConsistencyState {
  const ProgramConsistencyState();
}

class ProgramConsistencyInitial extends ProgramConsistencyState {
  const ProgramConsistencyInitial();
}

class ProgramConsistencyLoading extends ProgramConsistencyState {
  const ProgramConsistencyLoading();
}

class ProgramConsistencyLoaded extends ProgramConsistencyState {
  final ProgramConsistencySummary summary;
  const ProgramConsistencyLoaded(this.summary);
}

class ProgramConsistencyError extends ProgramConsistencyState {
  final String message;
  const ProgramConsistencyError(this.message);
}
