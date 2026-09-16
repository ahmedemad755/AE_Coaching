import 'dart:async';

import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_completion_summary_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/log_set_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/name_only_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/rest_timer_widget.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
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
  State<ActiveWorkoutSessionScreen> createState() => _ActiveWorkoutSessionScreenState();
}

class _ActiveWorkoutSessionScreenState extends State<ActiveWorkoutSessionScreen> {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  late Timer _ticker;
  Duration _elapsed = Duration.zero;

  /// Local copy of the session's note — `widget.session` itself is an
  /// immutable route argument, never refreshed after a note edit, so
  /// this is what the UI actually reflects. Seeded once in [initState].
  late String? _sessionNote = widget.session.workoutNote;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    // Recomputes from the absolute wall-clock difference every tick —
    // robust to backgrounding/locking, unlike a naive incrementing
    // counter that would pause along with the app.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _updateElapsed());
    context.read<SessionExerciseCubit>().loadForSession(widget.session);
  }

  void _updateElapsed() {
    if (!mounted) return;
    setState(() => _elapsed = DateTime.now().difference(widget.session.startedAt));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Future<void> _confirmCancel() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.cancelWorkoutConfirmTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(l10n.cancelWorkoutConfirmBody, style: const TextStyle(color: _muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text(l10n.cancelWorkoutButton),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<WorkoutSessionCubit>().cancelWorkout(widget.session.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _confirmFinish() async {
    final l10n = AppLocalizations.of(context)!;
    final exerciseState = context.read<SessionExerciseCubit>().state;
    final totalVolume = exerciseState is SessionExerciseLoaded ? exerciseState.totalVolume : 0.0;
    final volumeText = totalVolume.toStringAsFixed(totalVolume.truncateToDouble() == totalVolume ? 0 : 1);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.finishWorkoutConfirmTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(l10n.finishWorkoutConfirmBody(volumeText), style: const TextStyle(color: _muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
            child: Text(l10n.finishWorkoutButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final sessionCubit = context.read<WorkoutSessionCubit>();
    final exerciseCubit = context.read<SessionExerciseCubit>();
    final completedSession = await sessionCubit.finishWorkout(
      sessionId: widget.session.id,
      totalVolume: totalVolume,
    );
    if (!mounted) return;

    if (completedSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unableToFinishWorkoutError), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Phase 11/12 comparison + PR detection, computed once right here
    // — the summary screen itself does no storage access of its own.
    final result = await exerciseCubit.buildCompletionSummary(completedSession);
    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      AppNavigator.workoutCompletionSummary,
      arguments: WorkoutCompletionSummaryArgs(
        workoutName: completedSession.workoutNameSnapshot,
        progressSummary: result.progressSummary,
        personalRecords: result.personalRecords,
      ),
    );
  }

  Future<void> _logSetFor(String exerciseName, {List<ExerciseSet> previousSets = const []}) async {
    final result = await showDialog<LogSetResult>(
      context: context,
      builder: (_) => LogSetDialog(exerciseName: exerciseName, previousSets: previousSets),
    );
    if (result == null || !mounted) return;

    await context.read<SessionExerciseCubit>().logSet(
          session: widget.session,
          exerciseName: exerciseName,
          weight: result.weight,
          reps: result.reps,
          notes: result.notes,
        );
  }

  Future<void> _editSessionNote() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _sessionNote ?? '');
    final newNote = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.editSessionNoteTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l10n.sessionNoteHint,
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xffd5e3f2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _blue),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
            child: Text(l10n.saveNoteButton),
          ),
        ],
      ),
    );
    if (newNote == null || !mounted) return;

    try {
      final updated = await context.read<WorkoutSessionCubit>().updateSessionNote(
            sessionId: widget.session.id,
            note: newNote,
          );
      if (mounted) setState(() => _sessionNote = updated.workoutNote);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.unableToSaveNoteError), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _addNewExercise() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameOnlyDialog(
        title: l10n.addNewExerciseTitle,
        hint: l10n.exerciseNameHint,
        saveLabel: l10n.save,
        cancelLabel: l10n.cancel,
        emptyValueMessage: l10n.exerciseNameRequiredError,
      ),
    );
    if (name == null || !mounted) return;
    await _logSetFor(name);
  }

  Future<void> _confirmDeleteSet(ExerciseSet set) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.deleteSetTooltip, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<SessionExerciseCubit>().deleteSet(widget.session, set);
    }
  }

  Widget _buildExerciseRow(SessionExerciseRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: row.isReferenceOnly ? Colors.white.withValues(alpha: 0.6) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: row.isReferenceOnly
            ? const BorderSide(color: Color(0xffd5e3f2), style: BorderStyle.solid)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.exerciseName,
                    style: const TextStyle(color: _dark, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.addSetTooltip,
                  icon: const Icon(Icons.add_circle_outline, color: _blue),
                  onPressed: () => _logSetFor(row.exerciseName, previousSets: row.previousSets),
                ),
              ],
            ),
            if (row.previousSets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${AppLocalizations.of(context)!.lastTimeLabel}: '
                  '${row.previousSets.map((s) => '${s.weight}${AppLocalizations.of(context)!.kgUnit} × ${s.reps}').join(', ')}',
                  style: const TextStyle(color: _muted, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            if (row.isReferenceOnly)
              Text(
                AppLocalizations.of(context)!.suggestedFromLastTimeLabel,
                style: const TextStyle(color: _muted, fontSize: 12, fontStyle: FontStyle.italic),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final set in row.sets)
                    Tooltip(
                      // Only wraps in a real tooltip when this set has
                      // a note (Phase 18) — an empty message would
                      // still show an empty bubble, so this is the one
                      // affordance to view a per-set note.
                      message: set.notes ?? '',
                      triggerMode: set.notes == null ? TooltipTriggerMode.manual : null,
                      child: InputChip(
                        label: Text(
                          set.notes != null
                              ? '${set.weight}${AppLocalizations.of(context)!.kgUnit} × ${set.reps} 📝'
                              : '${set.weight}${AppLocalizations.of(context)!.kgUnit} × ${set.reps}',
                        ),
                        onDeleted: () => _confirmDeleteSet(set),
                        deleteIconColor: Colors.redAccent,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xfff5f9fc),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Text(widget.session.workoutNameSnapshot),
        actions: [
          IconButton(
            icon: Icon(_sessionNote == null ? Icons.note_add_outlined : Icons.note),
            tooltip: l10n.sessionNoteTooltip,
            onPressed: _editSessionNote,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewExercise,
        backgroundColor: _blue,
        icon: const Icon(Icons.add),
        label: Text(l10n.newExerciseButton),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  l10n.elapsedTimeLabel,
                  style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatElapsed(_elapsed),
                  style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 48),
                ),
              ],
            ),
          ),
          const RestTimerWidget(),
          Expanded(
            child: BlocBuilder<SessionExerciseCubit, SessionExerciseState>(
              builder: (context, state) {
                if (state is SessionExerciseLoaded) {
                  if (state.rows.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          l10n.noExercisesLoggedYetBody,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _muted),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [for (final row in state.rows) _buildExerciseRow(row)],
                  );
                }
                if (state is SessionExerciseError) {
                  return Center(child: Text(state.message, style: const TextStyle(color: Colors.redAccent)));
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmFinish,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(l10n.finishWorkoutButton, style: const TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _confirmCancel,
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    label: Text(
                      l10n.cancelWorkoutButton,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
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
