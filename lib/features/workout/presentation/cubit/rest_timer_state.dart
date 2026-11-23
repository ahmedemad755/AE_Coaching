part of 'rest_timer_cubit.dart';

class RestTimerState {
  final Duration configuredDuration;
  final Duration remaining;
  final bool isRunning;

  const RestTimerState({
    required this.configuredDuration,
    required this.remaining,
    required this.isRunning,
  });

  double get progress {
    final total = configuredDuration.inMilliseconds;
    if (total <= 0) return 0;
    return (remaining.inMilliseconds / total).clamp(0, 1).toDouble();
  }

  RestTimerState copyWith({
    Duration? configuredDuration,
    Duration? remaining,
    bool? isRunning,
  }) {
    return RestTimerState(
      configuredDuration: configuredDuration ?? this.configuredDuration,
      remaining: remaining ?? this.remaining,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}
