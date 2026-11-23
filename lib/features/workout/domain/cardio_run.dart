import 'dart:math' as math;

import 'package:ae_coaching/features/workout/domain/activity_plans.dart';

/// Where a cardio activity of a workout session is.
enum CardioRunStatus {
  notStarted,
  running,
  paused,

  /// The plan was reached (or a stopwatch without a target was finished).
  completed,

  /// Finished by the user before the plan was reached.
  endedEarly,

  /// Not done. Never counted as completed, whatever time was on the clock.
  skipped;

  bool get isOpen => this == running || this == paused;
  bool get isFinal =>
      this == completed || this == endedEarly || this == skipped;

  static CardioRunStatus parse(Object? value) =>
      values.where((status) => status.name == value).firstOrNull ?? notStarted;
}

enum IntervalPhaseKind { warmup, work, rest, cooldown }

/// One phase of an interval plan.
class IntervalPhase {
  const IntervalPhase(this.kind, this.seconds, {this.round = 0});

  final IntervalPhaseKind kind;
  final int seconds;

  /// 1-based for work and rest; 0 for warm-up and cool-down.
  final int round;
}

/// Which phase an interval timer is in.
class IntervalPosition {
  const IntervalPosition({
    required this.index,
    required this.phase,
    required this.remainingSeconds,
    this.next,
  });

  final int index;
  final IntervalPhase phase;
  final int remainingSeconds;
  final IntervalPhase? next;
}

/// The phases of an interval plan, in order: the optional warm-up, work and
/// rest for each round (no rest after the last round), the optional
/// cool-down. Matches [CardioPlan.plannedSeconds].
List<IntervalPhase> intervalPhases(CardioPlan plan) {
  final work = plan.workSeconds;
  final rounds = plan.rounds;
  if (plan.mode != CardioMode.intervals || work == null || rounds == null) {
    return const [];
  }
  final rest = plan.intervalRestSeconds ?? 0;
  return [
    if ((plan.warmupSeconds ?? 0) > 0)
      IntervalPhase(IntervalPhaseKind.warmup, plan.warmupSeconds!),
    for (var round = 1; round <= rounds; round++) ...[
      if (work > 0) IntervalPhase(IntervalPhaseKind.work, work, round: round),
      if (rest > 0 && round < rounds)
        IntervalPhase(IntervalPhaseKind.rest, rest, round: round),
    ],
    if ((plan.cooldownSeconds ?? 0) > 0)
      IntervalPhase(IntervalPhaseKind.cooldown, plan.cooldownSeconds!),
  ];
}

/// The phase at [elapsedSeconds], or null once every phase is over.
IntervalPosition? intervalPositionAt(
  List<IntervalPhase> phases,
  int elapsedSeconds,
) {
  var start = 0;
  for (var i = 0; i < phases.length; i++) {
    final end = start + phases[i].seconds;
    if (elapsedSeconds < end) {
      return IntervalPosition(
        index: i,
        phase: phases[i],
        remainingSeconds: end - elapsedSeconds,
        next: i + 1 < phases.length ? phases[i + 1] : null,
      );
    }
    start = end;
  }
  return null;
}

/// Seconds after which a plan ends by itself: countdown and intervals.
/// A stopwatch runs until the user finishes it (its target is a goal).
int? autoFinishSeconds(CardioPlan plan) => switch (plan.mode) {
  CardioMode.countdown => plan.durationSeconds,
  CardioMode.intervals => plan.plannedSeconds,
  CardioMode.stopwatch => null,
};

/// One cardio activity's timer in a workout session (Stage 6).
///
/// Time is kept as wall-clock timestamps that are saved with the session,
/// not as a count of UI ticks: the timer keeps counting while the phone
/// sleeps, while the app is in the background, and after the app was
/// closed. A running timer never counts backwards: a clock moved back adds
/// nothing (see [elapsedAt] and [rebase]). A clock moved forward by hand
/// does advance it; that cannot be told apart from the phone sleeping.
///
/// Immutable: every action returns the new state, which the caller saves.
class CardioRun {
  const CardioRun({
    this.status = CardioRunStatus.notStarted,
    this.elapsedMs = 0,
    this.runningSinceMs,
    this.startedAtMs,
    this.endedAtMs,
    this.plannedSeconds,
    this.mode,
    this.name,
    this.exerciseId,
  });

