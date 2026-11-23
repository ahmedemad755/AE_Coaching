import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/profile/domain/my_progress_summary_service.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/domain/services/personal_record_detection_service.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

// Shared building blocks of the progress dashboard and its detail screens.

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toString();

String formatProgressNumber(BuildContext context, num value) =>
    latinDigits(NumberFormat('#,##0.##', _locale(context)).format(value));

/// Western digits everywhere on the progress screens: Arabic dates would
/// otherwise use Arabic-Indic digits next to Western counts and weights.
String latinDigits(String value) => value.replaceAllMapped(
  RegExp('[٠-٩۰-۹]'),
  (m) => '${m[0]!.codeUnitAt(0) & 0xF}',
);

/// Formats [date] with [format] (built for the current locale) in Western
/// digits.
String formatProgressDate(
  BuildContext context,
  DateFormat Function(String locale) format,
  DateTime date,
) => latinDigits(format(_locale(context)).format(date));

/// "100 kg × 5": the heaviest-weight record and the set it was lifted in.
String formatHeaviestWeight(
  BuildContext context,
  PersonalRecordResult record,
) => AppLocalizations.of(context)!.progressWeightTimesReps(
  formatProgressNumber(context, record.recordSet.weight),
  record.recordSet.reps,
);

/// "80 kg × 10 = 800 kg": a best-set-volume record, with its calculation.
String formatSetVolume(BuildContext context, PersonalRecordResult record) =>
    AppLocalizations.of(context)!.progressSetVolumeFormula(
      formatProgressNumber(context, record.recordSet.weight),
      record.recordSet.reps,
      formatProgressNumber(context, record.newBest),
    );

String? formatWorkoutDuration(BuildContext context, WorkoutSession session) {
  final end = session.completedAt;
  if (end == null) return null;
  final duration = end.difference(session.startedAt);
  if (duration.isNegative || duration.inMinutes < 1 || duration.inHours >= 24) {
    return null;
  }
  final l10n = AppLocalizations.of(context)!;
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours > 0
      ? l10n.durationHoursMinutesLabel(hours, minutes)
      : l10n.durationMinutesOnlyLabel(minutes);
}

/// Rounded, bordered surface used by every progress card.
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.highlighted = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  /// Makes the whole card tappable (with its ripple clipped to the shape).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    final content = Padding(padding: padding, child: child);
    return Material(
      color: highlighted
          ? primary.withValues(alpha: 0.12)
          : colors.surfaceRaised,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highlighted ? primary.withValues(alpha: 0.7) : colors.border,
          width: highlighted ? 1.4 : 1,
        ),
      ),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// A section title with an optional subtitle and "View all" action.
class ProgressSectionHeader extends StatelessWidget {
  const ProgressSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onViewAll,
    this.viewAllKey,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;
  final Key? viewAllKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onViewAll != null)
            TextButton(
              key: viewAllKey,
              onPressed: onViewAll,
              child: Text(AppLocalizations.of(context)!.progressViewAll),
            ),
        ],
      ),
    );
  }
}

