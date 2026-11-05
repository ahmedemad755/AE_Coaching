import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

part 'rest_timer_state.dart';

/// In-memory countdown used only by the active workout screen.
class RestTimerCubit extends Cubit<RestTimerState> {
  Timer? _ticker;

  RestTimerCubit()
    : super(
        const RestTimerState(
          configuredDuration: Duration(minutes: 1),
          remaining: Duration(minutes: 1),
          isRunning: false,
        ),
      );

  /// Updates the next rest duration. Changing it also resets a paused timer.
  void configure(Duration duration) {
    if (state.isRunning) return;
    final safeDuration = duration.isNegative ? Duration.zero : duration;
    emit(
      state.copyWith(configuredDuration: safeDuration, remaining: safeDuration),
    );
  }

  /// Starts a fresh rest interval. Calling this after another set restarts it.
  void startCountdown() {
    final duration = state.configuredDuration;
    if (duration <= Duration.zero) return;
    _ticker?.cancel();
    emit(state.copyWith(remaining: duration, isRunning: true));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final remaining = state.remaining - const Duration(seconds: 1);
    if (remaining <= Duration.zero) {
      _ticker?.cancel();
      _ticker = null;
      emit(state.copyWith(remaining: Duration.zero, isRunning: false));
      return;
    }
    emit(state.copyWith(remaining: remaining));
  }

  /// Pauses the countdown without losing its remaining time.
  void stop() {
    _ticker?.cancel();
    _ticker = null;
    if (state.isRunning) emit(state.copyWith(isRunning: false));
  }

  /// Resets the display to the configured duration.
  void reset() {
    _ticker?.cancel();
    _ticker = null;
    emit(state.copyWith(remaining: state.configuredDuration, isRunning: false));
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _ticker = null;
    return super.close();
  }
}
