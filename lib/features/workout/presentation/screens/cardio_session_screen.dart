import 'dart:async';
import 'dart:math' as math;

import 'package:ae_coaching/core/feedback/app_feedback.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_run.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/cardio_activity_visuals.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/cardio_timer_controller.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/rest_timer_sound.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/timer_format.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The icon, name and colour of an interval phase. The icon and the name
/// always come with the colour: the phase never depends on colour alone.
(IconData, String, Color) intervalPhaseLook(
  BuildContext context,
  IntervalPhaseKind kind,
) {
  final l10n = AppLocalizations.of(context)!;
  final scheme = Theme.of(context).colorScheme;
  final colors = context.appColors;
  return switch (kind) {
    IntervalPhaseKind.warmup => (
      Icons.wb_twilight,
      l10n.intervalPhaseWarmup,
      colors.warning,
    ),
    IntervalPhaseKind.work => (
      Icons.bolt,
      l10n.intervalPhaseWork,
      scheme.primary,
    ),
    IntervalPhaseKind.rest => (
      Icons.self_improvement,
      l10n.intervalPhaseRest,
      colors.success,
    ),
    IntervalPhaseKind.cooldown => (
      Icons.ac_unit,
      l10n.intervalPhaseCooldown,
      scheme.tertiary,
    ),
  };
}

/// A cardio activity during a workout (Stage 6): a large timer for
/// countdown and stopwatch plans, and phase by phase for intervals.
///
/// Nothing starts until the user taps Start. Each start, pause, resume,
/// finish and skip is saved with the session, so the timer is restored if
/// the app is put in the background, closed or killed.
class CardioSessionScreen extends StatefulWidget {
  const CardioSessionScreen({
    super.key,
    required this.workoutTitle,
    required this.activityName,
    required this.exerciseId,
    required this.plan,
    required this.initialRun,
    required this.onSave,
    this.nextActivityName,
    this.now,
  });

  final String workoutTitle;
  final String activityName;
  final String exerciseId;
  final CardioPlan plan;
  final CardioRun initialRun;
  final Future<void> Function(CardioRun run) onSave;

  /// The activity after this one in the workout, or null when it is last.
  final String? nextActivityName;

  /// Clock for tests (ms since epoch).
  final int Function()? now;

  @override
  State<CardioSessionScreen> createState() => _CardioSessionScreenState();
}

