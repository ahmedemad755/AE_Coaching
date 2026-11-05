import 'package:hive/hive.dart';

part 'workout_template_exercise_assignment.g.dart';

enum WorkoutExerciseReferenceType { builtIn, custom, manual }

@HiveType(typeId: 7)
class WorkoutTemplateExerciseAssignment extends HiveObject {
  @HiveField(0)
  final String assignmentId;

  @HiveField(1)
  final String exerciseId;

  @HiveField(2)
  final String exerciseNameSnapshot;

  @HiveField(3)
  final String referenceType;

  // Optional planning targets. Existing four-field records remain valid;
  // these are not logged sets and do not contribute to analytics.
  @HiveField(4)
  final int? workingSets;
  @HiveField(5)
  final int? targetRepsMin;
  @HiveField(6)
  final int? targetRepsMax;
  @HiveField(7)
  final int? restSeconds;

  WorkoutTemplateExerciseAssignment({
    required this.assignmentId,
    required this.exerciseId,
    required this.exerciseNameSnapshot,
    required this.referenceType,
    this.workingSets,
    this.targetRepsMin,
    this.targetRepsMax,
    this.restSeconds,
  });

  bool get hasTargets =>
      workingSets != null &&
      targetRepsMin != null &&
      targetRepsMax != null &&
      restSeconds != null;

  void validateTargets() {
    final values = [workingSets, targetRepsMin, targetRepsMax, restSeconds];
    if (values.every((value) => value == null)) return;
    if (!hasTargets ||
        workingSets! < 1 ||
        workingSets! > 10 ||
        targetRepsMin! < 1 ||
        targetRepsMax! > 100 ||
        targetRepsMax! < targetRepsMin! ||
        restSeconds! < 15 ||
        restSeconds! > 600) {
      throw ArgumentError('Invalid working sets, rep range or rest target.');
    }
  }

  WorkoutTemplateExerciseAssignment copyWith({
    String? exerciseId,
    String? exerciseNameSnapshot,
    String? referenceType,
    int? workingSets,
    int? targetRepsMin,
    int? targetRepsMax,
    int? restSeconds,
  }) => WorkoutTemplateExerciseAssignment(
    assignmentId: assignmentId,
    exerciseId: exerciseId ?? this.exerciseId,
    exerciseNameSnapshot: exerciseNameSnapshot ?? this.exerciseNameSnapshot,
    referenceType: referenceType ?? this.referenceType,
    workingSets: workingSets ?? this.workingSets,
    targetRepsMin: targetRepsMin ?? this.targetRepsMin,
    targetRepsMax: targetRepsMax ?? this.targetRepsMax,
    restSeconds: restSeconds ?? this.restSeconds,
  );

  WorkoutExerciseReferenceType get referenceTypeValue =>
      WorkoutExerciseReferenceType.values.firstWhere(
        (type) => type.name == referenceType,
        orElse: () => WorkoutExerciseReferenceType.manual,
      );

  Map<String, dynamic> toJson() => {
    'assignmentId': assignmentId,
    'exerciseId': exerciseId,
    'exerciseNameSnapshot': exerciseNameSnapshot,
    'referenceType': referenceType,
    if (workingSets != null) 'workingSets': workingSets,
    if (targetRepsMin != null) 'targetRepsMin': targetRepsMin,
    if (targetRepsMax != null) 'targetRepsMax': targetRepsMax,
    if (restSeconds != null) 'restSeconds': restSeconds,
  };

  factory WorkoutTemplateExerciseAssignment.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkoutTemplateExerciseAssignment(
      assignmentId: json['assignmentId'] as String,
      exerciseId: json['exerciseId'] as String,
      exerciseNameSnapshot: json['exerciseNameSnapshot'] as String,
      referenceType: json['referenceType'] as String,
      workingSets: json['workingSets'] as int?,
      targetRepsMin: json['targetRepsMin'] as int?,
      targetRepsMax: json['targetRepsMax'] as int?,
      restSeconds: json['restSeconds'] as int?,
    );
  }
}
