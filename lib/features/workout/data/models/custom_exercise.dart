import 'package:ae_coaching/core/sync/canonical_hash.dart';
import 'package:ae_coaching/core/sync/sync_meta.dart';
import 'package:hive/hive.dart';

part 'custom_exercise.g.dart';

@HiveType(typeId: 6)
class CustomExercise extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? muscleGroup;

  @HiveField(3)
  final String? equipment;

  @HiveField(4)
  final DateTime createdAt;

  /// `strength` / `cardio` / `timed`; null means strength (all custom
  /// exercises created before activities).
  @HiveField(5)
  final String? activityType;

  /// Cloud sync state ([SyncMeta]), in the same record (see WorkoutTemplate).
  @HiveField(6)
  final Map<String, dynamic>? syncData;

  CustomExercise({
    required this.id,
    required this.name,
    this.muscleGroup,
    this.equipment,
    required this.createdAt,
    this.activityType,
    this.syncData,
  });

  SyncMeta get syncMeta => SyncMeta.fromMap(syncData);

  CustomExercise withSyncMeta(SyncMeta meta) => CustomExercise(
    id: id,
    name: name,
    muscleGroup: muscleGroup,
    equipment: equipment,
    createdAt: createdAt,
    activityType: activityType,
    syncData: meta.toMap(),
  );

  Map<String, dynamic> syncContent() => {
    'name': name,
    'muscleGroup': muscleGroup,
    'equipment': equipment,
    'activityType': activityType ?? 'strength',
  };

  String get contentFingerprint => contentHash(syncContent());

  /// Cloud document body (schema 2), without the sync fields.
  Map<String, dynamic> toCloudContent() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'equipment': equipment,
    'activityType': activityType ?? 'strength',
    'createdAt': createdAt.toIso8601String(),
  };

  factory CustomExercise.fromCloudContent(
    Map<String, dynamic> data, {
    Map<String, dynamic>? syncData,
  }) {
    final type = data['activityType'];
    return CustomExercise(
      id: data['id'] as String,
      name: data['name'] as String,
      muscleGroup: data['muscleGroup'] as String?,
      equipment: data['equipment'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
      activityType: type == 'strength' ? null : type as String?,
      syncData: syncData,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'equipment': equipment,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CustomExercise.fromJson(Map<String, dynamic> json) {
    return CustomExercise(
      id: json['id'] as String,
      name: json['name'] as String,
      muscleGroup: json['muscleGroup'] as String?,
      equipment: json['equipment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
