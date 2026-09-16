part of 'rest_timer_cubit.dart';

/// A rest timer is deliberately just one plain state, not a
/// loading/loaded/error hierarchy — it holds nothing but an in-memory
/// stopwatch value, never touches storage, and never fails.
class RestTimerState {
  final Duration elapsed;
  final bool isRunning;

  const RestTimerState({required this.elapsed, required this.isRunning});

  RestTimerState copyWith({Duration? elapsed, bool? isRunning}) {
    return RestTimerState(
      elapsed: elapsed ?? this.elapsed,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}
