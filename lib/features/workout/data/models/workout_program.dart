import 'package:hive/hive.dart';

part 'workout_program.g.dart';

/// A long-term training program (e.g. "Push Pull Legs V1").
///
/// Completely separate model from [ExerciseSet] — this phase does not
/// touch ExerciseSet at all. A program owns [WorkoutTemplate]s (added
/// in Phase 2) which in turn own [WorkoutSession]s (Phase 3).
///
/// Only one program is ever active at a time (enforced by
/// `WorkoutProgramRepository.setActiveProgram`, not by this model) —
/// making a new program active deactivates the previous one, it is
/// never deleted.
@HiveType(typeId: 1)
class WorkoutProgram extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime? startedAt;

  @HiveField(5)
  final DateTime? endedAt;

  @HiveField(6)
  final bool isActive;

  WorkoutProgram({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.isActive = false,
  });

  WorkoutProgram copyWith({
    String? name,
    String? description,
    DateTime? startedAt,
    DateTime? endedAt,
    bool? isActive,
  }) {
    return WorkoutProgram(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Cloud sync (Firestore) — same shape as ExerciseSet.toJson/fromJson
  // and BodyMeasurement.toJson/fromJson.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory WorkoutProgram.fromJson(Map<String, dynamic> json) {
    return WorkoutProgram(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null,
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt'] as String) : null,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}
