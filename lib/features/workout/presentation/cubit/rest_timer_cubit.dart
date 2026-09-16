import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

part 'rest_timer_state.dart';

/// A manual, count-UP rest timer — the user explicitly starts it and
/// explicitly stops it; it never auto-starts after logging a set and
/// never auto-ends on its own after some fixed duration. This mirrors
/// the same manual-stopwatch preference already used for the overall
/// session elapsed timer (Phase 7): the athlete decides when rest is
/// over, not a countdown.
///
/// Entirely in-memory and screen-scoped (registered as a factory, one
/// instance per [ActiveWorkoutSessionScreen]) — nothing here is
/// persisted, and nothing here can block or interfere with logging
/// sets, finishing, or cancelling the workout; it is purely an
/// optional side display.
class RestTimerCubit extends Cubit<RestTimerState> {
  Timer? _ticker;

  RestTimerCubit() : super(const RestTimerState(elapsed: Duration.zero, isRunning: false));

  /// Starts (or resumes) counting up from the current elapsed value.
  /// Calling it while already running is a harmless no-op — it never
  /// schedules a second ticker.
  void start() {
    if (state.isRunning) return;
    emit(state.copyWith(isRunning: true));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      emit(state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1)));
    });
  }

  /// Pauses counting, preserving the elapsed value so far — the user
  /// can [start] again to resume from where it left off.
  void stop() {
    _ticker?.cancel();
    _ticker = null;
    if (state.isRunning) emit(state.copyWith(isRunning: false));
  }

  /// Stops and zeroes the elapsed value.
  void reset() {
    _ticker?.cancel();
    _ticker = null;
    emit(const RestTimerState(elapsed: Duration.zero, isRunning: false));
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _ticker = null;
    return super.close();
  }
}
