import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/profile/domain/workout_history_groups.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_dashboard.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_widgets.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Route arguments for [WorkoutHistoryScreen].
class WorkoutHistoryArgs {
  const WorkoutHistoryArgs({required this.data});
  final ProgressDashboardData data;
}

/// Every completed workout of the account, by month (newest first), with a
/// program filter. Each workout opens its workout day's history, as on the
/// dashboard. Built lazily.
class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key, required this.data});

  final ProgressDashboardData data;

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  String? _programId;

  /// Programs that have completed workouts, in dashboard order.
  late final List<WorkoutProgram> _filterPrograms = () {
    final used = {for (final s in widget.data.sessions) s.programId};
    return widget.data.programs.where((p) => used.contains(p.id)).toList();
  }();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final data = widget.data;
    final months = groupWorkoutHistoryByMonth(
      data.sessions,
      programId: _programId,
    );
    // Month headers and workouts as one flat, lazily built list.
    final items = <Object>[
      for (final month in months) ...[month, ...month.sessions],
    ];
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text(l10n.progressRecentWorkouts)),
      body: data.sessions.isEmpty
          ? ProgressEmptyState(
              icon: Icons.history,
              message: l10n.progressNoCompletedWorkouts,
            )
          : Column(
              children: [
                if (_filterPrograms.length > 1) _filters(context),
                Expanded(
                  child: items.isEmpty
                      ? ProgressEmptyState(
                          icon: Icons.filter_alt_off_outlined,
                          message: l10n.progressHistoryNoResults,
                        )
                      : ListView.builder(
                          key: const ValueKey('history-list'),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            24 + MediaQuery.paddingOf(context).bottom,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (item is WorkoutHistoryMonth) {
                              return _MonthHeader(month: item);
                            }
                            final session = item as WorkoutSession;
                            return WorkoutSessionTile(
                              session: session,
                              programName: _programId == null
                                  ? data.programsById[session.programId]?.name
                                  : null,
                              onTap: workoutDayHistoryOpener(
                                context,
                                session,
                                data.templatesById,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filters(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.progressFilterByProgram,
      container: true,
      child: SizedBox(
        height: 52,
        child: ListView(
          key: const ValueKey('history-filters'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          children: [
            _chip(null, l10n.progressAllPrograms),
            for (final program in _filterPrograms)
              _chip(program.id, program.name),
          ],
        ),
      ),
    );
  }

  Widget _chip(String? programId, String label) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: ChoiceChip(
      key: ValueKey('history-filter-${programId ?? 'all'}'),
      label: Text(label),
      selected: _programId == programId,
      onSelected: (_) => setState(() => _programId = programId),
    ),
  );
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month});

  final WorkoutHistoryMonth month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatProgressDate(context, DateFormat.yMMMM, month.month),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              l10n.progressWorkoutCount(month.sessions.length),
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
