import 'package:ae_coaching/core/feedback/app_feedback.dart';
import 'package:ae_coaching/core/sync/revision_sync_engine.dart';
import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/workout_limits.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Shown inside a workout-day card when the day needs the user: a conflict
/// between devices, earlier exercises found in the cloud (prominent when a
/// decision is pending, a quiet link when restoring is only optional), or
/// more activities than a day can sync (split it).
class DaySyncNotice extends StatelessWidget {
  const DaySyncNotice({
    super.key,
    required this.template,
    required this.repository,
  });

  final WorkoutTemplate template;
  final WorkoutTemplateRepository repository;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final meta = template.syncMeta;
    final candidate = meta.legacyCandidate;
    final prompted = meta.hasConflict || candidate?['prompt'] == true;
    void open() =>
        showDaySyncReview(context, repository: repository, day: template);
    if (prompted) {
      return _NoticeBanner(
        key: ValueKey('day-sync-notice-${template.id}'),
        icon: meta.hasConflict ? Icons.sync_problem : Icons.history,
        title: meta.hasConflict
            ? _conflictTitle(l10n, meta.conflictReason)
            : l10n.syncLegacyTitle,
        subtitle: l10n.syncReviewNeeded,
        action: TextButton(onPressed: open, child: Text(l10n.syncReviewAction)),
      );
    }
    final count = template.exerciseAssignments.length;
    if (count > WorkoutLimits.maxActivitiesPerDay) {
      return _NoticeBanner(
        key: ValueKey('day-too-many-${template.id}'),
        icon: Icons.call_split,
        title: l10n.syncTooManyTitle,
        subtitle: l10n.syncTooManyBody(
          count,
          WorkoutLimits.maxActivitiesPerDay,
        ),
        action: TextButton(
          key: ValueKey('day-split-${template.id}'),
          onPressed: () =>
              confirmDaySplit(context, repository: repository, day: template),
          child: Text(l10n.syncSplitDay),
        ),
      );
    }
    if (candidate != null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: ValueKey('day-earlier-version-${template.id}'),
          onPressed: open,
          icon: const Icon(Icons.history, size: 18),
          label: Text(l10n.syncEarlierVersionAvailable),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          action,
        ],
      ),
    );
  }
}

/// Asks first, then splits [day] (nothing is deleted: the activities after
/// the limit move, in order, to new days of the same program).
Future<void> confirmDaySplit(
  BuildContext context, {
  required WorkoutTemplateRepository repository,
  required WorkoutTemplate day,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final newDays =
      WorkoutTemplateRepository.splitPlan(
        day.exerciseAssignments.length,
      ).length -
      1;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.syncSplitConfirmTitle),
      content: Text(
        l10n.syncSplitConfirmBody(WorkoutLimits.maxActivitiesPerDay, newDays),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('day-split-confirm'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.syncSplitDay),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    final days = await repository.splitOversizedDay(day.id);
    AppFeedback.success(l10n.syncSplitDone(days.length));
  } catch (_) {
    AppFeedback.error(l10n.exerciseLibrarySaveError);
  }
}

String _conflictTitle(AppLocalizations l10n, String? reason) =>
    switch (reason) {
      SyncConflictReason.deletedElsewhere => l10n.syncDeletedElsewhereTitle,
      SyncConflictReason.deletedHereEditedElsewhere =>
        l10n.syncDeletedHereTitle,
      SyncConflictReason.differsFromCloud => l10n.syncDiffersTitle,
      SyncConflictReason.overwrittenByOlderBuild => l10n.syncOlderBuildTitle,
      _ => l10n.syncEditedElsewhereTitle,
    };

String _conflictBody(AppLocalizations l10n, String? reason) => switch (reason) {
  SyncConflictReason.deletedElsewhere => l10n.syncDeletedElsewhereBody,
  SyncConflictReason.deletedHereEditedElsewhere => l10n.syncDeletedHereBody,
  SyncConflictReason.differsFromCloud => l10n.syncDiffersBody,
  SyncConflictReason.overwrittenByOlderBuild => l10n.syncOlderBuildBody,
  _ => l10n.syncEditedElsewhereBody,
};

