import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/active_workout_session_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_program_details_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/create_program_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/rename_program_dialog.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

/// My Programs — the first Programs UI. Shows the active program, a
/// list of previous/archived ones, and Create/Rename/Make Active/
/// Archive actions. No WorkoutTemplate/WorkoutSession UI lives here
/// yet (Phase 6+); "Open" navigates to a placeholder details screen.
class WorkoutProgramsScreen extends StatefulWidget {
  const WorkoutProgramsScreen({super.key});

  @override
  State<WorkoutProgramsScreen> createState() => _WorkoutProgramsScreenState();
}

class _WorkoutProgramsScreenState extends State<WorkoutProgramsScreen> {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _muted = Color(0xff7d8792);

  // Retains the last successfully loaded box across transient states
  // (background Firestore sync, or any action's brief Loading state)
  // so the screen never flashes a spinner/error over data that is
  // already on screen — same pattern used by every other feature.
  Box<WorkoutProgram>? _box;

  @override
  void initState() {
    super.initState();
    context.read<WorkoutProgramCubit>().loadPrograms();
    context.read<WorkoutSessionCubit>().checkActiveSession();
  }

  void _openActiveSession(WorkoutSession session) {
    // On finish (Phase 10/13), the active-session screen replaces
    // itself with the Workout Completion Summary screen, whose own
    // "Done" button pops straight back to here — nothing to react to
    // on the way back.
    Navigator.pushNamed(
      context,
      AppNavigator.activeWorkoutSession,
      arguments: ActiveWorkoutSessionArgs(session: session),
    );
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<CreateProgramResult>(
      context: context,
      builder: (_) => const CreateProgramDialog(),
    );
    if (result == null || !mounted) return;

    final cubit = context.read<WorkoutProgramCubit>();

    if (!result.makeActive) {
      cubit.createProgram(name: result.name, description: result.description, makeActive: false);
      return;
    }

    final box = _box;
    final currentActive = box != null ? cubit.repository.getActiveProgram(box) : null;

    if (currentActive == null) {
      cubit.createProgram(name: result.name, description: result.description, makeActive: true);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.makeActiveConfirmTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(
          l10n.makeActiveConfirmBodyWithCurrent(result.name),
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
            child: Text(l10n.makeActiveButton),
          ),
        ],
      ),
    );

    // Whether or not they confirm making it active, the create intent
    // itself is honored — declining only skips the activation switch.
    cubit.createProgram(name: result.name, description: result.description, makeActive: confirmed == true);
  }

  Future<void> _confirmMakeActive(WorkoutProgram program) async {
    final l10n = AppLocalizations.of(context)!;
    final box = _box;
    final currentActive = box != null ? context.read<WorkoutProgramCubit>().repository.getActiveProgram(box) : null;

    final body = currentActive == null
        ? l10n.makeActiveConfirmBodyNoCurrent(program.name)
        : l10n.makeActiveConfirmBodyWithCurrent(program.name);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.makeActiveConfirmTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(body, style: const TextStyle(color: _muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
            child: Text(l10n.makeActiveButton),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<WorkoutProgramCubit>().setActiveProgram(program.id);
    }
  }

  Future<void> _confirmArchive(WorkoutProgram program) async {
    final l10n = AppLocalizations.of(context)!;

    // Rule 6: confirmation is required when archiving the ACTIVE
    // program specifically (a real, felt consequence). Archiving an
    // already-inactive "previous" program is lower-stakes and proceeds
    // immediately — fewer modal steps for the common case.
    if (!program.isActive) {
      context.read<WorkoutProgramCubit>().archiveProgram(program.id);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.archiveActiveConfirmTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(l10n.archiveActiveConfirmBody(program.name), style: const TextStyle(color: _muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text(l10n.archiveButton),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<WorkoutProgramCubit>().archiveProgram(program.id);
    }
  }

  /// Real, permanent, cascading delete — every workout day, session,
  /// and logged set under this program goes with it. Requires an
  /// explicit confirmation naming exactly what will be lost;
  /// [_confirmArchive] remains the normal, reversible action.
  Future<void> _confirmDelete(WorkoutProgram program) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.deleteProgramConfirmTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(l10n.deleteProgramConfirmBody(program.name), style: const TextStyle(color: _muted)),
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
      context.read<WorkoutProgramCubit>().deleteProgram(program.id);
    }
  }

  Future<void> _openRenameDialog(WorkoutProgram program) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => RenameProgramDialog(currentName: program.name),
    );
    if (newName != null && mounted) {
      context.read<WorkoutProgramCubit>().renameProgram(programId: program.id, newName: newName);
    }
  }

  void _openProgramDetails(WorkoutProgram program) {
    Navigator.pushNamed(
      context,
      AppNavigator.workoutProgramDetails,
      arguments: WorkoutProgramDetailsArgs(program: program),
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
        title: Text(l10n.myProgramsTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 10,
        icon: const Icon(Icons.add_circle_outline),
        label: Text(l10n.createProgramButton, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: BlocConsumer<WorkoutProgramCubit, WorkoutProgramState>(
        listener: (context, state) {
          if (state is WorkoutProgramLoaded && _box != state.box) {
            setState(() => _box = state.box);
          }
          if (state is WorkoutProgramError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
            );
          }
        },
        builder: (context, state) {
          final box = _box;

          if (box == null) {
            if (state is WorkoutProgramError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.unableToLoadProgramsError,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.read<WorkoutProgramCubit>().loadPrograms(),
                        style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          return ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<WorkoutProgram> liveBox, _) {
              final repository = context.read<WorkoutProgramCubit>().repository;
              final all = repository.getPrograms(liveBox);
              final active = repository.getActiveProgram(liveBox);
              final previous = all.where((p) => !p.isActive).toList();

              if (all.isEmpty) {
                return _EmptyState(onCreate: _openCreateDialog);
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                children: [
                  BlocBuilder<WorkoutSessionCubit, WorkoutSessionState>(
                    builder: (context, sessionState) {
                      if (sessionState is! WorkoutSessionActive) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _ResumeWorkoutBanner(
                          session: sessionState.session,
                          onTap: () => _openActiveSession(sessionState.session),
                        ),
                      );
                    },
                  ),
                  if (active != null) ...[
                    Text(
                      l10n.activeProgramLabel,
                      style: const TextStyle(color: _muted, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    _ProgramCard(
                      program: active,
                      onOpen: () => _openProgramDetails(active),
                      onRename: () => _openRenameDialog(active),
                      onArchive: () => _confirmArchive(active),
                      onMakeActive: null,
                      onDelete: () => _confirmDelete(active),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (previous.isNotEmpty) ...[
                    Text(
                      l10n.previousProgramsLabel,
                      style: const TextStyle(color: _muted, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ...previous.map(
                      (program) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ProgramCard(
                          program: program,
                          onOpen: () => _openProgramDetails(program),
                          onRename: () => _openRenameDialog(program),
                          onArchive: () => _confirmArchive(program),
                          onMakeActive: () => _confirmMakeActive(program),
                          onDelete: () => _confirmDelete(program),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ResumeWorkoutBanner extends StatelessWidget {
  final WorkoutSession session;
  final VoidCallback onTap;

  const _ResumeWorkoutBanner({required this.session, required this.onTap});

  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);

  String _formatElapsed(Duration d, AppLocalizations l10n) {
    if (d.inMinutes < 1) return l10n.durationSecondsOnlyLabel(d.inSeconds);
    if (d.inHours < 1) return l10n.durationMinutesOnlyLabel(d.inMinutes);
    return l10n.durationHoursMinutesLabel(d.inHours, d.inMinutes.remainder(60));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final elapsed = _formatElapsed(DateTime.now().difference(session.startedAt), l10n);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _blue,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: _blue.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 9)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.resumeWorkoutBannerTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.resumeWorkoutBannerBody(session.workoutNameSnapshot, elapsed),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Text(
                l10n.resumeWorkoutButton,
                style: const TextStyle(color: _dark, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final WorkoutProgram program;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onArchive;
  final VoidCallback? onMakeActive;
  final VoidCallback onDelete;

  const _ProgramCard({
    required this.program,
    required this.onOpen,
    required this.onRename,
    required this.onArchive,
    required this.onMakeActive,
    required this.onDelete,
  });

  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateLocale = Localizations.localeOf(context).toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: program.isActive ? Border.all(color: _blue, width: 1.5) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 7)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  program.name,
                  style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              if (program.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xffeaf2fc), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    l10n.activeProgramLabel,
                    style: const TextStyle(color: _blue, fontWeight: FontWeight.w800, fontSize: 10),
                  ),
                ),
            ],
          ),
          if (program.startedAt != null || program.endedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (program.startedAt != null)
                  '${l10n.startedLabel}: ${DateFormat('d MMM yyyy', dateLocale).format(program.startedAt!)}',
                if (program.endedAt != null)
                  '${l10n.endedLabel}: ${DateFormat('d MMM yyyy', dateLocale).format(program.endedAt!)}',
              ].join('  •  '),
              style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(label: l10n.openButton, icon: Icons.arrow_forward, onTap: onOpen),
              _ActionChip(label: l10n.renameButton, icon: Icons.edit_outlined, onTap: onRename),
              if (onMakeActive != null)
                _ActionChip(label: l10n.makeActiveButton, icon: Icons.check_circle_outline, onTap: onMakeActive!),
              _ActionChip(label: l10n.archiveButton, icon: Icons.archive_outlined, onTap: onArchive, isDestructiveTone: true),
              _ActionChip(label: l10n.delete, icon: Icons.delete_forever_outlined, onTap: onDelete, isDestructiveTone: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructiveTone;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructiveTone = false,
  });

  static const Color _blue = Color(0xff2f80ed);

  @override
  Widget build(BuildContext context) {
    final color = isDestructiveTone ? Colors.redAccent : _blue;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 9)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assignment_outlined, color: _blue, size: 40),
              const SizedBox(height: 14),
              Text(
                l10n.noProgramsYetTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.noProgramsYetSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: Text(l10n.createProgramButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
