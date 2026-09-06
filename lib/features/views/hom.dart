import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/features/analytics/presentation/workout_analytics_screen.dart';
import 'package:ae_coaching/features/workout/presentation/bloc/workout_cubit.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class Hom extends StatefulWidget {
  const Hom({super.key});

  @override
  State<Hom> createState() => _HomState();
}

class _HomState extends State<Hom> {
  Box<ExerciseSet>? exerciseBox; // محتفظين بيه فقط للـ ValueListenableBuilder المحلى أو العرض السريع
  bool _isLoading = true;
  String _userName = 'User';

  final nameController = TextEditingController();
  final weightController = TextEditingController();
  final repsController = TextEditingController();

  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  void initState() {
    super.initState();
    _initUserBox();
  }

  Future<void> _initUserBox() async {
    final authBox = Hive.box('authBox');
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final storedName =
        (authBox.get('currentUserName', defaultValue: '') as String).trim();
    final uid = firebaseUser?.uid ?? '';

    if (uid.isEmpty) {
      await authBox.put('isLoggedIn', false);
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppNavigator.login,
        (route) => false,
      );
      return;
    }

    _userName = storedName.isNotEmpty ? storedName : (firebaseUser?.displayName ?? 'User');
    await authBox.put('currentUserUid', uid);

    // فتح الصندوق الخاص بالمستخدم الحالي
    exerciseBox = await Hive.openBox<ExerciseSet>('sets_$uid');

