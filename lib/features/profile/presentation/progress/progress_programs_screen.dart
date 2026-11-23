import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_dashboard.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_widgets.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Route arguments for [ProgressProgramsScreen].
class ProgressProgramsArgs {
  const ProgressProgramsArgs({required this.programs});
  final List<WorkoutProgram> programs;
}

/// Every program (active first), each opening its existing analytics.
class ProgressProgramsScreen extends StatelessWidget {
  const ProgressProgramsScreen({super.key, required this.programs});

  final List<WorkoutProgram> programs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.appColors.canvas,
      appBar: AppBar(title: Text(l10n.progressProgramAnalytics)),
      body: programs.isEmpty
          ? ProgressEmptyState(
              icon: Icons.insights,
              message: l10n.progressNoCompletedWorkouts,
            )
          : ListView.builder(
              key: const ValueKey('programs-list'),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: programs.length,
              itemBuilder: (context, index) => ProgramAnalyticsTile(
                program: programs[index],
                onTap: () => openProgramAnalytics(context, programs[index]),
              ),
            ),
    );
  }
}
