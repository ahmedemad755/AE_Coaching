import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/profile/domain/my_progress_summary_service.dart';
import 'package:ae_coaching/features/profile/domain/personal_record_book.dart';
import 'package:ae_coaching/features/profile/presentation/progress/personal_records_screen.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_programs_screen.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_widgets.dart';
import 'package:ae_coaching/features/profile/presentation/progress/workout_history_screen.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/domain/services/week_boundary_util.dart';
import 'package:ae_coaching/features/workout/presentation/screens/program_analytics_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_template_history_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Everything the progress screens show, loaded once by [MyProgressScreen]
/// and handed to the detail screens (no second read).
class ProgressDashboardData {
  ProgressDashboardData({
    required this.summary,
    required this.records,
    required List<WorkoutProgram> programs,
    required List<WorkoutTemplate> templates,
  }) : programs = List<WorkoutProgram>.unmodifiable(
         <WorkoutProgram>[...programs]..sort(_activeThenNewest),
       ),
       templatesById = {
         for (final template in templates) template.id: template,
       },
       programsById = {for (final program in programs) program.id: program};

  ProgressDashboardData.empty()
    : this(
        summary: MyProgressSummary(
          completedWorkouts: 0,
          completedThisWeek: 0,
          completedThisMonth: 0,
          weeklyActivity: const [],
        ),
        records: PersonalRecordBook.empty,
        programs: const [],
        templates: const [],
      );

  final MyProgressSummary summary;
  final PersonalRecordBook records;

  /// Active program first, then newest first.
  final List<WorkoutProgram> programs;
  final Map<String, WorkoutTemplate> templatesById;
  final Map<String, WorkoutProgram> programsById;

  /// Completed workouts, newest first.
  List<WorkoutSession> get sessions => summary.completedSessions;

  bool get isEmpty => sessions.isEmpty && programs.isEmpty && records.isEmpty;

  static int _activeThenNewest(WorkoutProgram a, WorkoutProgram b) {
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  }
}

/// Opens the history of the workout day a session belongs to (the existing
/// workout details), or null when that day no longer exists.
VoidCallback? workoutDayHistoryOpener(
  BuildContext context,
  WorkoutSession session,
  Map<String, WorkoutTemplate> templatesById,
) {
  final template = templatesById[session.workoutTemplateId];
  if (template == null) return null;
  return () => Navigator.pushNamed(
    context,
    AppNavigator.workoutTemplateHistory,
    arguments: WorkoutTemplateHistoryArgs(template: template),
  );
}

void openProgramAnalytics(BuildContext context, WorkoutProgram program) =>
    Navigator.pushNamed(
      context,
      AppNavigator.programAnalytics,
      arguments: ProgramAnalyticsArgs(program: program),
    );

enum _ActivityRange { days, weeks }

/// The progress overview: summary numbers, the activity chart and short
/// previews (latest records, recent workouts, programs), each with a
/// "View all" screen, so the dashboard stays short however long the
/// history grows.
class ProgressDashboard extends StatefulWidget {
  const ProgressDashboard({super.key, required this.data, required this.now});

  static const recordsShown = 3;
  static const workoutsShown = 2;
  static const programsShown = 2;

  final ProgressDashboardData data;
  final DateTime now;

  @override
  State<ProgressDashboard> createState() => _ProgressDashboardState();
}

class _ProgressDashboardState extends State<ProgressDashboard> {
  _ActivityRange _range = _ActivityRange.days;

  ProgressDashboardData get _data => widget.data;

  void _openRecords() => Navigator.pushNamed(
    context,
    AppNavigator.personalRecords,
    arguments: PersonalRecordsArgs(records: _data.records),
  );

  void _openHistory() => Navigator.pushNamed(
    context,
    AppNavigator.workoutHistory,
    arguments: WorkoutHistoryArgs(data: _data),
  );