/// One summary number with what it counts and over which period.
class ProgressMetricCard extends StatelessWidget {
  const ProgressMetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.caption,
    this.highlighted = false,
  });

  final IconData icon;
  final int value;
  final String label;
  final String caption;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      label: l10n.progressMetricSemantics(label, value, caption),
      child: ExcludeSemantics(
        child: ProgressCard(
          highlighted: highlighted,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                formatProgressNumber(context, value),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered icon + message, for empty lists and sections.
class ProgressEmptyState extends StatelessWidget {
  const ProgressEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.compact = false,
  });

  final IconData icon;
  final String message;

  /// Inline in a dashboard section instead of filling a screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    if (compact) {
      return ProgressCard(
        child: Row(
          children: [
            Icon(icon, color: colors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// One bar of [ProgressActivityChart].
class ProgressActivityBar {
  const ProgressActivityBar({
    required this.label,
    required this.sublabel,
    required this.semanticsPeriod,
    required this.count,
    this.current = false,
  });

  /// E.g. the weekday ("Sat") or "Today".
  final String label;

  /// E.g. the date ("22/11").
  final String sublabel;

  /// The full period read by screen readers ("Saturday 22 November").
  final String semanticsPeriod;
  final int count;

  /// Today / this week: emphasized.
  final bool current;

  static List<ProgressActivityBar> days(
    BuildContext context,
    List<DailyActivityPoint> points,
    DateTime now,
  ) {
    final locale = _locale(context);
    final l10n = AppLocalizations.of(context)!;
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (final point in points)
        ProgressActivityBar(
          label: point.day == today
              ? l10n.progressTodayLabel
              : DateFormat.E(locale).format(point.day),
          sublabel: latinDigits(DateFormat('d/M', locale).format(point.day)),
          semanticsPeriod: latinDigits(
            DateFormat.MMMMEEEEd(locale).format(point.day),
          ),
          count: point.completedCount,
          current: point.day == today,
        ),
    ];
  }

  static List<ProgressActivityBar> weeks(
    BuildContext context,
    List<WeeklyActivityPoint> points,
  ) {
    final locale = _locale(context);
    final l10n = AppLocalizations.of(context)!;
    return [
      for (var i = 0; i < points.length; i++)
        ProgressActivityBar(
          label: latinDigits(
            DateFormat('d/M', locale).format(points[i].weekStart),
          ),
          sublabel: latinDigits(
            DateFormat(
              'd/M',
              locale,
            ).format(points[i].weekStart.add(const Duration(days: 6))),
          ),
          semanticsPeriod: l10n.progressWeekOf(
            latinDigits(DateFormat.MMMMd(locale).format(points[i].weekStart)),
          ),
          count: points[i].completedCount,
          current: i == points.length - 1,
        ),
    ];
  }
}

/// Bars in chronological order (reading direction: right to left in
/// Arabic), each with its value, zero days visibly zero, and one
/// screen-reader label per bar.
class ProgressActivityChart extends StatelessWidget {
  const ProgressActivityChart({super.key, required this.bars});

  final List<ProgressActivityBar> bars;

  static const double _barArea = 96;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    final primary = theme.colorScheme.primary;
    final maxCount = bars.fold<int>(
      0,
      (max, bar) => bar.count > max ? bar.count : max,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final bar in bars)
          Expanded(
            child: Semantics(
              container: true,
              label: l10n.progressChartBarSemantics(
                bar.semanticsPeriod,
                bar.count,
              ),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatProgressNumber(context, bar.count),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: bar.count == 0 ? colors.textMuted : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: _barArea,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 34),
                            child: bar.count == 0
                                ? Container(
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: colors.border,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  )
                                : Container(
                                    height: (_barArea * bar.count / maxCount)
                                        .clamp(14.0, _barArea),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color.lerp(
                                            primary,
                                            Colors.white,
                                            0.35,
                                          )!,
                                          primary,
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          bar.label,
                          maxLines: 1,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: bar.current
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: bar.current ? primary : null,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          bar.sublabel,
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A round icon badge used as the leading element of progress tiles.
class _TileBadge extends StatelessWidget {
  const _TileBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

/// A personal-record achievement: exercise, what kind of record, its value
/// and when it was set.
class PersonalRecordTile extends StatelessWidget {
  const PersonalRecordTile({super.key, required this.record});

  final PersonalRecordResult record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    final isWeight = record.type == PersonalRecordType.heaviestWeight;
    final kind = isWeight
        ? l10n.progressHeaviestWeightRecord
        : l10n.progressBestSetVolumeLabel;
    final value = isWeight
        ? formatHeaviestWeight(context, record)
        : formatSetVolume(context, record);
    final date = formatProgressDate(
      context,
      DateFormat.yMMMd,
      record.recordSet.date,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProgressCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _TileBadge(
              icon: Icons.emoji_events_outlined,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.exerciseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kind,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              date,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A completed workout: name, date, duration and (optionally) its program.
class WorkoutSessionTile extends StatelessWidget {
  const WorkoutSessionTile({
    super.key,
    required this.session,
    this.programName,
    this.onTap,
  });

  final WorkoutSession session;
  final String? programName;

  /// Opens the workout day's history; null when that day no longer exists.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final completed = MyProgressSummaryService.completedAt(session);
    final details = [
      formatProgressDate(context, DateFormat.MMMEd, completed),
      ?formatWorkoutDuration(context, session),
      ?programName,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProgressCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _TileBadge(
              icon: Icons.check_circle_outline,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.workoutNameSnapshot,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    details,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// A program, leading to its analytics.
class ProgramAnalyticsTile extends StatelessWidget {
  const ProgramAnalyticsTile({
    super.key,
    required this.program,
    required this.onTap,
  });

  final WorkoutProgram program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProgressCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _TileBadge(
              icon: program.isActive ? Icons.flag_outlined : Icons.insights,
              color: program.isActive
                  ? colors.success
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (program.isActive)
                    Text(
                      l10n.activeProgramLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
