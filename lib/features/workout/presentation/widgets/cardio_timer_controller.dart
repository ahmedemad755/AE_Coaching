import 'dart:async';
import 'dart:math' as math;

import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_run.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Moments worth a sound or a vibration.
enum CardioCue { phaseChanged, targetReached, finished }

/// Drives one cardio activity's timer on screen (Stage 6).
///
/// The time itself comes from [CardioRun] (saved wall-clock timestamps); the
/// ticker only refreshes the display, so a late, missed or duplicated tick
/// never changes the result. At most one ticker exists, and only while the
/// timer runs. A change is saved before it counts: if saving fails, the
/// timer goes back to where it was.
class CardioTimerController extends ChangeNotifier {
  CardioTimerController({
    required this.plan,
    required CardioRun initial,
    required this.save,
    this.onCue,
    int Function()? now,
  }) : _run = initial,
       _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
       phases = intervalPhases(plan) {
    _counted = _run.elapsedAt(_now());
    _phaseIndex = position?.index;
    final target = plan.durationSeconds;
    _targetCued =
        plan.mode == CardioMode.stopwatch &&
        target != null &&
        elapsedSeconds >= target;
    // A plan that ran out while the app was away is completed now, quietly.
    _settle(cue: false);
    _syncTicker();
  }

  final CardioPlan plan;
  final Future<void> Function(CardioRun run) save;
  final void Function(CardioCue cue)? onCue;
  final int Function() _now;
  final List<IntervalPhase> phases;

  CardioRun _run;
  int _counted = 0;
  int? _phaseIndex;
  bool _targetCued = false;
  bool _busy = false;
  Timer? _ticker;

  CardioRun get run => _run;
  CardioRunStatus get status => _run.status;
  bool get busy => _busy;
  int get elapsedMs => _counted;
  int get elapsedSeconds => _counted ~/ 1000;

  /// Countdown and intervals: what is left of the whole plan.
  int? get remainingSeconds {
    final limit = autoFinishSeconds(plan);
    return limit == null ? null : math.max(0, limit - elapsedSeconds);
  }

  IntervalPosition? get position =>
      phases.isEmpty ? null : intervalPositionAt(phases, elapsedSeconds);

  /// 0–1 towards the plan or the stopwatch's target; null without either.
  double? get progress {
    final total = autoFinishSeconds(plan) ?? plan.durationSeconds;
    if (total == null || total <= 0) return null;
    return (_counted / (total * 1000)).clamp(0.0, 1.0);
  }

  /// Refreshes the time (each tick, and when the app comes back). Listeners
  /// are told only when what is shown changes (the second or the state),
  /// not on every tick.
  void tick() {
    if (_ticker == null && _run.status != CardioRunStatus.running) return;
    final shown = (_run.status, elapsedSeconds);
    final now = _now();
    if (_reconcile(now)) unawaited(_saveQuietly(_run));
    _settle(cue: true);
    _cueProgress();
    if ((_run.status, elapsedSeconds) != shown) notifyListeners();
  }

  Future<bool> start() => _apply((run, now) => run.start(now));
  Future<bool> pause() => _apply((run, now) => run.pause(now));
  Future<bool> resume() => _apply((run, now) => run.resume(now));
  Future<bool> finish() => _apply((run, now) => run.finish(now, plan));
  Future<bool> skip() => _apply((run, now) => run.skip(now));

  /// What [finish] would record now, without changing anything.
  CardioRun preview() {
    final now = _now();
    return _run.rebase(now, _counted).finish(now, plan);
  }

  /// Keeps the time already shown when the phone's clock went back.
  /// Returns whether the run changed.
  bool _reconcile(int now) {
    final computed = _run.elapsedAt(now);
    if (_run.status == CardioRunStatus.running && computed < _counted) {
      if (_counted - computed > 1500) {
        _run = _run.rebase(now, _counted);
        return true;
      }
      return false;
    }
    _counted = computed;
    return false;
  }

  void _settle({required bool cue}) {
    final settled = _run.settle(_now(), plan);
    if (identical(settled, _run)) return;
    _run = settled;
    _counted = settled.elapsedMs;
    _syncTicker();
    unawaited(_saveQuietly(settled));
    if (cue && settled.status == CardioRunStatus.completed) {
      onCue?.call(CardioCue.finished);
    }
  }

  void _cueProgress() {
    if (_run.status != CardioRunStatus.running) return;
    final index = position?.index;
    if (index != null && index != _phaseIndex) {
      _phaseIndex = index;
      onCue?.call(CardioCue.phaseChanged);
    }
    final target = plan.durationSeconds;
    if (!_targetCued &&
        plan.mode == CardioMode.stopwatch &&
        target != null &&
        elapsedSeconds >= target) {
      _targetCued = true;
      onCue?.call(CardioCue.targetReached);
    }
  }

  Future<bool> _apply(CardioRun Function(CardioRun run, int now) change) async {
    if (_busy) return false;
    final now = _now();
    _reconcile(now);
    final before = _run;
    final current = _run.rebase(now, _counted);
    final next = change(current, now);
    if (identical(next, current)) return false;
    _busy = true;
    _run = next;
    _counted = next.elapsedAt(now);
    _phaseIndex = position?.index;
    _syncTicker();
    notifyListeners();
    try {
      await save(next);
      if (next.status == CardioRunStatus.completed) {
        onCue?.call(CardioCue.finished);
      }
      return true;
    } catch (_) {
      _run = before;
      _counted = before.elapsedAt(_now());
      _phaseIndex = position?.index;
      _syncTicker();
      rethrow;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _saveQuietly(CardioRun run) async {
    try {
      await save(run);
    } catch (error) {
      // The next action saves the state again; the screen keeps showing it.
      if (kDebugMode) {
        debugPrint('[CardioTimer] background save failed: $error');
      }
    }
  }

  void _syncTicker() {
    if (_run.status == CardioRunStatus.running) {
      _ticker ??= Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => tick(),
      );
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}

/// Keeps the screen on while a timer runs (Android). Best effort: the timer
/// stays correct either way.
class ScreenAwake {
  static const MethodChannel _channel = MethodChannel('ae_coaching/rest_timer');

  static Future<void> set(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepScreenOn', on);
    } on MissingPluginException {
      // Other platforms: nothing to do.
    } on PlatformException {
      // Best effort.
    }
  }
}
