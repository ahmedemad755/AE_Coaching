import 'package:hive/hive.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';

part 'workout_template.g.dart';

/// A reusable workout day definition (e.g. "Push 1", "Pull 1", "Legs")
/// belonging to exactly one [WorkoutProgram] via [programId].
///
/// Created once, reused every week — a new WorkoutSession (Phase 3)
/// references this same template each time the user trains that day,
/// it is never recreated. [programId] is set at creation and never
/// changes afterward (see `WorkoutTemplateRepository.updateTemplate`,
/// whose signature does not even accept a programId) — moving a
/// workout day to a different program means creating a new template
/// there, not silently repointing this one.
@HiveType(typeId: 4)
class WorkoutTemplate extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String programId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime? updatedAt;

  @HiveField(5)
  final bool isArchived;

  /// Optional stable ordering for workout-day cards within a program
  /// (Phase 6). Null means "no explicit order yet".
  @HiveField(6)
  final int? orderIndex;

  @HiveField(7)
  final List<WorkoutTemplateExerciseAssignment> exerciseAssignments;

  WorkoutTemplate({
    required this.id,
    required this.programId,
    required this.name,
    required this.createdAt,
    this.updatedAt,
    this.isArchived = false,
    this.orderIndex,
    List<WorkoutTemplateExerciseAssignment> exerciseAssignments = const [],
  }) : exerciseAssignments = List.unmodifiable(exerciseAssignments);

  /// Intentionally has no way to change [programId] or [id] — every
  /// field that must never drift after creation is hard-copied from
  /// `this`, not taken as a parameter.
  WorkoutTemplate copyWith({
    String? name,
    DateTime? updatedAt,
    bool? isArchived,
    int? orderIndex,
    List<WorkoutTemplateExerciseAssignment>? exerciseAssignments,
  }) {
    return WorkoutTemplate(
      id: id,
      programId: programId,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      orderIndex: orderIndex ?? this.orderIndex,
      exerciseAssignments: exerciseAssignments ?? this.exerciseAssignments,
    );
  }

  // Cloud sync (Firestore) — same shape as the other models in this
  // app. programId is always included so Firestore documents carry
  // their program ownership too. Exercise assignments stay local in
  // this stage and are intentionally excluded from the cloud payload.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'programId': programId,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isArchived': isArchived,
      'orderIndex': orderIndex,
    };
  }

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) {
    return WorkoutTemplate(
      id: json['id'] as String,
      programId: json['programId'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isArchived: json['isArchived'] as bool? ?? false,
      orderIndex: json['orderIndex'] as int?,
      exerciseAssignments:
          (json['exerciseAssignments'] as List<dynamic>?)
              ?.map(
                (item) => WorkoutTemplateExerciseAssignment.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList() ??
          const [],
    );
  }
}
