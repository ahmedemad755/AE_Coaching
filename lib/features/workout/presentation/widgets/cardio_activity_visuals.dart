import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/repositories/cardio_library_catalog.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
import 'package:ae_coaching/features/workout/domain/cardio_library.dart';
import 'package:ae_coaching/features/workout/domain/cardio_run.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/timer_format.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// The icon of a cardio activity (bundled Material icons, no assets).
IconData cardioActivityIcon(String exerciseId) => switch (exerciseId) {
  'repdb:treadmill-running' ||
  'repdb:running' ||
  'repdb:high-knees' => Icons.directions_run,
  'repdb:incline-treadmill-walk' || 'repdb:walking' => Icons.directions_walk,
  'repdb:stationary-bike' || CardioLibrary.airBike => Icons.pedal_bike,
  'repdb:cycling' => Icons.directions_bike,
  'repdb:elliptical-trainer' => Icons.fitness_center,
  'repdb:stair-climber' || 'repdb:step-ups' => Icons.stairs,
  'repdb:rowing-machine' => Icons.rowing,
  'repdb:ski-erg' => Icons.downhill_skiing,
  'repdb:battle-ropes' || 'repdb:battle-rope-double-slam' => Icons.waves,
  'repdb:jump-rope' || 'repdb:burpees' => Icons.sports_gymnastics,
  'repdb:jumping-jacks' => Icons.accessibility_new,
  'repdb:mountain-climbers' => Icons.terrain,
  'repdb:heel-flicks' => Icons.directions_run,
  CardioLibrary.shadowBoxing => Icons.sports_mma,
  CardioLibrary.hiking => Icons.hiking,
  CardioLibrary.swimming => Icons.pool,
  _ => Icons.monitor_heart,
};

/// The app-defined activities' names, in both languages (stored with the
/// activity in the language of the app when it is added).
AppDefinedCardioNames appDefinedCardioNames() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));
  return {
    CardioLibrary.shadowBoxing: (
      en: en.cardioShadowBoxing,
      ar: ar.cardioShadowBoxing,
    ),
    CardioLibrary.hiking: (en: en.cardioHiking, ar: ar.cardioHiking),
    CardioLibrary.swimming: (en: en.cardioSwimming, ar: ar.cardioSwimming),
  };
}

String cardioCategoryLabel(AppLocalizations l10n, CardioCategory? category) =>
    switch (category) {
      CardioCategory.machines => l10n.cardioCategoryMachines,
      CardioCategory.bodyweight => l10n.cardioCategoryBodyweight,
      CardioCategory.outdoor => l10n.cardioCategoryOutdoor,
      null => l10n.cardioCategoryMine,
    };

String cardioModeLabel(AppLocalizations l10n, CardioMode mode) =>
    switch (mode) {
      CardioMode.countdown => l10n.cardioModeCountdown,
      CardioMode.stopwatch => l10n.cardioModeStopwatch,
      CardioMode.intervals => l10n.cardioModeIntervals,
    };

/// The planned duration, in whole minutes (at least one), or null.
String? cardioDurationLabel(AppLocalizations l10n, CardioPlan plan) {
  final seconds = plan.plannedSeconds;
  if (seconds == null || seconds <= 0) return null;
  return l10n.cardioDurationMinutes(((seconds + 59) ~/ 60).clamp(1, 1000));
}

/// "Countdown · 20 min" (the mode alone when there is no duration).
String cardioPlanSummary(AppLocalizations l10n, CardioPlan plan) {
  final mode = cardioModeLabel(l10n, plan.mode);
  final duration = cardioDurationLabel(l10n, plan);
  return duration == null ? mode : l10n.cardioPlanSummary(mode, duration);
}

/// A cardio activity's icon in a tinted rounded square, optionally with its
/// place in the day (same footprint as the exercise thumbnails).
class CardioActivityAvatar extends StatelessWidget {
  const CardioActivityAvatar({
    super.key,
    required this.exerciseId,
    this.index,
    this.size = 52,
  });

  final String exerciseId;
  final int? index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final colors = context.appColors;
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
      ),
      child: Icon(
        cardioActivityIcon(exerciseId),
        color: primary,
        size: size * 0.5,
      ),
    );
    final number = index;
    if (number == null) return ExcludeSemantics(child: avatar);
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            PositionedDirectional(
              top: -4,
              start: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  '$number',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where a cardio timer is, with [seconds] on it: "In progress · 05:07",
/// "Done · 20:00", "Skipped"… One wording for the workout, the timer and
/// the summary.
String cardioRunStatusLabel(
  AppLocalizations l10n,
  CardioRunStatus status,
  int seconds,
) {
  final time = formatTimerClock(seconds);
  return switch (status) {
    CardioRunStatus.notStarted => l10n.cardioStatusNotStarted,
    CardioRunStatus.running => l10n.cardioStatusRunning(time),
    CardioRunStatus.paused => l10n.cardioStatusPaused(time),
    CardioRunStatus.completed => l10n.cardioStatusCompleted(time),
    CardioRunStatus.endedEarly => l10n.cardioStatusEndedEarly(time),
    CardioRunStatus.skipped => l10n.cardioStatusSkipped,
  };
}
