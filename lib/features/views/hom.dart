import 'dart:async';
import 'package:ae_coaching/core/localization/operation_message_localizer.dart';
import 'package:ae_coaching/core/feedback/app_feedback.dart';
import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/notifications/fcm_device_service.dart';
import 'package:ae_coaching/features/inactivity_reminders/application/inactivity_reminder_scheduler.dart';
import 'package:ae_coaching/features/notification_settings/application/notification_preferences_sync.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/analytics/presentation/workout_analytics_screen.dart';
import 'package:ae_coaching/features/profile/data/local_profile_photo_store.dart';
import 'package:ae_coaching/features/profile/presentation/my_progress_screen.dart';
import 'package:ae_coaching/features/profile/presentation/personal_hub_screen.dart';
import 'package:ae_coaching/features/profile/presentation/profile_navigation.dart';
import 'package:ae_coaching/features/views/widgets/home_dashboard.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/domain/services/home_progress_comparison_service.dart';
import 'package:ae_coaching/features/workout/presentation/bloc/workout_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/home_workout_overview_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_programs_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ae_coaching/core/widgets/app_shimmer.dart';

class Hom extends StatefulWidget {
  const Hom({super.key});

  @override
  State<Hom> createState() => _HomState();
}

class _HomState extends State<Hom> {
  Box<ExerciseSet>?
  exerciseBox; // محتفظين بيه فقط للـ ValueListenableBuilder المحلى أو العرض السريع
  bool _isLoading = true;

