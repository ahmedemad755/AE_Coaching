import 'dart:async';

import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/profile/domain/my_progress_summary_service.dart';
import 'package:ae_coaching/features/profile/domain/personal_record_book.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_dashboard.dart';
import 'package:ae_coaching/features/profile/presentation/progress/progress_widgets.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ae_coaching/core/widgets/app_shimmer.dart';
import 'package:ae_coaching/core/widgets/visible_data_refresher.dart';

class MyProgressScreen extends StatefulWidget {
  const MyProgressScreen({super.key});

  @override
  State<MyProgressScreen> createState() => _MyProgressScreenState();
}

class _MyProgressScreenState extends State<MyProgressScreen> {
  StreamSubscription<User?>? _authSubscription;
  String _uid = '';
  late Future<ProgressDashboardData> _data;

  /// True while a change-driven refresh replaces [_data]: the current data
  /// stays on screen (no shimmer, scroll position kept) until it lands.
  /// Never true for a first load or a different user's load.
  bool _refreshing = false;

  // Kept alive as a Home tab, this screen reloads only after the boxes it
  // reads changed, and only while it is visible.
  late final _refresher = VisibleDataRefresher(reload: _refreshInBackground);

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _data = _load(_uid);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid ?? '';
      if (uid == _uid || !mounted) return;
      _refresher.reset();
      setState(() {
        _uid = uid;
        _refreshing = false;
        _data = _load(uid);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresher.attachVisibility(TickerMode.getNotifier(context));
  }

  Future<void> _refreshInBackground() async {
    if (!mounted || _uid.isEmpty) return;
    final next = _load(_uid);
    setState(() {
      _refreshing = true;
      _data = next;
    });
    await next;
  }

  Future<ProgressDashboardData> _load(String uid) async {
    if (uid.isEmpty) return ProgressDashboardData.empty();
    final programRepository = sl<WorkoutProgramRepository>();
    final templateRepository = sl<WorkoutTemplateRepository>();
    final sessionRepository = sl<WorkoutSessionRepository>();
    final setRepository = sl<SessionExerciseRepository>();
    final programBox = await programRepository.getUserBox();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      return ProgressDashboardData.empty();
    }
    final templateBox = await templateRepository.getUserBox();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      return ProgressDashboardData.empty();
    }
    final sessionBox = await sessionRepository.getUserBox();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      return ProgressDashboardData.empty();
    }
    final setBox = await setRepository.getUserBox();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      return ProgressDashboardData.empty();
    }
    if (mounted && uid == _uid) {
      _refresher.watch([
        programBox.watch(),
        templateBox.watch(),
        sessionBox.watch(),
        setBox.watch(),
      ]);
    }
    final allSets = setBox.values.toList();
    // Computed once here; the dashboard and its detail screens only read it.
    return ProgressDashboardData(
      summary: const MyProgressSummaryService().summarize(
        sessions: sessionRepository.getAllCompletedSessions(sessionBox),
        sets: allSets,
        now: DateTime.now(),
      ),
      records: PersonalRecordBook.fromSets(allSets),
      programs: programRepository.getPrograms(programBox),
      templates: templateBox.values.toList(),
    );
  }

  @override
  void dispose() {
    _refresher.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    if (_uid.isEmpty || FirebaseAuth.instance.currentUser?.uid != _uid) {
      return Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(title: Text(l10n.myProgressTitle)),
        body: const ShimmerDashboard(),
      );
    }
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text(l10n.myProgressTitle)),
      body: FutureBuilder<ProgressDashboardData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !(_refreshing && snapshot.hasData)) {
            return const ShimmerDashboard();
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
                      onPressed: () => setState(() {
                        _refreshing = false;
                        _data = _load(_uid);
                      }),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data ?? ProgressDashboardData.empty();
          if (data.isEmpty) {
            return ProgressEmptyState(
              icon: Icons.insights_outlined,
              message: l10n.progressNoCompletedWorkouts,
            );
          }
          return ProgressDashboard(data: data, now: DateTime.now());
        },
      ),
    );
  }
}
