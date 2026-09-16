import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/features/analytics/presentation/workout_analytics_screen.dart';
import 'package:ae_coaching/features/workout/presentation/bloc/workout_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/home_workout_overview_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_program_details_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/home_workout_overview_section.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
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
        context.read<HomeWorkoutOverviewCubit>().loadOverview();
      });
    }
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

              // Phase 21 audit fix: WorkoutSessionCubit is a
              // process-lifetime singleton (see its class docs) — its
              // last-emitted state must not leak into whichever user
              // signs in next on this device/process.
              sl<WorkoutSessionCubit>().reset();

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

  // _groupExercises (the old date|exerciseName grouping used by Home's
  // flat exercise-card list) was removed along with that list — Home
  // now shows session-level cards via HomeWorkoutOverviewSection. The
  // identical grouping pattern still lives on, unchanged, inside
  // _showProgressAnalysis below, which this redesign does not touch.

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

    return MultiBlocListener(
      listeners: [
        BlocListener<WorkoutCubit, WorkoutState>(listener: _onWorkoutStateChanged),
        // Redesigned Home workout section (see HomeWorkoutOverviewCubit's
        // class docs): refreshes whenever the app-wide active-session
        // state settles, so starting/resuming/finishing/cancelling a
        // workout elsewhere is reflected here without a manual pull.
        BlocListener<WorkoutSessionCubit, WorkoutSessionState>(
          listener: (context, state) {
            if (state is! WorkoutSessionLoading) {
              context.read<HomeWorkoutOverviewCubit>().loadOverview();
            }
          },
        ),
      ],
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
                  const Expanded(
                    child: HomeWorkoutOverviewSection(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _onStartWorkoutPressed,
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 10,
          icon: const Icon(Icons.add_circle_outline),
          label: Text(
            l10n.startWorkoutFabLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  /// New Workout FAB (redesigned): goes straight to the active
  /// program's Workout Days screen so the user picks Push/Pull/etc and
  /// starts a real, structured [WorkoutSession] — never creates a loose
  /// legacy [ExerciseSet]. With no active program yet, it opens the
  /// Programs hub instead. The old one-off manual entry dialog has been
  /// removed entirely — every workout is now logged through a real
  /// session.
  void _onStartWorkoutPressed() {
    final overviewState = context.read<HomeWorkoutOverviewCubit>().state;
    final activeProgram =
        overviewState is HomeWorkoutOverviewLoaded ? overviewState.overview.activeProgram?.program : null;

    if (activeProgram != null) {
      Navigator.pushNamed(
        context,
        AppNavigator.workoutProgramDetails,
        arguments: WorkoutProgramDetailsArgs(program: activeProgram),
      );
    } else {
      Navigator.pushNamed(context, AppNavigator.workoutPrograms);
    }
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
                  onPressed: () => Navigator.pushNamed(context, AppNavigator.workoutPrograms),
                  icon: const Icon(Icons.assignment_outlined),
                  color: Colors.white,
                  tooltip: l10n.workoutProgramsTooltip,
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

  // _showAddExerciseDialog / _showEditSetDialog / _confirmDeleteExercise
  // / _deleteExerciseSets / _ExerciseDialog (the old manual one-off
  // exercise entry, and edit/swipe-to-delete for one legacy exercise
  // card) were removed entirely — logging a workout now always goes
  // through a real WorkoutSession (Start Workout, from a program's
  // Workout Days screen). The underlying data/operations they used
  // (WorkoutCubit.saveWorkout/deleteWorkout/deleteMultipleWorkouts)
  // are untouched; any exercise data logged this way before this
  // change is still intact in storage and still reflected in
  // Today's Volume / Progress Analysis below.
}

// ==================== Sub-Widgets Components ====================
//
// _DeleteSwipeBackground and _ExerciseCard (the old per-legacy-exercise
// swipe-to-delete background and expandable card) were removed along
// with Home's flat exercise-card list, their only caller — see the
// Home Workout Overview redesign. Nothing else in this file referenced
// them.

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

// _ExerciseDialog (the shared weight/reps/optional-name dialog behind
// the old manual one-off exercise entry) was removed along with
// _showAddExerciseDialog — its only caller.
