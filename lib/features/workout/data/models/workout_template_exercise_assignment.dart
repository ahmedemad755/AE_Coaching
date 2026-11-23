import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:ae_coaching/features/workout/domain/activity_plans.dart';
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

  // ── Activities (schema 2). All optional: records written before them
  // read as strength. Plans are plain maps, not Hive types, so an older
  // app build reading these records ignores them instead of crashing.

  /// `strength` / `cardio` / `timed`; null means strength.
  @HiveField(8)
  final String? activityType;

  @HiveField(9)
  final int? schemaVersion;

  /// [CardioPlan] as a map (cardio activities only).
  @HiveField(10)
  final Map<String, dynamic>? cardioData;

  /// [TimedPlan] as a map (timed activities only).
  @HiveField(11)
  final Map<String, dynamic>? timedData;

  WorkoutTemplateExerciseAssignment({
    required this.assignmentId,
    required this.exerciseId,
    required this.exerciseNameSnapshot,
    required this.referenceType,
    this.workingSets,
    this.targetRepsMin,
    this.targetRepsMax,
    this.restSeconds,
    this.activityType,
    this.schemaVersion,
    this.cardioData,
    this.timedData,
  });

  static const int currentSchemaVersion = 2;

  ActivityType get type => ActivityType.parse(activityType);
  CardioPlan? get cardio => CardioPlan.fromMap(cardioData);
  TimedPlan? get timed => TimedPlan.fromMap(timedData);

  /// The same entry turned into another kind of activity: plans that do not
  /// belong to [type] are cleared (copyWith cannot clear fields).
  WorkoutTemplateExerciseAssignment withActivity({
    required ActivityType type,
    CardioPlan? cardio,
    TimedPlan? timed,
  }) => WorkoutTemplateExerciseAssignment(
    assignmentId: assignmentId,
    exerciseId: exerciseId,
    exerciseNameSnapshot: exerciseNameSnapshot,
    referenceType: referenceType,
    workingSets: type == ActivityType.strength ? workingSets : null,
    targetRepsMin: type == ActivityType.strength ? targetRepsMin : null,
    targetRepsMax: type == ActivityType.strength ? targetRepsMax : null,
    restSeconds: type == ActivityType.strength ? restSeconds : null,
    activityType: type == ActivityType.strength ? null : type.name,
    schemaVersion: currentSchemaVersion,
    cardioData: type == ActivityType.cardio ? cardio?.toMap() : null,
    timedData: type == ActivityType.timed ? timed?.toMap() : null,
  );

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
    activityType: activityType,
    schemaVersion: schemaVersion,
    cardioData: cardioData,
    timedData: timedData,
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

  /// The activity in the cloud / snapshot format (schema 2):
  /// `{id, type, exerciseId, referenceType, name, strength?, cardio?, timed?}`.
  /// Only set values are written; [ActivityType.strength] keeps its targets
  /// under `strength`.
  Map<String, dynamic> toActivityMap() {
    final strength = <String, dynamic>{
      if (workingSets != null) 'sets': workingSets,
      if (targetRepsMin != null) 'repsMin': targetRepsMin,
      if (targetRepsMax != null) 'repsMax': targetRepsMax,
      if (restSeconds != null) 'restSeconds': restSeconds,
    };
    return {
      'id': assignmentId,
      'type': type.name,
      'exerciseId': exerciseId,
      'referenceType': referenceType,
      'name': exerciseNameSnapshot,
      if (strength.isNotEmpty) 'strength': strength,
      if (cardioData != null) 'cardio': deepStringKeys(cardioData),
      if (timedData != null) 'timed': deepStringKeys(timedData),
    };
  }

  /// Reads [toActivityMap]'s format (from Firestore or a snapshot).
  factory WorkoutTemplateExerciseAssignment.fromActivityMap(
    Map<dynamic, dynamic> map,
  ) {
    final type = ActivityType.parse(map['type']);
    final strength = map['strength'];
    final cardio = map['cardio'];
    final timed = map['timed'];
    int? target(String key) =>
        strength is Map ? (strength[key] as num?)?.toInt() : null;
    return WorkoutTemplateExerciseAssignment(
      assignmentId: map['id'] as String,
      exerciseId: map['exerciseId'] as String,
      exerciseNameSnapshot: map['name'] as String,
      referenceType: map['referenceType'] as String,
      workingSets: target('sets'),
      targetRepsMin: target('repsMin'),
      targetRepsMax: target('repsMax'),
      restSeconds: target('restSeconds'),
      activityType: type == ActivityType.strength ? null : type.name,
      schemaVersion: currentSchemaVersion,
      cardioData: cardio is Map
          ? deepStringKeys(cardio) as Map<String, dynamic>
          : null,
      timedData: timed is Map
          ? deepStringKeys(timed) as Map<String, dynamic>
          : null,
    );
  }
}