  /// Set before logout closes this user's boxes. Signing out rebuilds Hom
  /// (its auth listener, the per-user theme) BEFORE navigation leaves it, so
  /// from here on Hom must not build anything bound to per-user data.
  bool _signingOut = false;
  String _userName = 'User';
  String _profilePhotoUid = '';
  String? _profilePhotoPath;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthStateChanged,
    );
    _initUserBox();
  }

  void _handleAuthStateChanged(User? user) {
    final uid = user?.uid ?? '';
    if (uid == _profilePhotoUid) return;
    _profilePhotoUid = uid;
    if (mounted) {
      setState(() {
        _profilePhotoPath = null;
        _userName = _resolveUserName(user);
      });
    }
    if (uid.isNotEmpty) unawaited(_loadProfilePhoto(uid));
  }

  String _resolveUserName(User? user) {
    if (user == null) return 'User';
    final session = sl<SessionStorage>();
    final storedName = session.currentUserUid == user.uid
        ? session.currentUserName.trim()
        : '';
    if (storedName.isNotEmpty) return storedName;
    final displayName = user.displayName?.trim() ?? '';
    return displayName.isEmpty ? 'User' : displayName;
  }

  Future<void> _loadProfilePhoto(String uid) async {
    try {
      final path = await sl<LocalProfilePhotoStore>().getPhotoPath(uid);
      if (_ownsProfilePhoto(uid)) {
        setState(() => _profilePhotoPath = path);
      }
    } catch (_) {
      if (_ownsProfilePhoto(uid)) setState(() => _profilePhotoPath = null);
    }
  }

  bool _ownsProfilePhoto(String uid) =>
      mounted &&
      uid.isNotEmpty &&
      _profilePhotoUid == uid &&
      FirebaseAuth.instance.currentUser?.uid == uid;

  Future<void> _initUserBox() async {
    final sessionStorage = sl<SessionStorage>();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final uid = firebaseUser?.uid ?? '';

    if (uid.isEmpty) {
      await sessionStorage.markLoggedOut();
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppNavigator.login,
        (route) => false,
      );
      return;
    }

    _userName = _resolveUserName(firebaseUser);
    _profilePhotoUid = uid;
    unawaited(_loadProfilePhoto(uid));
    // Background, never blocks Home: language, device time zone and the
    // first preference document for this verified account.
    unawaited(
      sl<NotificationPreferencesSync>().syncCurrentAccount(
        languageCode: context.read<LocaleCubit>().state.languageCode,
      ),
    );
    await sessionStorage.updateCurrentUserUid(uid);

    // فتح ال[ص]ندوق الخاص بالمستخدم الحالي — through the shared
    // UserStorageManager (Stage 3): Hom no longer opens this box
    // independently. It still keeps the returned reference locally
    // because ValueListenableBuilder genuinely needs a Box instance,
    // but opening and (on logout) closing are both owned centrally now.
    exerciseBox = await sl<UserStorageManager>().getUserBox<ExerciseSet>(
      'sets',
      uid,
    );

    // Local inactivity reminders for THIS account (cancels any previous
    // account's first). Background; never blocks Home.
    unawaited(sl<InactivityReminderScheduler>().activate(uid));

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
    final colors = context.appColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.logoutConfirmTitle,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          '${l10n.logoutConfirmBody}\n\n${l10n.settingsLogoutDescription}',
          style: TextStyle(color: colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              // 1. Capture the OUTGOING uid FIRST — before anything
              //    else can invalidate it (FirebaseAuth.signOut below
              //    makes currentUser null).
              final outgoingUid = FirebaseAuth.instance.currentUser?.uid;

              // Stop building per-user UI before anything below closes its
              // boxes (see _signingOut).
              if (mounted) setState(() => _signingOut = true);

              try {
                // The outgoing account's reminders never outlive its
                // session (and stop watching its boxes before they close).
                await sl<InactivityReminderScheduler>().deactivate();
                if (outgoingUid != null && outgoingUid.isNotEmpty) {
                  await sl<FcmDeviceService>().unregisterCurrentDeviceToken(
                    expectedUid: outgoingUid,
                  );
                }

                // 2. Reset WorkoutSessionCubit's in-memory state first
                //    (Phase 21 audit fix, unchanged) — its last-emitted
                //    state must never leak into whichever user signs in
                //    next on this device/process.
                sl<WorkoutSessionCubit>().reset();

                // 3. Close every per-user box owned for the outgoing
                //    uid through the central manager. Never deletes
                //    data. Propagates failure — a close problem must
                //    not be treated as a successful logout.
                if (outgoingUid != null && outgoingUid.isNotEmpty) {
                  await sl<UserStorageManager>().closeForUser(outgoingUid);
                }
                // 4. Drop Hom's own cached reference — it's now closed
                //    (or, on failure below, we're about to show an
                //    error and stay on this screen regardless).
                exerciseBox = null;

                // 5. Clear the local Hive session record.
                await sl<SessionStorage>().clearSession();

                // 6. Sign out of Firebase last.
                await FirebaseAuth.instance.signOut();

                // 7. Navigate only after every step above succeeded.
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppNavigator.login,
                    (route) => false,
                  );
                }
              } catch (error, stackTrace) {
                // Never show raw exception/infrastructure details to
                // the user; log the real cause through the project's
                // existing debug convention instead. Logout is
                // retryable, not transactional — earlier steps that
                // already succeeded (e.g. WorkoutSessionCubit.reset())
                // are not rolled back, but nothing here deletes data,
                // and the user remains on this screen rather than
                // being navigated away as if logout fully completed.
                debugPrint('Logout failed: $error\n$stackTrace');
                // Localized through the State's own `context`, guarded by
                // this State's own `mounted` — the same pattern this screen already
                // uses on the success path above.
                if (mounted) {
                  AppFeedback.error(
                    AppLocalizations.of(context)!.logoutFailedMessage,
                  );
                  unawaited(_restoreAfterFailedLogout());
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              l10n.logoutTooltip,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  /// A logout that failed part-way may already have closed this user's
  /// boxes. Reopen them (the user is still signed in) before showing
  /// per-user UI again; until then Hom keeps its loading placeholder.
  Future<void> _restoreAfterFailedLogout() async {
    try {
      await _initUserBox();
    } catch (error, stackTrace) {
      debugPrint(
        'Restoring Home after a failed logout failed: $error\n$stackTrace',
      );
    }
    if (mounted) setState(() => _signingOut = false);
  }

  Future<void> _openPersonalHub() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await Navigator.pushNamed(
      context,
      AppNavigator.personalHub,
      arguments: PersonalHubArgs(onLogout: _logout),
    );
    await _refreshProfile(uid);
  }

  /// The More tab can rename the user or change the photo; mirror it on Home.
  Future<void> _refreshProfile([String? uid]) async {
    uid ??= FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
    final savedName = sl<SessionStorage>().currentUserName.trim();
    if (savedName.isNotEmpty && savedName != _userName) {
      setState(() => _userName = savedName);
    }
    await _loadProfilePhoto(uid);
  }

  Future<void> _openAppSettings() async {
    await Navigator.pushNamed(
      context,
      AppNavigator.appSettings,
      arguments: AppSettingsArgs(onLogout: _logout),
    );
  }

  // _groupExercises (the old date|exerciseName grouping used by Home's
  // flat exercise-card list) was removed along with that list — Home
  // now shows session-level cards via HomeWorkoutOverviewSection. The
  // progress analysis below uses completed session links so comparisons
  // stay within the selected program and workout day.

  double _calculateTodayVolume() {
    if (exerciseBox == null) return 0.0;
    final todayStr = DateFormat('yyyy-MM-dd', 'en_US').format(DateTime.now());
    return exerciseBox!.values
        .where((set) {
          return DateFormat('yyyy-MM-dd', 'en_US').format(set.date) == todayStr;
        })
        .fold(0.0, (sum, set) => sum + (set.weight * set.reps));
  }

  Future<void> _showProgressAnalysis() async {
    if (exerciseBox == null) return;
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final analyticsScreenContext = context;
    late final List<HomeExerciseProgressHistory> histories;
    try {
      final programRepository = sl<WorkoutProgramRepository>();
      final templateRepository = sl<WorkoutTemplateRepository>();
      final sessionRepository = sl<WorkoutSessionRepository>();
      final programBox = await programRepository.getUserBox();
      final templateBox = await templateRepository.getUserBox();
      final sessionBox = await sessionRepository.getUserBox();
      histories = const HomeProgressComparisonService().build(
        programs: programBox.values.toList(),
        templates: templateBox.values.toList(),
        sessions: sessionBox.values.toList(),
        sets: exerciseBox!.values.toList(),
      );
    } catch (error, stackTrace) {
      debugPrint('Home progress history load failed: $error\n$stackTrace');
      return;
    }
    if (!mounted) return;

    final programs = <String, String>{};
    for (final history in histories) {
      programs.putIfAbsent(history.programId, () => history.programName);
    }
    String? selectedProgramId = programs.keys.firstOrNull;
    String? selectedTemplateId = histories
        .where((history) => history.programId == selectedProgramId)
        .map((history) => history.workoutTemplateId)
        .firstOrNull;
    String? selectedExerciseKey = histories
        .where(
          (history) =>
              history.programId == selectedProgramId &&
              history.workoutTemplateId == selectedTemplateId,
        )
        .map((history) => history.exerciseKey)
        .firstOrNull;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final templates = <String, String>{};
          for (final history in histories.where(
            (history) => history.programId == selectedProgramId,
          )) {
            templates.putIfAbsent(
              history.workoutTemplateId,
              () => history.workoutTemplateName,
            );
          }
          final exercises = <String, String>{};
          for (final history in histories.where(
            (history) =>
                history.programId == selectedProgramId &&
                history.workoutTemplateId == selectedTemplateId,
          )) {
            exercises.putIfAbsent(
              history.exerciseKey,
              () => history.exerciseName,
            );
          }
          final selectedHistory = histories
              .where(
                (history) =>
                    history.programId == selectedProgramId &&
                    history.workoutTemplateId == selectedTemplateId &&
                    history.exerciseKey == selectedExerciseKey,
              )
              .firstOrNull;
          final currentVolume = selectedHistory?.currentVolume;
          final previousVolume = selectedHistory?.previousVolume;
          final diff = currentVolume != null && previousVolume != null
              ? currentVolume - previousVolume
              : 0.0;

          return DraggableScrollableSheet(
            initialChildSize: 0.82,
            minChildSize: 0.45,
            maxChildSize: 0.92,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.arrow_back_ios_new),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.history),
                        label: Text(l10n.historyLabel),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.analytics_outlined),
                        label: Text(l10n.analyticsLabel),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.progressAnalyticsTitle,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (histories.isEmpty)
                    _AnalyticsNoticeCard(text: l10n.progressNoCompletedHistory)
                  else ...[
                    _progressDropdown<String>(
                      label: l10n.progressSelectProgram,
                      value: selectedProgramId,
                      options: programs,
                      onChanged: (value) => setSheetState(() {
                        selectedProgramId = value;
                        selectedTemplateId = histories
                            .where((history) => history.programId == value)
                            .map((history) => history.workoutTemplateId)
                            .firstOrNull;
                        selectedExerciseKey = histories
                            .where(
                              (history) =>
                                  history.programId == value &&
                                  history.workoutTemplateId ==
                                      selectedTemplateId,
                            )
                            .map((history) => history.exerciseKey)
                            .firstOrNull;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _progressDropdown<String>(
                      label: l10n.progressSelectWorkoutDay,
                      value: selectedTemplateId,
                      options: templates,
                      onChanged: (value) => setSheetState(() {
                        selectedTemplateId = value;
                        selectedExerciseKey = histories
                            .where(
                              (history) =>
                                  history.programId == selectedProgramId &&
                                  history.workoutTemplateId == value,
                            )
                            .map((history) => history.exerciseKey)
                            .firstOrNull;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _progressDropdown<String>(
                      label: l10n.progressSelectExercise,
                      value: selectedExerciseKey,
                      options: exercises,
                      onChanged: (value) =>
                          setSheetState(() => selectedExerciseKey = value),
                    ),
                    const SizedBox(height: 18),
                    if (selectedHistory == null || previousVolume == null)
                      _AnalyticsNoticeCard(
                        text: l10n.exerciseNeedsMoreData(
                          selectedHistory?.exerciseName ?? '',
                        ),
                      )
                    else
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          final percentage = previousVolume > 0
                              ? (diff / previousVolume) * 100
                              : 0.0;
                          Navigator.pushNamed(
                            analyticsScreenContext,
                            AppNavigator.workoutAnalytics,
                            arguments: WorkoutAnalyticsArgs(
                              exerciseName: selectedHistory.exerciseName,
                              totalVolume: selectedHistory.currentVolume
                                  .toStringAsFixed(0),
                              progressDelta: percentage.toStringAsFixed(1),
                            ),
                          );
                        },
                        child: _AnalyticsCard(
                          title: selectedHistory.exerciseName,
                          subtitle: l10n.lastPreviousVolume(
                            selectedHistory.currentVolume.toStringAsFixed(0),
                            previousVolume.toStringAsFixed(0),
                          ),
                          improved: diff >= 0,
                          diff: diff,
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 8,
                      ),
                      child: Text(l10n.close),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _progressDropdown<T>({
    required String label,
    required T? value,
    required Map<T, String> options,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: ValueKey('$label:$value'),
      initialValue: options.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: options.entries
          .map(
            (entry) => DropdownMenuItem<T>(
              value: entry.key,
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: options.isEmpty ? null : onChanged,
    );
  }

  void _onWorkoutStateChanged(BuildContext context, WorkoutState state) {
    if (state is WorkoutSuccess) {
      if (exerciseBox != state.box) {
        setState(() => exerciseBox = state.box);
      }
      return;
    }

    if (state is WorkoutError) {
      AppFeedback.error(
        localizeOperationError(AppLocalizations.of(context)!, state.message),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // No per-user UI without an open box: while loading, while signing out,
    // and in the signed-out redirect (where no box is opened at all).
    if (_isLoading || _signingOut || exerciseBox == null) {
      return const Scaffold(body: ShimmerHome());
    }
    return MultiBlocListener(
      listeners: [
        BlocListener<WorkoutCubit, WorkoutState>(
          listener: _onWorkoutStateChanged,
        ),
        BlocListener<WorkoutSessionCubit, WorkoutSessionState>(
          listener: (context, state) {
            if (state is! WorkoutSessionLoading) {
              context.read<HomeWorkoutOverviewCubit>().loadOverview();
            }
          },
        ),
      ],
      child: HomeDashboard(
        name: _userName.trim(),
        photoPath: _profilePhotoPath,
        currentUserId: () => FirebaseAuth.instance.currentUser?.uid,
        onProfile: _openPersonalHub,
        onSettings: _openAppSettings,
        onProgressAnalysis: _showProgressAnalysis,
        programsTab: (_) => const WorkoutProgramsScreen(),
        progressTab: (_) => const MyProgressScreen(),
        // The tab stays mounted, so the header is refreshed when the More
        // tab actually changes the name or photo, not on every tab switch.
        moreTab: (_) => PersonalHubScreen(
          onLogout: _logout,
          onProfileChanged: () => unawaited(_refreshProfile()),
        ),
        onImageError: () {
          final uid = _profilePhotoUid;
          final failedPath = _profilePhotoPath;
          if (failedPath != null &&
              _ownsProfilePhoto(uid) &&
              _profilePhotoPath == failedPath) {
            setState(() => _profilePhotoPath = null);
          }
        },
        volume: _buildVolumePanel(),
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Widget _buildVolumePanel() {
    final l10n = AppLocalizations.of(context)!;
    final dateLocale = Localizations.localeOf(context).toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border),
      ),
      child: ValueListenableBuilder(
        valueListenable: exerciseBox!.listenable(),
        builder: (context, box, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.todaysVolumeLabel,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  DateFormat('EEE, MMM d', dateLocale).format(DateTime.now()),
                  style: TextStyle(color: context.appColors.textMuted),
                ),
                Text(
                  _calculateTodayVolume().toStringAsFixed(1),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
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
    final colors = context.appColors;
    final color = improved ? colors.success : colors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
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
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Icon(
                  improved ? Icons.arrow_upward : Icons.arrow_downward,
                  color: color,
                ),
                Text(
                  '${improved ? '+' : ''}${diff.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
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

class _AnalyticsNoticeCard extends StatelessWidget {
  final String text;
  const _AnalyticsNoticeCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: colors.textMuted, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// _ExerciseDialog (the shared weight/reps/optional-name dialog behind
// the old manual one-off exercise entry) was removed along with
// _showAddExerciseDialog — its only caller.