  void _openPrograms() => Navigator.pushNamed(
    context,
    AppNavigator.progressPrograms,
    arguments: ProgressProgramsArgs(programs: _data.programs),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessions = _data.sessions;
    final programs = _data.programs;
    return ListView(
      key: const ValueKey('progress-dashboard'),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _metrics(context),
        const SizedBox(height: 16),
        _activity(context),
        const SizedBox(height: 24),
        ProgressSectionHeader(
          title: l10n.progressLatestRecords,
          onViewAll: _data.records.isEmpty ? null : _openRecords,
          viewAllKey: const ValueKey('progress-view-all-records'),
        ),
        if (_data.records.isEmpty)
          ProgressEmptyState(
            compact: true,
            icon: Icons.emoji_events_outlined,
            message: l10n.progressRecordsEmpty,
          )
        else
          for (final record in _data.records.latest(
            ProgressDashboard.recordsShown,
          ))
            PersonalRecordTile(record: record),
        const SizedBox(height: 20),
        ProgressSectionHeader(
          title: l10n.progressRecentWorkoutsSection,
          onViewAll: sessions.isEmpty ? null : _openHistory,
          viewAllKey: const ValueKey('progress-view-all-workouts'),
        ),
        if (sessions.isEmpty)
          ProgressEmptyState(
            compact: true,
            icon: Icons.history,
            message: l10n.progressNoCompletedWorkouts,
          )
        else
          for (final session in sessions.take(ProgressDashboard.workoutsShown))
            WorkoutSessionTile(
              session: session,
              programName: _data.programsById[session.programId]?.name,
              onTap: workoutDayHistoryOpener(
                context,
                session,
                _data.templatesById,
              ),
            ),
        if (programs.isNotEmpty) ...[
          const SizedBox(height: 20),
          ProgressSectionHeader(
            title: l10n.progressProgramAnalytics,
            onViewAll: programs.length > ProgressDashboard.programsShown
                ? _openPrograms
                : null,
            viewAllKey: const ValueKey('progress-view-all-programs'),
          ),
          for (final program in programs.take(ProgressDashboard.programsShown))
            ProgramAnalyticsTile(
              program: program,
              onTap: () => openProgramAnalytics(context, program),
            ),
        ],
      ],
    );
  }

  Widget _metrics(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final summary = _data.summary;
    final now = widget.now;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ProgressMetricCard(
              key: const ValueKey('progress-metric-total'),
              icon: Icons.fitness_center,
              value: summary.completedWorkouts,
              label: l10n.progressCompletedWorkoutsLabel,
              caption: l10n.progressAllTimeCaption,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ProgressMetricCard(
              key: const ValueKey('progress-metric-week'),
              icon: Icons.bar_chart_rounded,
              value: summary.completedThisWeek,
              label: l10n.progressThisWeekLabel,
              caption: l10n.progressSinceCaption(
                DateFormat.EEEE(locale).format(startOfWeek(now)),
              ),
              highlighted: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ProgressMetricCard(
              key: const ValueKey('progress-metric-month'),
              icon: Icons.calendar_month_outlined,
              value: summary.completedThisMonth,
              label: l10n.progressThisMonthLabel,
              caption: l10n.progressSinceCaption(
                formatProgressDate(
                  context,
                  DateFormat.MMMd,
                  DateTime(now.year, now.month),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activity(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final days = _range == _ActivityRange.days;
    final bars = days
        ? ProgressActivityBar.days(
            context,
            _data.summary.dailyActivity,
            widget.now,
          )
        : ProgressActivityBar.weeks(context, _data.summary.weeklyActivity);
    final total = bars.fold<int>(0, (sum, bar) => sum + bar.count);
    return ProgressCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ProgressSectionHeader(
                  title: l10n.progressWeeklyActivity,
                  subtitle: days
                      ? l10n.progressDailyChartSubtitle
                      : l10n.progressWeeklyChartSubtitle,
                ),
              ),
              Tooltip(
                message: l10n.progressChartInfo,
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 6),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    Icons.info_outline,
                    color: context.appColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          SegmentedButton<_ActivityRange>(
            key: const ValueKey('progress-activity-range'),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(
                value: _ActivityRange.days,
                label: Text(l10n.progressRangeDays),
              ),
              ButtonSegment(
                value: _ActivityRange.weeks,
                label: Text(l10n.progressRangeWeeks),
              ),
            ],
            selected: {_range},
            onSelectionChanged: (selection) =>
                setState(() => _range = selection.single),
          ),
          const SizedBox(height: 16),
          ProgressActivityChart(
            key: ValueKey('progress-chart-${_range.name}'),
            bars: bars,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.progressChartTotal(total),
            style: theme.textTheme.labelMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