  /// A not-yet-started run with the plan's details kept for history.
  factory CardioRun.planned({
    required CardioPlan plan,
    required String name,
    required String exerciseId,
  }) => CardioRun(
    plannedSeconds: plan.plannedSeconds,
    mode: plan.mode,
    name: name,
    exerciseId: exerciseId,
  );

  /// Longest time recorded for one activity (the longest plan allowed).
  static const maxSeconds = 6 * 3600;

  final CardioRunStatus status;

  /// Time counted before the current running stretch (all of it when not
  /// running).
  final int elapsedMs;

  /// When the current running stretch began (ms since epoch). Only while
  /// running.
  final int? runningSinceMs;

  /// First start and final end (ms since epoch), for history.
  final int? startedAtMs;
  final int? endedAtMs;

  /// The plan at the time (history keeps what was planned).
  final int? plannedSeconds;
  final CardioMode? mode;
  final String? name;
  final String? exerciseId;

  /// Counted time at [nowMs], never below what was already counted and
  /// never above [maxSeconds].
  int elapsedAt(int nowMs) {
    var total = elapsedMs;
    final since = runningSinceMs;
    if (status == CardioRunStatus.running && since != null) {
      total += math.max(0, nowMs - since);
    }
    return math.min(total, maxSeconds * 1000);
  }

  int get actualSeconds => elapsedMs ~/ 1000;

  /// Time spent on it, for a workout that counts it: done or ended early,
  /// or still open (closed when the workout is finished).
  bool get countsAsTraining =>
      status == CardioRunStatus.completed ||
      status == CardioRunStatus.endedEarly ||
      status.isOpen;

  /// Starts it. A skipped activity can still be done after all.
  CardioRun start(int nowMs) => switch (status) {
    CardioRunStatus.notStarted || CardioRunStatus.skipped => _copy(
      status: CardioRunStatus.running,
      elapsedMs: 0,
      runningSinceMs: nowMs,
      startedAtMs: nowMs,
      endedAtMs: null,
    ),
    _ => this,
  };

  CardioRun pause(int nowMs) => status == CardioRunStatus.running
      ? _copy(
          status: CardioRunStatus.paused,
          elapsedMs: elapsedAt(nowMs),
          runningSinceMs: null,
        )
      : this;

  CardioRun resume(int nowMs) => status == CardioRunStatus.paused
      ? _copy(status: CardioRunStatus.running, runningSinceMs: nowMs)
      : this;

  /// Banks [counted] and restarts the running stretch at [nowMs]: used when
  /// the phone's clock went back, so the time shown never drops.
  CardioRun rebase(int nowMs, int counted) => status == CardioRunStatus.running
      ? _copy(elapsedMs: counted, runningSinceMs: nowMs)
      : this;

  /// Finished by the user: completed when the plan (or a stopwatch's
  /// target) was reached, otherwise ended early. A stopwatch without a
  /// target is always completed.
  CardioRun finish(int nowMs, CardioPlan plan) {
    if (!status.isOpen) return this;
    final settled = settle(nowMs, plan);
    if (settled.status == CardioRunStatus.completed) return settled;
    final ms = elapsedAt(nowMs);
    final goal = autoFinishSeconds(plan) ?? plan.durationSeconds;
    final reached = goal == null || ms >= goal * 1000;
    return _copy(
      status: reached ? CardioRunStatus.completed : CardioRunStatus.endedEarly,
      elapsedMs: ms,
      runningSinceMs: null,
      endedAtMs: nowMs,
    );
  }

