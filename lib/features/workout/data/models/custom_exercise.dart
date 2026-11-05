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

  CustomExercise({
    required this.id,
    required this.name,
    this.muscleGroup,
    this.equipment,
    required this.createdAt,
  });

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
