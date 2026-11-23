import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/profile/domain/personal_record_book.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_widgets.dart';
import 'package:ae_coaching/features/workout/domain/services/personal_record_detection_service.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Route arguments for [PersonalRecordsScreen].
class PersonalRecordsArgs {
  const PersonalRecordsArgs({required this.records});
  final PersonalRecordBook records;
}

/// Every personal record, one card per exercise (heaviest weight and best
/// single set kept apart), most recently improved first, searchable by
/// exercise name. Lazily built, so hundreds of exercises stay smooth.
class PersonalRecordsScreen extends StatefulWidget {
  const PersonalRecordsScreen({super.key, required this.records});

  final PersonalRecordBook records;

  @override
  State<PersonalRecordsScreen> createState() => _PersonalRecordsScreenState();
}

class _PersonalRecordsScreenState extends State<PersonalRecordsScreen> {
  final _search = TextEditingController();
  late List<ExercisePersonalRecords> _visible = widget.records.exercises;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(String query) =>
      setState(() => _visible = widget.records.search(query));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text(l10n.progressPersonalRecords)),
      body: widget.records.isEmpty
          ? ProgressEmptyState(
              icon: Icons.emoji_events_outlined,
              message: l10n.progressRecordsEmpty,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    key: const ValueKey('records-search'),
                    controller: _search,
                    onChanged: _filter,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.progressRecordsSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: l10n.progressClearSearch,
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                _filter('');
                              },
                            ),
                      filled: true,
                      fillColor: colors.surfaceRaised,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(color: colors.border),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.progressExerciseCount(_visible.length),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _visible.isEmpty
                      ? ProgressEmptyState(
                          icon: Icons.search_off,
                          message: l10n.progressRecordsNoResults(
                            _search.text.trim(),
                          ),
                        )
                      : ListView.builder(
                          key: const ValueKey('records-list'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            24 + MediaQuery.paddingOf(context).bottom,
                          ),
                          itemCount: _visible.length,
                          itemBuilder: (context, index) =>
                              _ExerciseRecordsCard(exercise: _visible[index]),
                        ),
                ),
              ],
            ),
    );
  }
}

class _ExerciseRecordsCard extends StatelessWidget {
  const _ExerciseRecordsCard({required this.exercise});

  final ExercisePersonalRecords exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final heaviest = exercise.heaviestWeight;
    final volume = exercise.bestSetVolume;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProgressCard(
        key: ValueKey('records-exercise-${exercise.exerciseName}'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.exerciseName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            if (heaviest != null)
              _RecordLine(
                key: const ValueKey('record-heaviest'),
                icon: Icons.fitness_center,
                label: l10n.progressHeaviestWeightRecord,
                value: formatHeaviestWeight(context, heaviest),
                record: heaviest,
              ),
            if (volume != null)
              _RecordLine(
                key: const ValueKey('record-volume'),
                icon: Icons.stacked_bar_chart,
                label: l10n.progressBestSetVolumeLabel,
                value: formatSetVolume(context, volume),
                record: volume,
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordLine extends StatelessWidget {
  const _RecordLine({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.record,
  });

  final IconData icon;
  final String label;
  final String value;
  final PersonalRecordResult record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    final date = formatProgressDate(
      context,
      DateFormat.yMMMd,
      record.recordSet.date,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  l10n.progressRecordSetOn(date),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
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