  /// Not done. The time on the clock is kept for the record, but a skipped
  /// activity is never shown as completed.
  CardioRun skip(int nowMs) => status.isFinal
      ? this
      : _copy(
          status: CardioRunStatus.skipped,
          elapsedMs: elapsedAt(nowMs),
          runningSinceMs: null,
          endedAtMs: nowMs,
        );

  /// Ends a countdown or interval plan whose time is up, including one that
  /// ran out while the app was in the background or closed: the recorded
  /// time is the plan, and the end time is when it actually ran out. A run
  /// that reached [maxSeconds] is paused there.
  CardioRun settle(int nowMs, CardioPlan plan) {
    if (status != CardioRunStatus.running) return this;
    final limit = autoFinishSeconds(plan);
    final ms = elapsedAt(nowMs);
    if (limit != null && ms >= limit * 1000) {
      return _copy(
        status: CardioRunStatus.completed,
        elapsedMs: limit * 1000,
        runningSinceMs: null,
        endedAtMs: runningSinceMs! + (limit * 1000 - elapsedMs),
      );
    }
    if (ms >= maxSeconds * 1000) {
      return _copy(
        status: CardioRunStatus.paused,
        elapsedMs: maxSeconds * 1000,
        runningSinceMs: null,
      );
    }
    return this;
  }

  /// Closes an open run when its workout is finished.
  CardioRun close(int nowMs, CardioPlan? plan) => !status.isOpen
      ? this
      : plan == null
      ? _copy(
          status: CardioRunStatus.endedEarly,
          elapsedMs: elapsedAt(nowMs),
          runningSinceMs: null,
          endedAtMs: nowMs,
        )
      : finish(nowMs, plan);

  Map<String, Object?> toMap() => {
    'status': status.name,
    'elapsedMs': elapsedMs,
    if (runningSinceMs != null) 'runningSinceMs': runningSinceMs,
    if (startedAtMs != null) 'startedAtMs': startedAtMs,
    if (endedAtMs != null) 'endedAtMs': endedAtMs,
    if (plannedSeconds != null) 'plannedSeconds': plannedSeconds,
    if (mode != null) 'mode': mode!.name,
    if (name != null) 'name': name,
    if (exerciseId != null) 'exerciseId': exerciseId,
  };

  /// Never throws: a missing or malformed value reads as absent. A "running"
  /// record without its start time cannot keep counting, so it reads as
  /// paused at the time it had.
  static CardioRun fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const CardioRun();
    int? integer(String key) {
      final value = map[key];
      return value is num && value.isFinite ? value.toInt() : null;
    }

    String? text(String key) => map[key] is String ? map[key] as String : null;
    var status = CardioRunStatus.parse(map['status']);
    final since = integer('runningSinceMs');
    if (status == CardioRunStatus.running && since == null) {
      status = CardioRunStatus.paused;
    }
    return CardioRun(
      status: status,
      elapsedMs: math.max(0, integer('elapsedMs') ?? 0),
      runningSinceMs: status == CardioRunStatus.running ? since : null,
      startedAtMs: integer('startedAtMs'),
      endedAtMs: integer('endedAtMs'),
      plannedSeconds: integer('plannedSeconds'),
      mode: CardioMode.parse(map['mode']),
      name: text('name'),
      exerciseId: text('exerciseId'),
    );
  }

  CardioRun _copy({
    CardioRunStatus? status,
    int? elapsedMs,
    Object? runningSinceMs = _keep,
    Object? startedAtMs = _keep,
    Object? endedAtMs = _keep,
  }) => CardioRun(
    status: status ?? this.status,
    elapsedMs: elapsedMs ?? this.elapsedMs,
    runningSinceMs: runningSinceMs == _keep
        ? this.runningSinceMs
        : runningSinceMs as int?,
    startedAtMs: startedAtMs == _keep ? this.startedAtMs : startedAtMs as int?,
    endedAtMs: endedAtMs == _keep ? this.endedAtMs : endedAtMs as int?,
    plannedSeconds: plannedSeconds,
    mode: mode,
    name: name,
    exerciseId: exerciseId,
  );
}

const _keep = Object();
