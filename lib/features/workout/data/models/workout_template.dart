import 'package:ae_coaching/core/sync/canonical_hash.dart';
import 'package:ae_coaching/core/sync/sync_meta.dart';
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

  /// The day's activities (strength, cardio, timed) in their saved order.
  @HiveField(7)
  final List<WorkoutTemplateExerciseAssignment> exerciseAssignments;

  /// Cloud sync state ([SyncMeta]) kept in the same record as the content,
  /// so one `put` writes both. A plain map: older builds ignore it.
  @HiveField(8)
  final Map<String, dynamic>? syncData;

  WorkoutTemplate({
    required this.id,
    required this.programId,
    required this.name,
    required this.createdAt,
    this.updatedAt,
    this.isArchived = false,
    this.orderIndex,
    List<WorkoutTemplateExerciseAssignment> exerciseAssignments = const [],
    this.syncData,
  }) : exerciseAssignments = List.unmodifiable(exerciseAssignments);

  SyncMeta get syncMeta => SyncMeta.fromMap(syncData);

  WorkoutTemplate withSyncMeta(SyncMeta meta) => WorkoutTemplate(
    id: id,
    programId: programId,
    name: name,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isArchived: isArchived,
    orderIndex: orderIndex,
    exerciseAssignments: exerciseAssignments,
    syncData: meta.toMap(),
  );

  /// What the cloud copy must match: everything the user can change, in
  /// order. Device timestamps are excluded (they are not content).
  Map<String, dynamic> syncContent() => {
    'programId': programId,
    'name': name,
    'isArchived': isArchived,
    'orderIndex': orderIndex,
    'activities': [
      for (final assignment in exerciseAssignments) assignment.toActivityMap(),
    ],
  };

  String get contentFingerprint => contentHash(syncContent());

  /// The document body in the cloud format (schema 2), without the sync
  /// fields (revision, writeId...), which the sync engine adds.
  Map<String, dynamic> toCloudContent() => {
    'id': id,
    'programId': programId,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'isArchived': isArchived,
    'orderIndex': orderIndex,
    'activities': [
      for (final assignment in exerciseAssignments) assignment.toActivityMap(),
    ],
  };

  /// Reads a schema-2 cloud document. [syncData] is set by the caller.
  factory WorkoutTemplate.fromCloudContent(
    Map<String, dynamic> data, {
    Map<String, dynamic>? syncData,
  }) {
    final activities = data['activities'];
    return WorkoutTemplate(
      id: data['id'] as String,
      programId: data['programId'] as String,
      name: data['name'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      updatedAt: data['updatedAt'] is String
          ? DateTime.parse(data['updatedAt'] as String)
          : null,
      isArchived: data['isArchived'] as bool? ?? false,
      orderIndex: (data['orderIndex'] as num?)?.toInt(),
      exerciseAssignments: activities is List
          ? [
              for (final item in activities)
                if (item is Map)
                  WorkoutTemplateExerciseAssignment.fromActivityMap(item),
            ]
          : const [],
      syncData: syncData,
    );
  }

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
      syncData: syncData,
    );
  }

  // The pre-schema-2 (legacy) document shape: still what older app builds
  // write, and what old cloud documents contain. Schema 2 uses
  // [toCloudContent] (with activities) through the sync engine.
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
