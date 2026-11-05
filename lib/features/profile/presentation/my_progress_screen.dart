import 'dart:async';

import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/services/personal_record_detection_service.dart';
import 'package:ae_coaching/features/profile/domain/my_progress_summary_service.dart';
import 'package:ae_coaching/features/workout/presentation/screens/program_analytics_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_template_history_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyProgressScreen extends StatefulWidget {
  const MyProgressScreen({super.key});

  @override
  State<MyProgressScreen> createState() => _MyProgressScreenState();
}

class _MyProgressScreenState extends State<MyProgressScreen> {
  StreamSubscription<User?>? _authSubscription;
  String _uid = '';
  late Future<_ProgressData> _data;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _data = _load(_uid);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid ?? '';
      if (uid == _uid || !mounted) return;
      setState(() {
        _uid = uid;
        _data = _load(uid);
      });
    });
  }

  Future<_ProgressData> _load(String uid) async {
    if (uid.isEmpty) return _ProgressData.empty();
    final programRepository = sl<WorkoutProgramRepository>();
    final templateRepository = sl<WorkoutTemplateRepository>();
    final sessionRepository = sl<WorkoutSessionRepository>();
    final setRepository = sl<SessionExerciseRepository>();
    final programBox = await programRepository.getUserBox();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      return _ProgressData.empty();
    }
    final templateBox = await templateRepository.getUserBox();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      return _ProgressData.empty();
    }
    final sessionBox = await sessionRepository.getUserBox();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      return _ProgressData.empty();
    }
    final setBox = await setRepository.getUserBox();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      return _ProgressData.empty();
    }
    final programs = programRepository.getPrograms(programBox);
    final templates = templateBox.values.toList();
    final allSets = setBox.values.toList();
    final summary = const MyProgressSummaryService().summarize(
      sessions: sessionRepository.getAllCompletedSessions(sessionBox),
      sets: allSets,
      now: DateTime.now(),
    );
    final personalRecords = const PersonalRecordDetectionService().detect(
      newSets: allSets,
      historicalSets: const [],
    );
    return _ProgressData(
      sessions: summary.completedSessions,
      programs: programs,
      templates: templates,
      summary: summary,
      personalRecords: personalRecords,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _openProgramAnalytics(WorkoutProgram program) {
    Navigator.pushNamed(
      context,
      AppNavigator.programAnalytics,
      arguments: ProgramAnalyticsArgs(program: program),
    );
  }

  void _openTemplateHistory(WorkoutTemplate template) {
    Navigator.pushNamed(
      context,
      AppNavigator.workoutTemplateHistory,
      arguments: WorkoutTemplateHistoryArgs(template: template),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    if (_uid.isEmpty || FirebaseAuth.instance.currentUser?.uid != _uid) {
      return Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(title: Text(l10n.myProgressTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text(l10n.myProgressTitle)),
      body: FutureBuilder<_ProgressData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.progressDataUnavailable,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => setState(() => _data = _load(_uid)),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data ?? _ProgressData.empty();
          if (data.sessions.isEmpty &&
              data.programs.isEmpty &&
              data.personalRecords.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.insights_outlined,
                      size: 44,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.progressNoCompletedWorkouts,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            );
          }
          return _buildProgress(context, data);
        },
      ),
    );
  }

  Widget _buildProgress(BuildContext context, _ProgressData data) {
    final l10n = AppLocalizations.of(context)!;
    final summary = data.summary;
    final templatesById = {
      for (final template in data.templates) template.id: template,
    };
    final programs = [...data.programs]
      ..sort((a, b) {
        if (a.isActive == b.isActive) return b.createdAt.compareTo(a.createdAt);
        return a.isActive ? -1 : 1;
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        if (data.sessions.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: summary.completedWorkouts,
                  label: l10n.progressCompletedWorkoutsLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  value: summary.completedThisWeek,
                  label: l10n.progressThisWeekLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  value: summary.completedThisMonth,
                  label: l10n.progressThisMonthLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            l10n.progressWeeklyActivity,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _WeeklyActivityChart(weeklyActivity: summary.weeklyActivity),
          const SizedBox(height: 24),
        ],
        if (data.personalRecords.isNotEmpty) ...[
          Text(
            l10n.progressPersonalRecords,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final record in data.personalRecords)
            _PersonalRecordTile(record: record),
          const SizedBox(height: 18),
        ],
        if (programs.isNotEmpty) ...[
          Text(
            l10n.progressProgramAnalytics,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final program in programs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                program.isActive ? Icons.flag_outlined : Icons.fitness_center,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                program.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: program.isActive ? Text(l10n.activeProgramLabel) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openProgramAnalytics(program),
            ),
          const SizedBox(height: 12),
        ],
        if (data.sessions.isNotEmpty) ...[
          Text(
            l10n.progressRecentWorkouts,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final session in data.sessions)
            _SessionHistoryTile(
              session: session,
              onTap: templatesById[session.workoutTemplateId] == null
                  ? null
                  : () => _openTemplateHistory(
                      templatesById[session.workoutTemplateId]!,
                    ),
            ),
        ],
      ],
    );
  }
}