/// The review sheet: both versions side by side (or the earlier exercises)
/// with explicit choices. Nothing changes until the user picks one.
Future<void> showDaySyncReview(
  BuildContext context, {
  required WorkoutTemplateRepository repository,
  required WorkoutTemplate day,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _DaySyncReviewSheet(repository: repository, dayId: day.id),
);

class _DaySyncReviewSheet extends StatefulWidget {
  const _DaySyncReviewSheet({required this.repository, required this.dayId});

  final WorkoutTemplateRepository repository;
  final String dayId;

  @override
  State<_DaySyncReviewSheet> createState() => _DaySyncReviewSheetState();
}

class _DaySyncReviewSheetState extends State<_DaySyncReviewSheet> {
  late final Future<WorkoutDaySyncIssue?> _issue = widget.repository
      .syncIssues()
      .then(
        (issues) => issues.where((i) => i.day.id == widget.dayId).firstOrNull,
      );
  bool _busy = false;

  Future<void> _apply(Future<void> Function() action, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(AppLocalizations.of(context)!.exerciseLibrarySaveError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkoutDaySyncIssue?>(
      future: _issue,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final issue = snapshot.data;
        if (issue == null) {
          return const SizedBox(height: 120);
        }
        return issue.isConflict
            ? _conflict(context, issue)
            : _legacy(context, issue);
      },
    );
  }

  Widget _frame(
    BuildContext context, {
    required String title,
    required String body,
    required List<Widget> content,
    required Widget primary,
    required Widget secondary,
  }) {
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(body, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        ...content,
        const SizedBox(height: 20),
        primary,
        const SizedBox(height: 8),
        secondary,
      ],
    );
  }

  ButtonStyle get _wide =>
      FilledButton.styleFrom(minimumSize: const Size.fromHeight(48));

  Widget _conflict(BuildContext context, WorkoutDaySyncIssue issue) {
    final l10n = AppLocalizations.of(context)!;
    final reason = issue.meta.conflictReason;
    final id = widget.dayId;
    final repo = widget.repository;
    Future<void> mine() => repo.keepMyVersion(id);
    Future<void> cloud() => repo.keepCloudVersion(id);

    // Which version the record and the saved copy hold, per reason.
    final (WorkoutTemplate? other, WorkoutTemplate? phone) = switch (reason) {
      SyncConflictReason.deletedElsewhere => (null, issue.day),
      SyncConflictReason.deletedHereEditedElsewhere => (issue.day, null),
      SyncConflictReason.overwrittenByOlderBuild => (null, issue.day),
      _ => (issue.day, issue.myVersion),
    };
    final versions = [
      if (other != null) _VersionCard(label: l10n.syncOtherVersion, day: other),
      if (phone != null)
        _VersionCard(label: l10n.syncThisPhone, day: phone, highlighted: true),
    ];
    final (
      String primaryLabel,
      Future<void> Function() primaryAction,
      String secondaryLabel,
      Future<void> Function() secondaryAction,
    ) = switch (reason) {
      SyncConflictReason.deletedElsewhere => (
        l10n.syncRestoreDay,
        mine,
        l10n.syncDeleteHereToo,
        cloud,
      ),
      SyncConflictReason.deletedHereEditedElsewhere => (
        l10n.syncKeepDay,
        cloud,
        l10n.syncDeleteAnyway,
        mine,
      ),
      _ => (l10n.syncKeepMine, mine, l10n.syncKeepCloud, cloud),
    };
    return _frame(
      context,
      title: _conflictTitle(l10n, reason),
      body: _conflictBody(l10n, reason),
      content: versions,
      primary: FilledButton(
        key: const ValueKey('sync-review-primary'),
        style: _wide,
        onPressed: _busy
            ? null
            : () => _apply(primaryAction, l10n.syncResolved),
        child: Text(primaryLabel),
      ),
      secondary: OutlinedButton(
        key: const ValueKey('sync-review-secondary'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: _busy
            ? null
            : () => _apply(secondaryAction, l10n.syncResolved),
        child: Text(secondaryLabel),
      ),
    );
  }

  Widget _legacy(BuildContext context, WorkoutDaySyncIssue issue) {
    final l10n = AppLocalizations.of(context)!;
    final older = issue.olderExercises;
    final savedAt = issue.olderSavedAt;
    final colors = context.appColors;
    // Every exercise is restored: beyond the limit, into new days.
    const limit = WorkoutLimits.maxActivitiesPerDay;
    final days = WorkoutTemplateRepository.splitPlan(older.length).length;
    return _frame(
      context,
      title: l10n.syncLegacyTitle,
      body: l10n.syncLegacyBody(older.length),
      content: [
        if (savedAt != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.syncLegacySavedOn(
                DateFormat.yMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(savedAt.toLocal()),
              ),
              style: TextStyle(color: colors.textMuted),
            ),
          ),
        if (days > 1)
          Container(
            key: const ValueKey('sync-legacy-split-notice'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l10n.syncLegacySplitNotice(limit, older.length - limit, days - 1),
            ),
          ),
        for (final (index, exercise) in older.indexed) ...[
          if (index > 0 && index % limit == 0)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                l10n.syncNewDayLabel(
                  '${issue.day.name} (${index ~/ limit + 1})',
                ),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(radius: 13, child: Text('${index + 1}')),
            title: Text(exercise.exerciseNameSnapshot),
          ),
        ],
      ],
      primary: FilledButton(
        key: const ValueKey('sync-review-primary'),
        style: _wide,
        onPressed: _busy
            ? null
            : () => _apply(
                () => widget.repository.restoreOlderExercises(widget.dayId),
                days > 1
                    ? l10n.syncLegacyRestoredSplit(days)
                    : l10n.syncLegacyRestored,
              ),
        child: Text(l10n.syncLegacyRestore),
      ),
      secondary: OutlinedButton(
        key: const ValueKey('sync-review-secondary'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: _busy
            ? null
            : () => _apply(
                () => widget.repository.dismissOlderExercises(widget.dayId),
                l10n.syncResolved,
              ),
        child: Text(l10n.syncLegacyDismiss),
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.label,
    required this.day,
    this.highlighted = false,
  });

  final String label;
  final WorkoutTemplate day;
  final bool highlighted;

  static const _shown = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final activities = day.exerciseAssignments;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? theme.colorScheme.primary : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: highlighted ? theme.colorScheme.primary : colors.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day.name,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            l10n.syncActivitiesCount(activities.length),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 6),
          for (final activity in activities.take(_shown))
            Text('• ${activity.exerciseNameSnapshot}'),
          if (activities.length > _shown) const Text('…'),
        ],
      ),
    );
  }
}

/// [SyncMeta] helper used by tests and the day card.
bool dayNeedsReview(WorkoutTemplate day) =>
    day.syncMeta.hasConflict || day.syncMeta.legacyCandidate?['prompt'] == true;
