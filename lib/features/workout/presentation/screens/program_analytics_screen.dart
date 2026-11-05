import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/domain/services/program_analytics_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_analytics_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_consistency_cubit.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

/// Route arguments for [ProgramAnalyticsScreen].
class ProgramAnalyticsArgs {
  final WorkoutProgram program;
  const ProgramAnalyticsArgs({required this.program});
}

String _fmt(double value) =>
    value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);

/// Phase 15's Program → Day → Exercise analytics browser. Every
/// exercise row shown here is scoped to exactly one workout day
/// (`workoutTemplateId`) — see [ProgramAnalyticsService]'s docs for why
/// Push 1 and Push 2 can never merge here, even for exercises sharing
/// the same name.
class ProgramAnalyticsScreen extends StatefulWidget {
  final WorkoutProgram program;
  const ProgramAnalyticsScreen({super.key, required this.program});

  @override
  State<ProgramAnalyticsScreen> createState() => _ProgramAnalyticsScreenState();
}

class _ProgramAnalyticsScreenState extends State<ProgramAnalyticsScreen> {
  static const Color _blue = Color(0xff2f80ed);
  String? _selectedTemplateId;
  String? _selectedExerciseName;

  @override
  void initState() {
    super.initState();
    context.read<ProgramAnalyticsCubit>().loadAnalytics(widget.program.id);
    context.read<ProgramConsistencyCubit>().loadConsistency(widget.program.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: isDark ? colors.canvas : _blue,
        foregroundColor: isDark ? colors.textPrimary : Colors.white,
        title: Text(l10n.programAnalyticsTitle),
      ),
      body: BlocBuilder<ProgramAnalyticsCubit, ProgramAnalyticsState>(
        builder: (context, state) {
          if (state is ProgramAnalyticsError) {
            return Center(
              child: Text(state.message, style: TextStyle(color: colors.error)),
            );
          }
          if (state is! ProgramAnalyticsLoaded) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          final days = state.summary.days;
          final hasAnyData = days.any((d) => d.completedSessionsCount > 0);

          if (!hasAnyData) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.bar_chart,
                  color: Theme.of(context).colorScheme.primary,
                  size: 40,
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.noAnalyticsYetTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.noAnalyticsYetSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const _ConsistencyCard(),
              const SizedBox(height: 8),
              _buildProgressionBrowser(context, days),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressionBrowser(
    BuildContext context,
    List<WorkoutDayAnalyticsSummary> days,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final day =
        days
            .where((item) => item.workoutTemplateId == _selectedTemplateId)
            .firstOrNull ??
        days.first;
    final selectedExercise =
        day.exercises
            .where(
              (item) => item.normalizedExerciseName == _selectedExerciseName,
            )
            .firstOrNull ??
        day.exercises.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('program-analytics-day-${day.workoutTemplateId}'),
          initialValue: day.workoutTemplateId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.analyticsSelectDay,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: [
            for (final item in days)
              DropdownMenuItem(
                value: item.workoutTemplateId,
                child: Text(
                  item.workoutTemplateName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() {
            _selectedTemplateId = value;
            _selectedExerciseName = null;
          }),
        ),
        if (day.completedSessionsCount > 0) ...[
          const SizedBox(height: 6),
          Text(
            '${l10n.sessionsLoggedLabel(day.completedSessionsCount)} · ${l10n.averageVolumeLabel}: ${_fmt(day.averageSessionVolume)} ${l10n.kgUnit}',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        if (day.exercises.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.noExercisesForDayYetBody,
              style: TextStyle(color: colors.textMuted, fontSize: 13),
            ),
          )
        else ...[
          DropdownButtonFormField<String>(
            key: ValueKey(
              'program-analytics-exercise-${selectedExercise?.normalizedExerciseName}',
            ),
            initialValue: selectedExercise?.normalizedExerciseName,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.analyticsSelectExercise,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            items: [
              for (final item in day.exercises)
                DropdownMenuItem(
                  value: item.normalizedExerciseName,
                  child: Text(
                    item.exerciseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _selectedExerciseName = value),
          ),
          const SizedBox(height: 12),
          if (selectedExercise != null) ...[
            Text(
              selectedExercise.exerciseName,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.exerciseBestLatestSummary(
                _fmt(selectedExercise.bestWeight),
                _fmt(selectedExercise.latestVolume),
              ),
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _MetricProgressCard(
              title: l10n.analyticsWeightTitle,
              points: selectedExercise.weightProgression,
              previous: selectedExercise.previousSession?.maxWeight,
              latest: selectedExercise.latestSession?.maxWeight,
              previousDate: selectedExercise.previousSession?.completedAt,
              latestDate: selectedExercise.latestSession?.completedAt,
              absoluteChange: selectedExercise.weightDelta,
              percentChange: selectedExercise.weightDeltaPercent,
              unit: l10n.kgUnit,
              color: colors.chartSeries[0],
            ),
            _MetricProgressCard(
              title: l10n.analyticsRepsTitle,
              subtitle: selectedExercise.comparableRepsWeight == null
                  ? null
                  : l10n.analyticsRepsAtWeight(
                      _fmt(selectedExercise.comparableRepsWeight!),
                    ),
              points: selectedExercise.repsProgression,
              previous: selectedExercise.previousComparableReps?.toDouble(),
              latest: selectedExercise.latestComparableReps?.toDouble(),
              previousDate: selectedExercise.previousSession?.completedAt,
              latestDate: selectedExercise.latestSession?.completedAt,
              absoluteChange: selectedExercise.repsDelta,
              percentChange: selectedExercise.repsDeltaPercent,
              unit: l10n.analyticsRepsUnit,
              emptyMessage: selectedExercise.previousSession == null
                  ? l10n.analyticsNeedMoreSessions
                  : l10n.analyticsNoComparableReps,
              color: colors.chartSeries[3],
            ),
            _MetricProgressCard(
              title: l10n.analyticsVolumeTitle,
              points: selectedExercise.volumeProgression,
              previous: selectedExercise.previousSession?.volume,
              latest: selectedExercise.latestSession?.volume,
              previousDate: selectedExercise.previousSession?.completedAt,
              latestDate: selectedExercise.latestSession?.completedAt,
              absoluteChange: selectedExercise.volumeDelta,
              percentChange: selectedExercise.volumeDeltaPercent,
              unit: l10n.analyticsVolumeUnit,
              color: colors.chartSeries[1],
            ),
          ],
        ],
      ],
    );
  }
}

class _ConsistencyCard extends StatelessWidget {
  const _ConsistencyCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<ProgramConsistencyCubit, ProgramConsistencyState>(
      builder: (context, state) {
        if (state is! ProgramConsistencyLoaded) return const SizedBox.shrink();
        final summary = state.summary;
        final colors = context.appColors;
        if (summary.totalCompletedSessions == 0) return const SizedBox.shrink();

        return Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.consistencyTitle,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    _ConsistencyStat(
                      label: l10n.currentWeekStreakLabel,
                      value: l10n.weeksUnit(summary.currentWeekStreak),
                    ),
                    _ConsistencyStat(
                      label: l10n.longestWeekStreakLabel,
                      value: l10n.weeksUnit(summary.longestWeekStreak),
                    ),
                    _ConsistencyStat(
                      label: l10n.averagePerWeekLabel,
                      value: _fmt(summary.averageSessionsPerWeek),
                    ),
                    if (summary.daysSinceLastSession != null)
                      _ConsistencyStat(
                        label: l10n.daysSinceLastSessionLabel,
                        value: l10n.daysAgoLabel(summary.daysSinceLastSession!),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConsistencyStat extends StatelessWidget {
  final String label;
  final String value;
  const _ConsistencyStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        Text(label, style: TextStyle(color: colors.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _MetricProgressCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<ExerciseProgressionPoint> points;
  final double? previous;
  final double? latest;
  final DateTime? previousDate;
  final DateTime? latestDate;
  final double? absoluteChange;
  final double? percentChange;
  final String unit;
  final String? emptyMessage;
  final Color color;

  const _MetricProgressCard({
    required this.title,
    this.subtitle,
    required this.points,
    required this.previous,
    required this.latest,
    required this.previousDate,
    required this.latestDate,
    required this.absoluteChange,
    required this.percentChange,
    required this.unit,
    this.emptyMessage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toString();
    final canCompare = previous != null && latest != null;
    final change = absoluteChange == null
        ? null
        : '${absoluteChange! > 0 ? '+' : ''}${_fmt(absoluteChange!)}';

    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
            if (canCompare) ...[
              const SizedBox(height: 8),
              Text(
                l10n.analyticsPreviousValue(
                  DateFormat.MMMd(locale).format(previousDate!),
                  _fmt(previous!),
                  unit,
                ),
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
              Text(
                l10n.analyticsLatestValue(
                  DateFormat.MMMd(locale).format(latestDate!),
                  _fmt(latest!),
                  unit,
                ),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.analyticsAbsoluteChange(change!, unit),
                style: TextStyle(
                  color: absoluteChange! >= 0 ? colors.success : colors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                percentChange == null
                    ? l10n.analyticsPercentageUnavailable
                    : l10n.analyticsPercentChange(
                        '${percentChange! > 0 ? '+' : ''}${_fmt(percentChange!)}',
                      ),
                style: TextStyle(color: colors.textMuted, fontSize: 11),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  points.isEmpty
                      ? (emptyMessage ?? l10n.analyticsNeedMoreSessions)
                      : l10n.analyticsNeedMoreSessions,
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ),
            if (points.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ProgressionLineChart(points: points, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressionLineChart extends StatelessWidget {
  final List<ExerciseProgressionPoint> points;
  final Color color;

  const _ProgressionLineChart({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final colors = context.appColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = math
            .max(
              constraints.maxWidth,
              points.length <= 1 ? 96.0 : (points.length - 1) * 64.0 + 48.0,
            )
            .toDouble();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            child: Column(
              children: [
                SizedBox(
                  height: 132,
                  child: CustomPaint(
                    size: Size(chartWidth, 132),
                    painter: _ProgressionPainter(
                      points: points,
                      color: color,
                      gridColor: colors.chartGrid,
                    ),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: Stack(
                    children: [
                      for (var index = 0; index < points.length; index++)
                        Positioned(
                          left: _pointX(chartWidth, points.length, index) - 30,
                          width: 60,
                          child: Text(
                            DateFormat.MMMd(locale).format(points[index].date),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

double _pointX(double width, int count, int index) {
  if (count <= 1) return width / 2;
  return 14 + (width - 28) * index / (count - 1);
}

class _ProgressionPainter extends CustomPainter {
  final List<ExerciseProgressionPoint> points;
  final Color color;
  final Color gridColor;

  const _ProgressionPainter({
    required this.points,
    required this.color,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const top = 10.0;
    const bottom = 12.0;
    const left = 14.0;
    const right = 14.0;
    final plotHeight = size.height - top - bottom;
    final values = points.map((point) => point.value).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = maxValue == minValue ? 1.0 : maxValue - minValue;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row++) {
      final y = top + plotHeight * row / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      final x = _pointX(size.width, points.length, index);
      final y =
          top +
          plotHeight -
          (points[index].value - minValue) / range * plotHeight;
      offsets.add(Offset(x, y));
    }
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(path, linePaint);
    }
    final pointPaint = Paint()..color = color;
    for (final offset in offsets) {
      canvas.drawCircle(offset, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressionPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}