class _CardioSessionScreenState extends State<CardioSessionScreen>
    with WidgetsBindingObserver {
  /// Remembered while the app runs.
  static bool soundOn = true;

  late final CardioTimerController _timer;
  bool _awake = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A run that was never saved gets the plan's details for history; a
    // saved one is kept exactly as it is.
    final initial =
        widget.initialRun.status == CardioRunStatus.notStarted &&
            widget.initialRun.name == null
        ? CardioRun.planned(
            plan: widget.plan,
            name: widget.activityName,
            exerciseId: widget.exerciseId,
          )
        : widget.initialRun;
    _timer = CardioTimerController(
      plan: widget.plan,
      initial: initial,
      save: widget.onSave,
      onCue: _cue,
      now: widget.now,
    )..addListener(_keepAwake);
    _keepAwake();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background: show the right time and phase at once.
    if (state == AppLifecycleState.resumed) _timer.tick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer
      ..removeListener(_keepAwake)
      ..dispose();
    if (_awake) unawaited(ScreenAwake.set(false));
    super.dispose();
  }

  void _keepAwake() {
    final on = _timer.status == CardioRunStatus.running;
    if (on == _awake) return;
    _awake = on;
    unawaited(ScreenAwake.set(on));
  }

  void _cue(CardioCue cue) {
    if (!soundOn) return;
    // The notification sound follows the phone's sound mode, and the
    // vibration its touch-feedback setting.
    unawaited(RestTimerSound.play());
    unawaited(HapticFeedback.heavyImpact());
  }

  Future<bool> _guard(Future<bool> Function() action) async {
    try {
      return await action();
    } catch (_) {
      if (mounted) {
        AppFeedback.error(AppLocalizations.of(context)!.cardioTimerSaveError);
      }
      return false;
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            key: const ValueKey('cardio-confirm-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('cardio-confirm-ok'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  Future<void> _finish() async {
    final l10n = AppLocalizations.of(context)!;
    final result = _timer.preview();
    if (result.status == CardioRunStatus.endedEarly) {
      final planned =
          autoFinishSeconds(widget.plan) ?? widget.plan.durationSeconds ?? 0;
      final ok = await _confirm(
        l10n.cardioFinishEarlyTitle,
        l10n.cardioFinishEarlyBody(
          formatTimerClock(result.actualSeconds),
          formatTimerClock(planned),
        ),
        l10n.cardioTimerFinish,
      );
      if (!ok) return;
    }
    if (await _guard(_timer.finish) && mounted) {
      AppFeedback.success(
        l10n.cardioDoneMessage(
          widget.activityName,
          formatTimerClock(_timer.run.actualSeconds),
        ),
      );
    }
  }

  Future<void> _skip() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _confirm(
      l10n.cardioSkipConfirmTitle(widget.activityName),
      l10n.cardioSkipConfirmBody,
      l10n.cardioTimerSkip,
    );
    if (!ok) return;
    if (await _guard(_timer.skip) && mounted) {
      AppFeedback.info(l10n.cardioSkippedMessage(widget.activityName));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        foregroundColor: colors.textPrimary,
        title: Text(widget.workoutTitle),
        actions: [
          IconButton(
            key: const ValueKey('cardio-sound'),
            tooltip: soundOn ? l10n.cardioSoundOn : l10n.cardioSoundOff,
            icon: Icon(
              soundOn ? Icons.volume_up_outlined : Icons.volume_off_outlined,
            ),
            onPressed: () => setState(() => soundOn = !soundOn),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _timer,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    name: widget.activityName,
                    exerciseId: widget.exerciseId,
                    summary: cardioPlanSummary(l10n, widget.plan),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: _Dial(
                      timer: _timer,
                      size: math.min(constraints.maxWidth - 40, 280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PlanLine(timer: _timer),
                  const SizedBox(height: 24),
                  _Controls(
                    timer: _timer,
                    onFinish: _finish,
                    onSkip: _skip,
                    guard: _guard,
                  ),
                  const SizedBox(height: 20),
                  _NextActivity(name: widget.nextActivityName),
                  if (_timer.status.isOpen) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.cardioBackgroundNote,
                      key: const ValueKey('cardio-background-note'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.exerciseId,
    required this.summary,
  });

  final String name;
  final String exerciseId;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        CardioActivityAvatar(exerciseId: exerciseId, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(summary, style: TextStyle(color: colors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The large timer: the whole plan's progress for countdown and stopwatch,
/// the current phase's for intervals.
class _Dial extends StatelessWidget {
  const _Dial({required this.timer, required this.size});

  final CardioTimerController timer;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    final status = timer.status;
    final position = status.isFinal ? null : timer.position;

    IconData? icon;
    String label;
    int seconds;
    double? ring;
    var color = primary;
    String? below;
    if (status.isFinal) {
      seconds = timer.run.actualSeconds;
      label = cardioRunStatusLabel(l10n, status, seconds);
      icon = status == CardioRunStatus.skipped
          ? Icons.skip_next
          : Icons.check_circle_outline;
      color = status == CardioRunStatus.completed
          ? colors.success
          : colors.textMuted;
      ring = timer.progress ?? 1;
    } else if (position != null) {
      final look = intervalPhaseLook(context, position.phase.kind);
      icon = look.$1;
      label = look.$2;
      color = look.$3;
      seconds = position.remainingSeconds;
      ring = 1 - position.remainingSeconds / position.phase.seconds;
      final rounds = timer.plan.rounds;
      if (position.phase.round > 0 && rounds != null) {
        below = l10n.intervalRoundOf(position.phase.round, rounds);
      }
    } else if (timer.remainingSeconds != null) {
      label = l10n.cardioRemainingLabel;
      seconds = timer.remainingSeconds!;
      ring = timer.progress;
    } else {
      label = l10n.cardioElapsedLabel;
      seconds = timer.elapsedSeconds;
      ring = timer.progress ?? 0;
    }
    final progress = timer.progress;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              key: const ValueKey('cardio-dial'),
              value: (ring ?? 0).clamp(0.0, 1.0),
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              backgroundColor: colors.border,
              color: color,
              semanticsLabel: l10n.cardioTimerProgress,
              semanticsValue: progress == null
                  ? null
                  : '${(progress * 100).round()}%',
            ),
          ),
          Padding(
            padding: EdgeInsets.all(size * 0.14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  key: const ValueKey('cardio-phase'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                FittedBox(
                  child: Text(
                    formatTimerClock(seconds),
                    key: const ValueKey('cardio-time'),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (below != null)
                  Text(
                    below,
                    key: const ValueKey('cardio-round'),
                    style: TextStyle(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What was planned, and for intervals the phase that comes next.
class _PlanLine extends StatelessWidget {
  const _PlanLine({required this.timer});

  final CardioTimerController timer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final plan = timer.plan;
    final duration = cardioDurationLabel(l10n, plan);
    final planned = plan.mode == CardioMode.stopwatch
        ? (duration == null
              ? l10n.cardioNoTarget
              : l10n.cardioTargetValue(duration))
        : (duration == null ? null : l10n.cardioPlannedValue(duration));
    final position = timer.status.isFinal ? null : timer.position;
    final next = position?.next;
    String? nextPhase;
    if (position != null) {
      nextPhase = next == null
          ? l10n.intervalLastPhase
          : l10n.intervalNextPhase(
              intervalPhaseLook(context, next.kind).$2,
              formatTimerClock(next.seconds),
            );
    }
    return Column(
      children: [
        if (planned != null)
          Text(
            planned,
            key: const ValueKey('cardio-planned'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (nextPhase != null) ...[
          const SizedBox(height: 6),
          Text(
            nextPhase,
            key: const ValueKey('cardio-next-phase'),
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted),
          ),
        ],
        if (timer.phases.isNotEmpty || timer.remainingSeconds != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const ValueKey('cardio-overall'),
              value: timer.progress ?? 0,
              minHeight: 6,
              backgroundColor: colors.border,
              semanticsLabel: l10n.cardioTimerProgress,
            ),
          ),
        ],
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.timer,
    required this.onFinish,
    required this.onSkip,
    required this.guard,
  });

  final CardioTimerController timer;
  final VoidCallback onFinish;
  final VoidCallback onSkip;
  final Future<bool> Function(Future<bool> Function() action) guard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = timer.busy;
    const tall = Size.fromHeight(56);
    final skip = TextButton.icon(
      key: const ValueKey('cardio-skip'),
      onPressed: busy ? null : onSkip,
      icon: const Icon(Icons.skip_next),
      label: Text(l10n.cardioTimerSkip),
    );
    final finish = OutlinedButton.icon(
      key: const ValueKey('cardio-finish'),
      onPressed: busy ? null : onFinish,
      style: OutlinedButton.styleFrom(minimumSize: tall),
      icon: const Icon(Icons.flag_outlined),
      label: Text(l10n.cardioTimerFinish),
    );
    switch (timer.status) {
      case CardioRunStatus.notStarted:
      case CardioRunStatus.skipped:
        final again = timer.status == CardioRunStatus.skipped;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              key: const ValueKey('cardio-start'),
              onPressed: busy ? null : () => guard(timer.start),
              style: FilledButton.styleFrom(minimumSize: tall),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                again ? l10n.cardioTimerStartAgain : l10n.cardioTimerStart,
              ),
            ),
            if (!again) ...[const SizedBox(height: 8), skip],
            if (again) ...[const SizedBox(height: 8), const _BackButton()],
          ],
        );
      case CardioRunStatus.running:
      case CardioRunStatus.paused:
        final running = timer.status == CardioRunStatus.running;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: running
                      ? FilledButton.tonalIcon(
                          key: const ValueKey('cardio-pause'),
                          onPressed: busy ? null : () => guard(timer.pause),
                          style: FilledButton.styleFrom(minimumSize: tall),
                          icon: const Icon(Icons.pause_rounded),
                          label: Text(l10n.cardioTimerPause),
                        )
                      : FilledButton.icon(
                          key: const ValueKey('cardio-resume'),
                          onPressed: busy ? null : () => guard(timer.resume),
                          style: FilledButton.styleFrom(minimumSize: tall),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(l10n.cardioTimerResume),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(child: finish),
              ],
            ),
            const SizedBox(height: 8),
            skip,
          ],
        );
      case CardioRunStatus.completed:
      case CardioRunStatus.endedEarly:
        return const _BackButton(filled: true);
    }
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.filled = false});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final label = Text(AppLocalizations.of(context)!.cardioBackToWorkout);
    void back() => Navigator.of(context).maybePop();
    return filled
        ? FilledButton(
            key: const ValueKey('cardio-back'),
            onPressed: back,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: label,
          )
        : TextButton(
            key: const ValueKey('cardio-back'),
            onPressed: back,
            child: label,
          );
  }
}

class _NextActivity extends StatelessWidget {
  const _NextActivity({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Container(
      key: const ValueKey('cardio-next-activity'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            name == null ? Icons.flag_circle_outlined : Icons.arrow_forward,
            color: colors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name == null
                  ? l10n.cardioLastActivity
                  : l10n.cardioNextActivity(name!),
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
