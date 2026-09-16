part of 'program_overview_cubit.dart';

abstract class ProgramOverviewState {
  const ProgramOverviewState();
}

class ProgramOverviewInitial extends ProgramOverviewState {
  const ProgramOverviewInitial();
}

class ProgramOverviewLoading extends ProgramOverviewState {
  const ProgramOverviewLoading();
}

class ProgramOverviewLoaded extends ProgramOverviewState {
  final ProgramWeeklyOverview overview;
  const ProgramOverviewLoaded(this.overview);
}

class ProgramOverviewError extends ProgramOverviewState {
  final String message;
  const ProgramOverviewError(this.message);
}
