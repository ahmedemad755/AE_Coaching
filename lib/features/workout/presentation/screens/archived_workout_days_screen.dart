import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_template_cubit.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Route arguments for [ArchivedWorkoutDaysScreen].
class ArchivedWorkoutDaysArgs {
  final WorkoutProgram program;
  const ArchivedWorkoutDaysArgs({required this.program});
}

/// Every archived workout day for one program — the place an archived
/// day actually lives, so archiving it is no longer a one-way trip
/// that only shows back up by digging through workout history. Each
/// entry offers Restore (back to the normal active list, via
/// [WorkoutTemplateCubit.restoreTemplate]) or a real, permanent,
/// cascading Delete.
class ArchivedWorkoutDaysScreen extends StatefulWidget {
  final WorkoutProgram program;

  const ArchivedWorkoutDaysScreen({super.key, required this.program});

  @override
  State<ArchivedWorkoutDaysScreen> createState() => _ArchivedWorkoutDaysScreenState();
}

class _ArchivedWorkoutDaysScreenState extends State<ArchivedWorkoutDaysScreen> {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  Box<WorkoutTemplate>? _box;

  @override
  void initState() {
    super.initState();
    context.read<WorkoutTemplateCubit>().loadTemplates();
  }

  Future<void> _confirmDelete(WorkoutTemplate template) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(l10n.deleteWorkoutDayConfirmTitle, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(l10n.deleteWorkoutDayConfirmBody(template.name), style: const TextStyle(color: _muted)),
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
      context.read<WorkoutTemplateCubit>().deleteTemplate(template.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xfff5f9fc),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Text(l10n.archivedWorkoutDaysTitle),
      ),
      body: BlocConsumer<WorkoutTemplateCubit, WorkoutTemplateState>(
        listener: (context, state) {
          if (state is WorkoutTemplateLoaded && _box != state.box) {
            setState(() => _box = state.box);
          }
          if (state is WorkoutTemplateError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
            );
          }
        },
        builder: (context, state) {
          final box = _box;
          if (box == null) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          return ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<WorkoutTemplate> liveBox, _) {
              final repository = context.read<WorkoutTemplateCubit>().repository;
              final allForProgram = repository.getTemplatesForProgram(
                liveBox,
                widget.program.id,
                includeArchived: true,
              );
              final archived = allForProgram.where((t) => t.isArchived).toList();

              if (archived.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.noArchivedWorkoutDaysBody,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: archived.length,
                itemBuilder: (context, index) {
                  final template = archived[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              template.name,
                              style: const TextStyle(color: _dark, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.read<WorkoutTemplateCubit>().restoreTemplate(template.id),
                            child: Text(l10n.restoreButton),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                            tooltip: l10n.delete,
                            onPressed: () => _confirmDelete(template),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
