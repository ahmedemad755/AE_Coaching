import 'dart:async';

import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/active_workout_edit_service.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_completion_summary_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/log_set_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_library_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/rest_timer_widget.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_exercise_targets_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Route arguments for [ActiveWorkoutSessionScreen].
class ActiveWorkoutSessionArgs {
  final WorkoutSession session;

  const ActiveWorkoutSessionArgs({required this.session});
}

String _formatElapsed(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// Shows the currently in-progress workout session with a live elapsed
/// timer (Phase 7), exercise logging with auto-loaded structure and
/// previous performance (Phase 8/9), Finish Workout (Phase 10), an
/// optional rest timer (Phase 17), and session/exercise-level notes
/// (Phase 18).
class ActiveWorkoutSessionScreen extends StatefulWidget {
  final WorkoutSession session;

  const ActiveWorkoutSessionScreen({super.key, required this.session});

  @override
  State<ActiveWorkoutSessionScreen> createState() =>
      _ActiveWorkoutSessionScreenState();
}

class _ActiveWorkoutSessionScreenState extends State<ActiveWorkoutSessionScreen>
    with WidgetsBindingObserver {
  static const Color _blue = Color(0xff2f80ed);

  late Timer _ticker;
  Duration _elapsed = Duration.zero;
  bool _isFinishing = false;
  bool _isChangingExercises = false;
  bool _isLoggingSet = false;
  final Set<ExerciseSet> _completedSets = <ExerciseSet>{};
  final Set<ExerciseSet> _restedSets = <ExerciseSet>{};
  ExerciseSet? _setCurrentlyResting;

  /// Local copy of the session's note — `widget.session` itself is an
  /// immutable route argument, never refreshed after a note edit, so
  /// this is what the UI actually reflects. Seeded once in [initState].
  late String? _sessionNote = widget.session.workoutNote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateElapsed();
    // Recomputes from the absolute wall-clock difference every tick —
    // robust to backgrounding/locking, unlike a naive incrementing
    // counter that would pause along with the app.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateElapsed(),
    );
    context.read<SessionExerciseCubit>().loadForSession(widget.session);
  }

  void _updateElapsed() {
    if (!mounted) return;
    setState(
      () => _elapsed = DateTime.now().difference(widget.session.startedAt),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _confirmCancel() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.cancelWorkoutConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          l10n.cancelWorkoutConfirmBody,
          style: TextStyle(color: ctx.appColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.appColors.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.cancelWorkoutButton),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<WorkoutSessionCubit>().cancelWorkout(
        widget.session.id,
      );
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _confirmFinish() async {
    if (_editingBlocked) return;
    setState(() => _isFinishing = true);
    final l10n = AppLocalizations.of(context)!;
    late final List<ExerciseSet> validSets;
    try {
      validSets = await context
          .read<SessionExerciseCubit>()
          .getValidSetsForSession(widget.session);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFinishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unableToFinishWorkoutError),
          backgroundColor: context.appColors.error,
        ),
      );
      return;
    }
    if (!mounted) return;
    if (validSets.isEmpty) {
      final discardConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            l10n.discardEmptyWorkoutTitle,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            l10n.discardEmptyWorkoutBody,
            style: TextStyle(color: ctx.appColors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.keepTrainingButton),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ctx.appColors.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              child: Text(l10n.discardWorkoutButton),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (discardConfirmed != true) {
        setState(() => _isFinishing = false);
        return;
      }

      final sessionCubit = context.read<WorkoutSessionCubit>();
      await sessionCubit.cancelWorkout(widget.session.id);
      if (!mounted) return;
      if (sessionCubit.state is WorkoutSessionNone) {
        Navigator.pop(context);
      } else {
        setState(() => _isFinishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.unableToFinishWorkoutError),
            backgroundColor: context.appColors.error,
          ),
        );
      }
      return;
    }

    final totalVolume = validSets.fold<double>(
      0,
      (sum, set) => sum + set.weight * set.reps,
    );
    final volumeText = totalVolume.toStringAsFixed(
      totalVolume.truncateToDouble() == totalVolume ? 0 : 1,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.finishWorkoutConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          l10n.finishWorkoutConfirmBody(volumeText),
          style: TextStyle(color: ctx.appColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
              foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
            ),
            child: Text(l10n.finishWorkoutButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      if (mounted) setState(() => _isFinishing = false);
      return;
    }

    final sessionCubit = context.read<WorkoutSessionCubit>();
    final exerciseCubit = context.read<SessionExerciseCubit>();
    final completedSession = await sessionCubit.finishWorkout(
      sessionId: widget.session.id,
      totalVolume: totalVolume,
      hasValidCompletedSet: true,
    );
    if (!mounted) return;

    if (completedSession == null) {
      setState(() => _isFinishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unableToFinishWorkoutError),
          backgroundColor: context.appColors.error,
        ),
      );
      return;
    }

    if (!completedSession.isCompleted) {
      setState(() => _isFinishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unableToFinishWorkoutError),
          backgroundColor: context.appColors.error,
        ),
      );
      return;
    }

    List<ExerciseSet> persistedValidSets;
    try {
      persistedValidSets = await exerciseCubit.getValidSetsForSession(
        completedSession,
      );
    } catch (_) {
      persistedValidSets = validSets;
    }
    if (!mounted) return;

    // Existing progress and PR results are kept in the same completion
    // experience; the completion dialog is only opened after persistence.
    final result = await exerciseCubit.buildCompletionSummary(completedSession);
    if (!mounted) return;

    final exerciseCount = persistedValidSets
        .map((set) => set.exerciseName.trim().toLowerCase())
        .toSet()
        .length;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WorkoutCompletionSummaryScreen(
        args: WorkoutCompletionSummaryArgs(
          session: completedSession,
          recordedExerciseCount: exerciseCount,
          validSetCount: persistedValidSets.length,
          progressSummary: result.progressSummary,
          personalRecords: result.personalRecords,
        ),
      ),
    );
    if (!mounted) return;
  }

  Future<void> _logSetFor(
    String exerciseName, {
    List<ExerciseSet> previousSets = const [],
  }) async {
    if (_editingBlocked || !_canAddSet) {
      _showAddSetBlockedMessage();
      return;
    }
    setState(() => _isLoggingSet = true);
    try {
      final result = await showDialog<LogSetResult>(
        context: context,
        builder: (_) => LogSetDialog(
          exerciseName: exerciseName,
          previousSets: previousSets,
        ),
      );
      if (result == null || !mounted) return;
      if (!_restAllowsAddingSet) {
        _showAddSetBlockedMessage();
        return;
      }

      await context.read<SessionExerciseCubit>().logSet(
        session: widget.session,
        exerciseName: exerciseName,
        weight: result.weight,
        reps: result.reps,
        notes: result.notes,
      );
    } finally {
      if (mounted) setState(() => _isLoggingSet = false);
    }
  }

  Future<void> _editSessionNote() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _sessionNote ?? '');
    final newNote = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.editSessionNoteTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l10n.sessionNoteHint,
            filled: true,
            fillColor: ctx.appColors.surfaceRaised,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: ctx.appColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(ctx).colorScheme.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
              foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
            ),
            child: Text(l10n.saveNoteButton),
          ),
        ],
      ),
    );
    if (newNote == null || !mounted) return;

    try {
      final updated = await context
          .read<WorkoutSessionCubit>()
          .updateSessionNote(sessionId: widget.session.id, note: newNote);
      if (mounted) setState(() => _sessionNote = updated.workoutNote);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.unableToSaveNoteError),
            backgroundColor: context.appColors.error,
          ),
        );
      }
    }
  }

  WorkoutSession get _currentSession {
    final state = context.read<SessionExerciseCubit>().state;
    return state is SessionExerciseLoaded
        ? state.session ?? widget.session
        : widget.session;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_isChangingExercises &&
        !_isFinishing) {
      context.read<SessionExerciseCubit>().refreshForSession(widget.session);
    }
  }

  bool get _editingBlocked =>
      _isChangingExercises ||
      _isFinishing ||
      _isLoggingSet ||
      _currentSession.pendingProgramExerciseEdit != null ||
      !_currentSession.isInProgress;

  Future<ActiveWorkoutEditScope?> _chooseExerciseDestination() async {
    final l10n = AppLocalizations.of(context)!;
    var scope = ActiveWorkoutEditScope.sessionOnly;
    return showDialog<ActiveWorkoutEditScope>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(l10n.exerciseChangeDestinationTitle),
          content: RadioGroup<ActiveWorkoutEditScope>(
            groupValue: scope,
            onChanged: (value) => update(() => scope = value!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.activeExerciseScopeBody),
                RadioListTile<ActiveWorkoutEditScope>(
                  title: Text(l10n.activeSessionOnly),
                  value: ActiveWorkoutEditScope.sessionOnly,
                ),
                RadioListTile<ActiveWorkoutEditScope>(
                  title: Text(l10n.activeSessionAndProgram),
                  value: ActiveWorkoutEditScope.sessionAndProgram,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop<ActiveWorkoutEditScope>(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop<ActiveWorkoutEditScope>(dialogContext, scope),
              child: Text(l10n.activeApplyEdit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNewExercise() => _pickExercise();
  Future<void> _replaceExercise(SessionExerciseRow row) =>
      _pickExercise(replacing: row);

  Future<void> _pickExercise({SessionExerciseRow? replacing}) async {
    if (_editingBlocked) return;
    if (replacing != null && replacing.sets.isNotEmpty) {
      _showExerciseSaveError(
        const ActiveWorkoutEditException(ActiveWorkoutEditFailure.loggedSets),
      );
      return;
    }
    setState(() => _isChangingExercises = true);
    try {
      final scope = await _chooseExerciseDestination();
      if (scope == null || !mounted) return;
      final state = context.read<SessionExerciseCubit>().state;
      final rows = state is SessionExerciseLoaded
          ? state.rows
          : <SessionExerciseRow>[];
      final others = rows
          .where((row) => row.exerciseName != replacing?.exerciseName)
          .toList();
      final language = Localizations.localeOf(context).languageCode;
      final saved = await showDialog<List<ExerciseLibraryItem>>(
        context: context,
        builder: (_) => ExerciseLibraryScreen(
          catalog: sl<CombinedExerciseLibraryCatalog>(),
          customExercises: sl<CustomExerciseRepository>(),
          languageCode: language,
          singleSelectionOnly: replacing != null,
          saveErrorMessage: _exerciseSaveErrorMessage,
          excludedIds: others
              .map((r) => r.assignment?.exerciseId)
              .whereType<String>()
              .toSet(),
          excludedNames: others.map((r) => r.exerciseName).toSet(),
          onAddSelected: (selected) =>
              context.read<SessionExerciseCubit>().editActiveExercises(
                session: _currentSession,
                action: replacing == null
                    ? ActiveWorkoutEditAction.add
                    : ActiveWorkoutEditAction.replace,
                scope: scope,
                exerciseName: replacing?.exerciseName,
                exercises: selected,
                languageCode: language,
              ),
        ),
      );
      if (saved != null) _showEditSuccess(scope);
    } catch (error) {
      _showExerciseSaveError(error);
    } finally {
      if (mounted) setState(() => _isChangingExercises = false);
    }
  }

  Future<void> _removeExercise(SessionExerciseRow row) async {
    if (_editingBlocked) return;
    if (row.sets.isNotEmpty) {
      _showExerciseSaveError(
        const ActiveWorkoutEditException(ActiveWorkoutEditFailure.loggedSets),
      );
      return;
    }
    setState(() => _isChangingExercises = true);
    try {
      final scope = await _chooseExerciseDestination();
      if (scope == null || !mounted) return;
      await context.read<SessionExerciseCubit>().editActiveExercises(
        session: _currentSession,
        action: ActiveWorkoutEditAction.remove,
        scope: scope,
        exerciseName: row.exerciseName,
      );
      _showEditSuccess(scope);
    } catch (error) {
      _showExerciseSaveError(error);
    } finally {
      if (mounted) setState(() => _isChangingExercises = false);
    }
  }

  Future<void> _editTargets(SessionExerciseRow row) async {
    if (_editingBlocked) return;
    setState(() => _isChangingExercises = true);
    try {
      final scope = await _chooseExerciseDestination();
      if (scope == null || !mounted) return;
      final initial =
          row.assignment ??
          WorkoutTemplateExerciseAssignment(
            assignmentId: row.assignmentId ?? '',
            exerciseId: '',
            exerciseNameSnapshot: row.exerciseName,
            referenceType: WorkoutExerciseReferenceType.manual.name,
          );
      final targets = await showDialog<WorkoutTemplateExerciseAssignment>(
        context: context,
        builder: (_) => WorkoutExerciseTargetsDialog(assignment: initial),
      );
      if (targets == null || !mounted) return;
      await context.read<SessionExerciseCubit>().editActiveExercises(
        session: _currentSession,
        action: ActiveWorkoutEditAction.targets,
        scope: scope,
        exerciseName: row.exerciseName,
        targets: targets,
      );
      _showEditSuccess(scope);
    } catch (error) {
      _showExerciseSaveError(error);
    } finally {
      if (mounted) setState(() => _isChangingExercises = false);
    }
  }

  Future<void> _applyProgramExercises() async {
    if (_editingBlocked) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isChangingExercises = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.activeApplyProgram),
          content: Text(l10n.activeApplyProgramBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.activeApplyEdit),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await context.read<SessionExerciseCubit>().editActiveExercises(
        session: _currentSession,
        action: ActiveWorkoutEditAction.applyProgram,
      );
      _showEditSuccess(ActiveWorkoutEditScope.sessionOnly);
    } catch (error) {
      _showExerciseSaveError(error);
    } finally {
      if (mounted) setState(() => _isChangingExercises = false);
    }
  }

  Future<void> _resolvePending({bool keepSessionOnly = false}) async {
    if (_isChangingExercises) return;
    setState(() => _isChangingExercises = true);
    try {
      await context.read<SessionExerciseCubit>().resolvePendingEdit(
        _currentSession,
        keepSessionOnly: keepSessionOnly,
      );
    } catch (error) {
      _showExerciseSaveError(error);
    } finally {
      if (mounted) setState(() => _isChangingExercises = false);
    }
  }

  void _showEditSuccess(ActiveWorkoutEditScope scope) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          scope == ActiveWorkoutEditScope.sessionOnly
              ? l10n.activeSessionEditSaved
              : l10n.activeProgramEditSaved,
        ),
      ),
    );
  }

  void _showExerciseSaveError([Object? error]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_exerciseSaveErrorMessage(error)),
        backgroundColor: context.appColors.error,
      ),
    );
  }

  String _exerciseSaveErrorMessage(Object? error) {
    final l10n = AppLocalizations.of(context)!;
    final reason = error is ActiveWorkoutEditException ? error.reason : null;
    return switch (reason) {
      ActiveWorkoutEditFailure.loggedSets => l10n.activeLoggedExerciseProtected,
      ActiveWorkoutEditFailure.conflict => l10n.activeProgramConflict,
      ActiveWorkoutEditFailure.pending => l10n.activeProgramPending,
      ActiveWorkoutEditFailure.duplicate => l10n.activeDuplicateExercise,
      ActiveWorkoutEditFailure.inactive => l10n.activeWorkoutNoLongerActive,
      null => l10n.exerciseLibrarySaveError,
    };
  }

  Future<void> _confirmDeleteSet(ExerciseSet set) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.deleteSetTooltip,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.appColors.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<SessionExerciseCubit>().deleteSet(widget.session, set);
      if (mounted) setState(() => _completedSets.remove(set));
    }
  }

  void _markSetDone(ExerciseSet set, bool isDone) {
    final isLatestSet = identical(_latestRecordedSet, set);
    final hasRestInterval =
        context.read<RestTimerCubit>().state.configuredDuration > Duration.zero;
    setState(() {
      if (isDone) {
        _completedSets.add(set);
        if (isLatestSet) {
          _setCurrentlyResting = set;
          if (hasRestInterval) {
            _restedSets.remove(set);
          } else {
            _restedSets.add(set);
          }
        }
      } else {
        _completedSets.remove(set);
      }
    });
    if (isDone && isLatestSet && hasRestInterval) {
      context.read<RestTimerCubit>().startCountdown();
    }
  }

  ExerciseSet? get _latestRecordedSet {
    final current = context.read<SessionExerciseCubit>().state;
    if (current is! SessionExerciseLoaded) return null;
    ExerciseSet? latest;
    for (final set in current.rows.expand((row) => row.sets)) {
      if (latest == null || set.date.isAfter(latest.date)) latest = set;
    }
    return latest;
  }

  bool get _canAddSet {
    return !_isLoggingSet && _restAllowsAddingSet;
  }

  bool get _restAllowsAddingSet {
    if (context.read<RestTimerCubit>().state.isRunning) return false;
    final latest = _latestRecordedSet;
    if (latest == null) return true;
    if (!_completedSets.contains(latest)) return false;
    return !identical(_setCurrentlyResting, latest) ||
        _restedSets.contains(latest);
  }

  bool get _requiredRestPending {
    final latest = _latestRecordedSet;
    return latest != null &&
        identical(_setCurrentlyResting, latest) &&
        !_restedSets.contains(latest);
  }

  void _onRestTimerStarted() {
    final latest = _latestRecordedSet;
    if (latest == null) return;
    setState(() {
      _setCurrentlyResting = latest;
      _restedSets.remove(latest);
    });
  }

  void _onRestTimerCompleted() {
    final restingSet = _setCurrentlyResting;
    if (restingSet == null || !mounted) return;
    setState(() => _restedSets.add(restingSet));
  }

  void _showAddSetBlockedMessage() {
    final l10n = AppLocalizations.of(context)!;
    final message = _requiredRestPending
        ? l10n.waitForRestTimerLabel
        : l10n.markPreviousSetDoneLabel;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildExerciseRow(SessionExerciseRow row, {required int index}) {
    final colors = context.appColors;
    return Card(
      key: ValueKey('session-exercise-${row.exerciseName}'),
      margin: const EdgeInsets.only(bottom: 10),
      color: row.isReferenceOnly
          ? colors.surfaceRaised
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: row.isReferenceOnly
            ? BorderSide(color: colors.border, style: BorderStyle.solid)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDelayedDragStartListener(
                  index: index,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(Icons.drag_handle, color: colors.textMuted),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.exerciseName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (row.assignment?.hasTargets == true)
                        ExerciseTargetsSummary(assignment: row.assignment!),
                    ],
                  ),
                ),
                BlocBuilder<RestTimerCubit, RestTimerState>(
                  builder: (context, timerState) {
                    final canAddSet = !_editingBlocked && _canAddSet;
                    final l10n = AppLocalizations.of(context)!;
                    return IconButton(
                      tooltip: canAddSet
                          ? l10n.addSetTooltip
                          : (timerState.isRunning || _requiredRestPending
                                ? l10n.waitForRestTimerLabel
                                : l10n.markPreviousSetDoneLabel),
                      icon: Icon(
                        canAddSet
                            ? Icons.add_circle_outline
                            : Icons.hourglass_top,
                        color: canAddSet
                            ? Theme.of(context).colorScheme.primary
                            : context.appColors.textMuted,
                      ),
                      onPressed: canAddSet
                          ? () => _logSetFor(
                              row.exerciseName,
                              previousSets: row.previousSets,
                            )
                          : null,
                    );
                  },
                ),
                PopupMenuButton<String>(
                  key: ValueKey('session-exercise-actions-${row.exerciseName}'),
                  enabled: !_editingBlocked,
                  tooltip: AppLocalizations.of(context)!.edit,
                  onSelected: (action) {
                    if (action == 'replace') {
                      _replaceExercise(row);
                    } else if (action == 'remove') {
                      _removeExercise(row);
                    } else if (action == 'targets') {
                      _editTargets(row);
                    } else if (action == 'up' || action == 'down') {
                      final state = context.read<SessionExerciseCubit>().state;
                      if (state is SessionExerciseLoaded) {
                        _reorderSessionRows(
                          state.rows,
                          index,
                          action == 'up' ? index - 1 : index + 2,
                        );
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'targets',
                      child: Text(
                        AppLocalizations.of(context)!.editExerciseTargets,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'up',
                      enabled: index > 0,
                      child: Text(AppLocalizations.of(context)!.moveUpTooltip),
                    ),
                    PopupMenuItem(
                      value: 'down',
                      enabled:
                          context.read<SessionExerciseCubit>().state
                              is SessionExerciseLoaded &&
                          index <
                              (context.read<SessionExerciseCubit>().state
                                          as SessionExerciseLoaded)
                                      .rows
                                      .length -
                                  1,
                      child: Text(
                        AppLocalizations.of(context)!.moveDownTooltip,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'replace',
                      child: Text(
                        AppLocalizations.of(context)!.replaceExerciseAction,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        AppLocalizations.of(context)!.removeExerciseAction,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (row.previousSets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppLocalizations.of(context)!.lastTimeLabel}:',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    for (final previousSet in row.previousSets)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 8,
                          top: 2,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${previousSet.weight}${AppLocalizations.of(context)!.kgUnit} × ${previousSet.reps}',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            if (previousSet.notes?.trim().isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 8,
                                  bottom: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.sticky_note_2_outlined,
                                      size: 14,
                                      color: colors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        previousSet.notes!.trim(),
                                        style: TextStyle(
                                          color: colors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (row.isSessionOnly)
              Text(
                AppLocalizations.of(context)!.sessionOnlyExerciseLabel,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              )
            else if (row.isReferenceOnly && row.assignment == null)
              Text(
                AppLocalizations.of(context)!.suggestedFromLastTimeLabel,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (row.sets.isNotEmpty)
              Column(
                children: [
                  for (final set in row.sets)
                    Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _completedSets.contains(set),
                              onChanged: _isChangingExercises
                                  ? null
                                  : (value) => _markSetDone(set, value == true),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              semanticLabel:
                                  '${AppLocalizations.of(context)!.setDoneLabel}: '
                                  '${set.weight}${AppLocalizations.of(context)!.kgUnit} × ${set.reps}',
                            ),
                            Text(
                              AppLocalizations.of(context)!.setDoneLabel,
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: InputChip(
                                label: Text(
                                  '${set.weight}${AppLocalizations.of(context)!.kgUnit} × ${set.reps}',
                                ),
                                onDeleted: () => _confirmDeleteSet(set),
                                deleteIconColor: colors.error,
                              ),
                            ),
                          ],
                        ),
                        if (set.notes != null) ...[
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 72,
                              end: 12,
                              top: 2,
                              bottom: 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 16,
                                  color: colors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    set.notes!,
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reorderSessionRows(
    List<SessionExerciseRow> rows,
    int oldIndex,
    int newIndex,
  ) async {
    if (_editingBlocked || oldIndex == newIndex) return;
    if (newIndex > oldIndex) newIndex--;
    if (newIndex == oldIndex || newIndex < 0 || newIndex >= rows.length) return;
    final reordered = List<SessionExerciseRow>.of(rows);
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    setState(() => _isChangingExercises = true);
    try {
      final scope = await _chooseExerciseDestination();
      if (scope == null || !mounted) return;
      await context.read<SessionExerciseCubit>().editActiveExercises(
        session: _currentSession,
        action: ActiveWorkoutEditAction.reorder,
        scope: scope,
        orderedNames: reordered.map((row) => row.exerciseName).toList(),
      );
      _showEditSuccess(scope);
    } catch (error) {
      _showExerciseSaveError(error);
    } finally {
      if (mounted) setState(() => _isChangingExercises = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: isDark ? colors.canvas : _blue,
        foregroundColor: isDark ? colors.textPrimary : Colors.white,
        title: Text(widget.session.workoutNameSnapshot),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: FilledButton.icon(
              key: const ValueKey('active-add-exercise'),
              onPressed: _editingBlocked ? null : _addNewExercise,
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? primary : Colors.white,
                foregroundColor: isDark
                    ? Theme.of(context).colorScheme.onPrimary
                    : _blue,
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.newExerciseButton),
            ),
          ),
          PopupMenuButton<String>(
            enabled: !_editingBlocked,
            onSelected: (action) {
              if (action == 'apply') {
                _applyProgramExercises();
              }
              if (action == 'note') {
                _editSessionNote();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'apply',
                child: Text(l10n.activeApplyProgram),
              ),
              PopupMenuItem(
                value: 'note',
                child: Text(l10n.sessionNoteTooltip),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  l10n.elapsedTimeLabel,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatElapsed(_elapsed),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 48,
                  ),
                ),
              ],
            ),
          ),
          RestTimerWidget(
            lockCountdownControls: _requiredRestPending,
            onStarted: _onRestTimerStarted,
            onCompleted: _onRestTimerCompleted,
          ),
          Expanded(
            child: BlocBuilder<SessionExerciseCubit, SessionExerciseState>(
              builder: (context, state) {
                if (state is SessionExerciseLoaded) {
                  if (state.session?.pendingProgramExerciseEdit != null) {
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(l10n.activeProgramPending),
                            TextButton(
                              onPressed: _isChangingExercises
                                  ? null
                                  : () => _resolvePending(),
                              child: Text(l10n.activeRetryProgramEdit),
                            ),
                            TextButton(
                              onPressed: _isChangingExercises
                                  ? null
                                  : () =>
                                        _resolvePending(keepSessionOnly: true),
                              child: Text(l10n.activeKeepSessionEdit),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (state.rows.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          l10n.noExercisesLoggedYetBody,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textMuted),
                        ),
                      ),
                    );
                  }
                  return ReorderableListView.builder(
                    key: const PageStorageKey("active-exercises"),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    buildDefaultDragHandles: false,
                    itemCount: state.rows.length,
                    onReorder: (oldIndex, newIndex) =>
                        _reorderSessionRows(state.rows, oldIndex, newIndex),
                    itemBuilder: (context, index) {
                      final row = state.rows[index];
                      return _buildExerciseRow(row, index: index);
                    },
                  );
                }
                if (state is SessionExerciseError) {
                  return Center(
                    child: Text(
                      state.message,
                      style: TextStyle(color: colors.error),
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _editingBlocked ? null : _confirmFinish,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    l10n.finishWorkoutButton,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _editingBlocked ? null : _confirmCancel,
                  icon: Icon(Icons.close, color: colors.error),
                  label: Text(
                    l10n.cancelWorkoutButton,
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
