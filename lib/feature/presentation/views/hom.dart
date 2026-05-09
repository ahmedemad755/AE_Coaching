import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class Hom extends StatefulWidget {
  const Hom({super.key});

  @override
  State<Hom> createState() => _HomState();
}

class _HomState extends State<Hom> {
  late Box<ExerciseSet> exerciseBox;
  final nameController = TextEditingController();
  final weightController = TextEditingController();
  final repsController = TextEditingController();

  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  void initState() {
    super.initState();
    exerciseBox = Hive.box<ExerciseSet>('sets');
  }

  @override
  void dispose() {
    nameController.dispose();
    weightController.dispose();
    repsController.dispose();
    super.dispose();
  }

  Map<String, List<ExerciseSet>> _groupExercises(List<ExerciseSet> allSets) {
    final grouped = <String, List<ExerciseSet>>{};
    for (final set in allSets) {
      final dateKey = DateFormat('yyyy-MM-dd').format(set.date);
      final groupKey = '$dateKey | ${set.exerciseName}';
      grouped.putIfAbsent(groupKey, () => []).add(set);
    }

    for (final list in grouped.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }

    return grouped;
  }

  double _calculateTodayVolume() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return exerciseBox.values.where((set) {
      return DateFormat('yyyy-MM-dd').format(set.date) == todayStr;
    }).fold(0.0, (sum, set) => sum + (set.weight * set.reps));
  }

  Map<String, double> _dailyVolumeFor(List<ExerciseSet> history) {
    final dailyVolume = <String, double>{};
    for (final set in history) {
      final day = DateFormat('yyyy-MM-dd').format(set.date);
      dailyVolume[day] = (dailyVolume[day] ?? 0) + (set.weight * set.reps);
    }
    return dailyVolume;
  }

  void _showProgressAnalysis() {
    final allSets = exerciseBox.values.toList();
    final exerciseHistory = <String, List<ExerciseSet>>{};
    for (final set in allSets) {
      exerciseHistory.putIfAbsent(set.exerciseName.toLowerCase().trim(), () => []).add(set);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xfff5f9fc),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new),
                        color: _blue,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.history),
                        label: const Text('History'),
                        style: TextButton.styleFrom(foregroundColor: _blue),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('Analytics'),
                        style: TextButton.styleFrom(foregroundColor: _blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Progress Analytics',
                    style: TextStyle(
                      color: _dark,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Exercise Trends',
                    style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (exerciseHistory.isEmpty)
                    _AnalyticsNoticeCard(
                      text: 'Add at least two workout days to unlock progress analysis.',
                    )
                  else
                    ...exerciseHistory.entries.map((entry) {
                      final name = entry.key;
                      final dailyVolume = _dailyVolumeFor(entry.value);
                      final dates = dailyVolume.keys.toList()..sort((a, b) => b.compareTo(a));

                      if (dates.length < 2) {
                        return _AnalyticsNoticeCard(
                          text: '${_titleCase(name)} needs more data (2+ workouts)',
                        );
                      }

                      final currentVol = dailyVolume[dates[0]]!;
                      final previousVol = dailyVolume[dates[1]]!;
                      final diff = currentVol - previousVol;
                      final isImproved = diff >= 0;

                      return _AnalyticsCard(
                        title: _titleCase(name),
                        subtitle:
                            'Last: ${currentVol.toStringAsFixed(0)} kg | Previous: ${previousVol.toStringAsFixed(0)} kg',
                        improved: isImproved,
                        diff: diff,
                      );
                    }),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        elevation: 8,
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _titleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffdbe9f7), Color(0xff8fb6e6)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _buildTopPanel(),
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: exerciseBox.listenable(),
                      builder: (context, Box<ExerciseSet> box, _) {
                        final groupedData = _groupExercises(box.values.toList());
                        final groupKeys = groupedData.keys.toList()
                          ..sort((a, b) => b.compareTo(a));

                        if (groupKeys.isEmpty) {
                          return const Center(
                            child: Text(
                              'Start by adding your first exercise.',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
                          itemCount: groupKeys.length,
                          itemBuilder: (context, index) {
                            final key = groupKeys[index];
                            final sets = groupedData[key]!;
                            final exerciseName = key.split('|')[1].trim();
                            final dateLabel = key.split('|')[0].trim();
                            final totalVol = sets.fold(0.0, (sum, s) => sum + (s.weight * s.reps));

                            return _ExerciseCard(
                              exerciseName: exerciseName,
                              dateLabel: dateLabel,
                              totalVolume: totalVol,
                              sets: sets,
                              onAddSet: () => _showAddExerciseDialog(preFilledName: exerciseName),
                              onEditSet: _showEditSetDialog,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExerciseDialog(),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 10,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text(
          'New Exercise',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildTopPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Workout Tracker',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _showProgressAnalysis,
                  icon: const Icon(Icons.analytics_outlined),
                  color: Colors.white,
                  tooltip: 'Progress Analytics',
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ValueListenableBuilder(
              valueListenable: exerciseBox.listenable(),
              builder: (context, box, _) {
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Volume: [kg]",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('EEE, MMM d').format(DateTime.now()),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _calculateTodayVolume().toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseDialog({String? preFilledName}) {
    nameController.text = preFilledName ?? '';
    weightController.clear();
    repsController.clear();
    showDialog(
      context: context,
      builder: (context) => _ExerciseDialog(
        title: preFilledName == null ? 'Add New Exercise' : 'Add Set to $preFilledName',
        nameController: nameController,
        weightController: weightController,
        repsController: repsController,
        showName: preFilledName == null,
        actionLabel: 'Save',
        onDelete: null,
        onSubmit: () {
          final weight = double.tryParse(weightController.text);
          final reps = int.tryParse(repsController.text);
          if (nameController.text.trim().isEmpty || weight == null || reps == null) {
            return;
          }

          exerciseBox.add(
            ExerciseSet(
              exerciseName: nameController.text.trim(),
              weight: weight,
              reps: reps,
              date: DateTime.now(),
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditSetDialog(ExerciseSet set) {
    weightController.text = set.weight.toString();
    repsController.text = set.reps.toString();
    showDialog(
      context: context,
      builder: (context) => _ExerciseDialog(
        title: 'Edit ${set.exerciseName} Set',
        nameController: nameController,
        weightController: weightController,
        repsController: repsController,
        showName: false,
        actionLabel: 'Update',
        onDelete: () {
          set.delete();
          Navigator.pop(context);
        },
        onSubmit: () {
          exerciseBox.put(
            set.key,
            ExerciseSet(
              exerciseName: set.exerciseName,
              weight: double.tryParse(weightController.text) ?? set.weight,
              reps: int.tryParse(repsController.text) ?? set.reps,
              date: set.date,
              notes: set.notes,
            ),
          );
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String exerciseName;
  final String dateLabel;
  final double totalVolume;
  final List<ExerciseSet> sets;
  final VoidCallback onAddSet;
  final ValueChanged<ExerciseSet> onEditSet;

  const _ExerciseCard({
    required this.exerciseName,
    required this.dateLabel,
    required this.totalVolume,
    required this.sets,
    required this.onAddSet,
    required this.onEditSet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xffd6e9ff),
            child: Icon(Icons.fitness_center, color: Color(0xff2f80ed), size: 18),
          ),
          title: Text(
            exerciseName,
            style: const TextStyle(
              color: Color(0xff202936),
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            '$dateLabel | Total Vol: ${totalVolume.toStringAsFixed(1)} kg',
            style: const TextStyle(color: Color(0xff8a96a3), fontSize: 12),
          ),
          trailing: const Icon(Icons.tune, color: Color(0xff2f80ed)),
          children: [
            const Divider(height: 18),
            Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text('Sets', style: TextStyle(color: Color(0xff7d8792), fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: Text('Weight', style: TextStyle(color: Color(0xff7d8792), fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: Text('Reps', style: TextStyle(color: Color(0xff7d8792), fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...sets.asMap().entries.map((entry) {
              final set = entry.value;
              return InkWell(
                onTap: () => onEditSet(set),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xff9bc4f8),
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Set',
                              style: TextStyle(
                                color: Color(0xff202936),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${set.weight.toStringAsFixed(1)} kg',
                          style: const TextStyle(color: Color(0xff202936)),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${set.reps}',
                                style: const TextStyle(color: Color(0xff202936)),
                              ),
                            ),
                            const Icon(Icons.edit_note, color: Color(0xff2f80ed)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add_box),
              label: const Text('Add Another Set'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: const Color(0xff2f80ed),
                side: const BorderSide(color: Color(0xff2f80ed)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool improved;
  final double diff;

  const _AnalyticsCard({
    required this.title,
    required this.subtitle,
    required this.improved,
    required this.diff,
  });

  @override
  Widget build(BuildContext context) {
    final color = improved ? const Color(0xff38b66b) : const Color(0xffef5b4d);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: improved ? const Color(0xffd8f4df) : const Color(0xffffe7e4),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xff202936),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xff7d8792), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Icon(improved ? Icons.arrow_upward : Icons.arrow_downward, color: color),
                Text(
                  '${improved ? '+' : ''}${diff.toStringAsFixed(0)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsNoticeCard extends StatelessWidget {
  final String text;

  const _AnalyticsNoticeCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffdce6eb),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xff52606c), fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ExerciseDialog extends StatelessWidget {
  final String title;
  final TextEditingController nameController;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final bool showName;
  final String actionLabel;
  final VoidCallback? onDelete;
  final VoidCallback onSubmit;

  const _ExerciseDialog({
    required this.title,
    required this.nameController,
    required this.weightController,
    required this.repsController,
    required this.showName,
    required this.actionLabel,
    required this.onDelete,
    required this.onSubmit,
  });

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xffd5e3f2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff2f80ed)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xfff5f9fc),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xff202936),
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showName) ...[
            TextField(
              controller: nameController,
              decoration: _decoration('Exercise Name'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: weightController,
            decoration: _decoration('Weight (kg)'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: repsController,
            decoration: _decoration('Reps'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        if (onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: onDelete,
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xff2f80ed),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(actionLabel),
        ),
      ],
    );
  }
}
