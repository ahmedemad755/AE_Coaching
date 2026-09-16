part of 'home_workout_overview_cubit.dart';

abstract class HomeWorkoutOverviewState {
  const HomeWorkoutOverviewState();
}

class HomeWorkoutOverviewInitial extends HomeWorkoutOverviewState {
  const HomeWorkoutOverviewInitial();
}

class HomeWorkoutOverviewLoading extends HomeWorkoutOverviewState {
  const HomeWorkoutOverviewLoading();
}

class HomeWorkoutOverviewLoaded extends HomeWorkoutOverviewState {
  final HomeWorkoutOverview overview;
  const HomeWorkoutOverviewLoaded(this.overview);
}

class HomeWorkoutOverviewError extends HomeWorkoutOverviewState {
  final String message;
  const HomeWorkoutOverviewError(this.message);
}
