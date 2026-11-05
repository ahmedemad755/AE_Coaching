import 'package:ae_coaching/features/workout/data/models/standard_workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/workout_id_generator.dart';

/// Unsaved independent copy; no Hive writes until explicit Save.
class WorkoutProgramDraft {
  final String programId;
  final String ownerUid;
  final String name;
  final List<WorkoutTemplate> days;
  WorkoutProgramDraft({
    required this.programId,
    required this.ownerUid,
    required this.name,
    required List<WorkoutTemplate> days,
  }) : days = List.unmodifiable(days);

  factory WorkoutProgramDraft.fromTemplate({
    required StandardWorkoutSplit split,
    required StandardWorkoutVariant variant,
    required String languageCode,
    required String ownerUid,
  }) {
    final id = WorkoutIdGenerator.generate('program');
    final now = DateTime.now();
    return WorkoutProgramDraft(
      programId: id,
      ownerUid: ownerUid,
      name: '${split.nameForLanguage(languageCode)} — ${variant.days.length}',
      days: [
        for (var i = 0; i < variant.days.length; i++)
          WorkoutTemplate(
            id: WorkoutIdGenerator.generate('template'),
            programId: id,
            orderIndex: i,
            name: variant.days[i].nameForLanguage(languageCode),
            createdAt: now,
            exerciseAssignments: [
              for (final e in variant.days[i].exercises)
                WorkoutTemplateExerciseAssignment(
                  assignmentId: WorkoutIdGenerator.generate('assignment'),
                  exerciseId: e.exercise.id,
                  exerciseNameSnapshot: e.exercise.nameForLanguage(
                    languageCode,
                  ),
                  referenceType: 'builtIn',
                  workingSets: e.workingSets,
                  targetRepsMin: e.repsMin,
                  targetRepsMax: e.repsMax,
                  restSeconds: e.restSeconds,
                ),
            ],
          ),
      ],
    );
  }

  WorkoutProgramDraft copyWith({String? name, List<WorkoutTemplate>? days}) =>
      WorkoutProgramDraft(
        programId: programId,
        ownerUid: ownerUid,
        name: name ?? this.name,
        days: days ?? this.days,
      );
}