    // 🔥 تلميح هندسي: هنا تقدر تعمل Trigger لـ Load Workouts من الـ Cubit بتاعك:
    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<WorkoutCubit>().loadWorkoutBox();
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    weightController.dispose();
    repsController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.logoutConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w900, color: _dark),
        ),
        content: Text(
          l10n.logoutConfirmBody,
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: const TextStyle(color: _blue)),
          ),
          ElevatedButton(
            onPressed: () async {
              final authBox = Hive.box('authBox');
              await authBox.put('isLoggedIn', false);
              await authBox.delete('currentUserUid');
              await authBox.delete('currentUserName');
              await authBox.delete('currentUserPhone');

              if (exerciseBox != null && exerciseBox!.isOpen) {
                await exerciseBox!.close();
              }

              await FirebaseAuth.instance.signOut();

              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppNavigator.login,
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.logoutTooltip, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ملاحظة: مفاتيح التجميع/المقارنة دي لازم تفضل بأرقام إنجليزية عادية
  // بغض النظر عن لغة الابلكيشن، عشان الـ sort/compare يفضل شغال صح.
  Map<String, List<ExerciseSet>> _groupExercises(List<ExerciseSet> allSets) {
    final grouped = <String, List<ExerciseSet>>{};
    for (final set in allSets) {
      final dateKey = DateFormat('yyyy-MM-dd', 'en_US').format(set.date);
      final groupKey = '$dateKey | ${set.exerciseName}';
      grouped.putIfAbsent(groupKey, () => []).add(set);
    }

    for (final list in grouped.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }

    return grouped;
  }

  double _calculateTodayVolume() {
    if (exerciseBox == null) return 0.0;
    final todayStr = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now());
    return exerciseBox!.values.where((set) {
      return DateFormat('yyyy-MM-dd', 'en_US').format(set.date) == todayStr;
    }).fold(0.0, (sum, set) => sum + (set.weight * set.reps));
  }

  Map<String, double> _dailyVolumeFor(List<ExerciseSet> history) {
    final dailyVolume = <String, double>{};
    for (final set in history) {
      final day = DateFormat('yyyy-MM-dd', 'en_US').format(set.date);
      dailyVolume[day] = (dailyVolume[day] ?? 0) + (set.weight * set.reps);
    }
    return dailyVolume;
  }

  void _showProgressAnalysis() {
    if (exerciseBox == null) return;
    final l10n = AppLocalizations.of(context)!;
    final analyticsScreenContext = context;
    final allSets = exerciseBox!.values.toList();
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
                        label: Text(l10n.historyLabel),
                        style: TextButton.styleFrom(foregroundColor: _blue),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.analytics_outlined),
                        label: Text(l10n.analyticsLabel),
                        style: TextButton.styleFrom(foregroundColor: _blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.progressAnalyticsTitle,
                    style: const TextStyle(
                      color: _dark,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.exerciseTrendsLabel,
                    style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (exerciseHistory.isEmpty)
                    _AnalyticsNoticeCard(
                      text: l10n.needMoreDataForProgress,
                    )
                  else
                    ...exerciseHistory.entries.map((entry) {
                      final name = entry.key;
                      final dailyVolume = _dailyVolumeFor(entry.value);
                      final dates = dailyVolume.keys.toList()..sort((a, b) => b.compareTo(a));

                      if (dates.length < 2) {
                        return _AnalyticsNoticeCard(
                          text: l10n.exerciseNeedsMoreData(_titleCase(name)),
                        );
                      }

                      final currentVol = dailyVolume[dates[0]]!;
                      final previousVol = dailyVolume[dates[1]]!;
                      final diff = currentVol - previousVol;
                      final isImproved = diff >= 0;
                      final percentage = previousVol > 0 ? (diff / previousVol) * 100 : 0.0;
                      final progressDeltaStr = percentage.toStringAsFixed(1);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            analyticsScreenContext,
                            AppNavigator.workoutAnalytics,
                            arguments: WorkoutAnalyticsArgs(
                              exerciseName: _titleCase(name),
                              totalVolume: currentVol.toStringAsFixed(0),
                              progressDelta: progressDeltaStr,
                            ),
                          );
                        },
                        child: _AnalyticsCard(
                          title: _titleCase(name),
                          subtitle: l10n.lastPreviousVolume(
                            currentVol.toStringAsFixed(0),
                            previousVol.toStringAsFixed(0),
                          ),
                          improved: isImproved,
                          diff: diff,
                        ),
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
                      child: Text(l10n.close),
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

  void _onWorkoutStateChanged(BuildContext context, WorkoutState state) {
    if (state is WorkoutSuccess) {
      if (exerciseBox != state.box) {
        setState(() => exerciseBox = state.box);
      }
      return;
    }

    if (state is WorkoutError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffdbe9f7), Color(0xff8fb6e6)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: _blue),
          ),
        ),
      );
    }

    return BlocListener<WorkoutCubit, WorkoutState>(
      listener: _onWorkoutStateChanged,
      child: Scaffold(
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
                  _buildTopPanel(l10n),
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: exerciseBox!.listenable(),
                      builder: (context, Box<ExerciseSet> box, _) {
                        final groupedData = _groupExercises(box.values.toList());
                        final groupKeys = groupedData.keys.toList()
                          ..sort((a, b) => b.compareTo(a));

                        if (groupKeys.isEmpty) {
                          return Center(
                            child: Text(
                              l10n.startFirstExercise,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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

                            return Dismissible(
                              key: ValueKey(key),
                              direction: DismissDirection.horizontal,
                              background: const _DeleteSwipeBackground(
                                alignment: Alignment.centerLeft,
                              ),
                              secondaryBackground: const _DeleteSwipeBackground(
                                alignment: Alignment.centerRight,
                              ),
                              confirmDismiss: (_) => _confirmDeleteExercise(
                                exerciseName: exerciseName,
                                setCount: sets.length,
                              ),
                              onDismissed: (_) => _deleteExerciseSets(sets),
                              child: _ExerciseCard(
                                exerciseName: exerciseName,
                                dateLabel: dateLabel,
                                totalVolume: totalVol,
                                sets: sets,
                                onAddSet: () => _showAddExerciseDialog(preFilledName: exerciseName),
                                onEditSet: _showEditSetDialog,
                              ),
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
          label: Text(
            l10n.newExerciseButton,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _buildTopPanel(AppLocalizations l10n) {
    final headerName = 'c.${_userName.trim().isEmpty ? 'User' : _userName.trim()}';
    final dateLocale = Localizations.localeOf(context).toString();

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        l10n.workoutTrackerSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.read<LocaleCubit>().toggle(),
                  icon: const Icon(Icons.translate, size: 22),
                  color: Colors.white,
                  tooltip: l10n.languageToggleTooltip,
                ),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, size: 22),
                  color: Colors.white,
                  tooltip: l10n.logoutTooltip,
                ),
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, AppNavigator.measurements),
                  icon: const Icon(Icons.straighten),
                  color: Colors.white,
                  tooltip: l10n.measurementsTooltip,
                ),
                IconButton(
                  onPressed: _showProgressAnalysis,
                  icon: const Icon(Icons.analytics_outlined),
                  color: Colors.white,
                  tooltip: l10n.progressAnalyticsTooltip,
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ValueListenableBuilder(
              valueListenable: exerciseBox!.listenable(),
              builder: (context, box, _) {
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.todaysVolumeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('EEE, MMM d', dateLocale).format(DateTime.now()),
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
    final l10n = AppLocalizations.of(context)!;
    final workoutCubit = context.read<WorkoutCubit>();
    nameController.text = preFilledName ?? '';
    weightController.clear();
    repsController.clear();
    showDialog(
      context: context,
      builder: (context) => _ExerciseDialog(
        title: preFilledName == null ? l10n.addNewExerciseTitle : l10n.addSetToTitle(preFilledName),
        nameController: nameController,
        weightController: weightController,
        repsController: repsController,
        showName: preFilledName == null,
        actionLabel: l10n.save,
        onDelete: null,
        onSubmit: () {
          final weight = double.tryParse(weightController.text);
          final reps = int.tryParse(repsController.text);
          if (nameController.text.trim().isEmpty || weight == null || reps == null) {
            return;
          }

          final newSet = ExerciseSet(
            exerciseName: nameController.text.trim(),
            weight: weight,
            reps: reps,
            date: DateTime.now(),
          );

          // 🔥 التعديل المعماري: الحفظ عبر الـ Cubit للحفاظ على الـ Sync والداتا

          // حل محلي مؤقت شغال لحين ربط الـ Cubit بالكامل:
          workoutCubit.saveWorkout(set: newSet);

          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditSetDialog(ExerciseSet set) {
    final l10n = AppLocalizations.of(context)!;
    final workoutCubit = context.read<WorkoutCubit>();
    weightController.text = set.weight.toString();
    repsController.text = set.reps.toString();
    showDialog(
      context: context,
      builder: (context) => _ExerciseDialog(
        title: l10n.editSetTitle(set.exerciseName),
        nameController: nameController,
        weightController: weightController,
        repsController: repsController,
        showName: false,
        actionLabel: l10n.updateButton,
        onDelete: () {
          // 🔥 التعديل المعماري: الحذف عبر الـ Cubit لضمان المسح من السيرفر والـ Local

          workoutCubit.deleteWorkout(set: set);
          Navigator.pop(context);
        },
        onSubmit: () {
          final updatedSet = ExerciseSet(
            exerciseName: set.exerciseName,
            weight: double.tryParse(weightController.text) ?? set.weight,
            reps: int.tryParse(repsController.text) ?? set.reps,
            date: set.date,
            notes: set.notes,
          );

          // 🔥 التعديل المعماري: التحديث عبر الـ Cubit

          workoutCubit.saveWorkout(
                set: updatedSet,
                key: set.key.toString(),
              );
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<bool> _confirmDeleteExercise({
    required String exerciseName,
    required int setCount,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.deleteExerciseTitle,
          style: const TextStyle(fontWeight: FontWeight.w900, color: _dark),
        ),
        content: Text(
          l10n.deleteExerciseBody(
            exerciseName,
            setCount,
            setCount == 1 ? l10n.setUnitSingular : l10n.setUnitPlural,
          ),
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: const TextStyle(color: _blue)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.delete, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _deleteExerciseSets(List<ExerciseSet> sets) async {
    final keys = sets
        .map((set) => set.key?.toString())
        .whereType<String>()
        .where((key) => key.isNotEmpty)
        .toList(growable: false);

    // 🔥 التعديل المعماري: حذف مجموعة كاملة عبر الـ Cubit

    if (keys.isEmpty) return;

    await context.read<WorkoutCubit>().deleteMultipleWorkouts(keys: keys);
  }
}

// ==================== Sub-Widgets Components ====================

class _DeleteSwipeBackground extends StatelessWidget {
  final Alignment alignment;
  const _DeleteSwipeBackground({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: alignment,
      child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
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
    final l10n = AppLocalizations.of(context)!;
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
            l10n.totalVolumeLabel(dateLabel, totalVolume.toStringAsFixed(1)),
            style: const TextStyle(color: Color(0xff8a96a3), fontSize: 12),
          ),
          trailing: const Icon(Icons.tune, color: Color(0xff2f80ed)),
          children: [
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(l10n.setsColumnLabel,
                      style: const TextStyle(color: Color(0xff7d8792), fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: Text(l10n.weightColumnLabel,
                      style: const TextStyle(color: Color(0xff7d8792), fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: Text(l10n.repsColumnLabel,
                      style: const TextStyle(color: Color(0xff7d8792), fontWeight: FontWeight.w800)),
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
                            Text(
                              l10n.setLabel,
                              style: const TextStyle(
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
              label: Text(l10n.addAnotherSetButton),
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
    final l10n = AppLocalizations.of(context)!;
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
              decoration: _decoration(l10n.exerciseNameHint),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: weightController,
            decoration: _decoration(l10n.weightKgHint),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: repsController,
            decoration: _decoration(l10n.repsHint),
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
          child: Text(l10n.cancel),
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
