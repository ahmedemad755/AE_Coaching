part of 'program_analytics_cubit.dart';

abstract class ProgramAnalyticsState {
  const ProgramAnalyticsState();
}

class ProgramAnalyticsInitial extends ProgramAnalyticsState {
  const ProgramAnalyticsInitial();
}

class ProgramAnalyticsLoading extends ProgramAnalyticsState {
  const ProgramAnalyticsLoading();
}

class ProgramAnalyticsLoaded extends ProgramAnalyticsState {
  final ProgramAnalyticsSummary summary;
  const ProgramAnalyticsLoaded(this.summary);
}

class ProgramAnalyticsError extends ProgramAnalyticsState {
  final String message;
  const ProgramAnalyticsError(this.message);
}