class _ProgressData {
  const _ProgressData({
    required this.sessions,
    required this.programs,
    required this.templates,
    required this.summary,
    required this.personalRecords,
  });
  _ProgressData.empty()
    : sessions = const [],
      programs = const [],
      templates = const [],
      personalRecords = const [],
      summary = MyProgressSummary(
        completedWorkouts: 0,
        completedThisWeek: 0,
        completedThisMonth: 0,
        weeklyActivity: [],
      );

  final List<WorkoutSession> sessions;
  final List<WorkoutProgram> programs;
  final List<WorkoutTemplate> templates;
  final MyProgressSummary summary;
  final List<PersonalRecordResult> personalRecords;
}

class _PersonalRecordTile extends StatelessWidget {
  const _PersonalRecordTile({required this.record});

  final PersonalRecordResult record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final number = NumberFormat('0.##', locale);
    final isWeight = record.type == PersonalRecordType.heaviestWeight;
    final metric = isWeight
        ? '${l10n.progressHeaviestWeightRecord}: ${number.format(record.newBest)} kg'
        : '${l10n.progressHighestSetVolumeRecord}: ${number.format(record.recordSet.weight)} kg × ${record.recordSet.reps}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.emoji_events_outlined,
        color: Theme.of(context).colorScheme.tertiary,
      ),
      title: Text(
        record.exerciseName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$metric · ${DateFormat.yMMMd(locale).format(record.recordSet.date)}',
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 84),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 2,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.appColors.textMuted),
        ),
      ],
    ),
  );
}

class _WeeklyActivityChart extends StatelessWidget {
  const _WeeklyActivityChart({required this.weeklyActivity});
  final List<WeeklyActivityPoint> weeklyActivity;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final counts = weeklyActivity.map((point) => point.completedCount).toList();
    final maxCount = counts.fold<int>(
      0,
      (max, count) => count > max ? count : max,
    );

    return Container(
      height: 164,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < weeklyActivity.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${counts[index]}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: maxCount == 0 ? 4 : 78 * counts[index] / maxCount,
                      constraints: const BoxConstraints(minHeight: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      DateFormat(
                        'd/M',
                        locale,
                      ).format(weeklyActivity[index].weekStart),
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionHistoryTile extends StatelessWidget {
  const _SessionHistoryTile({required this.session, required this.onTap});
  final WorkoutSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateLocale = Localizations.localeOf(context).toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.check_circle_outline,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        session.workoutNameSnapshot,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        DateFormat.yMMMd(
          dateLocale,
        ).format(session.completedAt ?? session.date),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
      isThreeLine: false,
    );
  }
}
