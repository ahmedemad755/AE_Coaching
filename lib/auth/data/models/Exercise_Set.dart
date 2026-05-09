import 'package:hive/hive.dart';

// هذا الملف سيتم إنتاجه بواسطة hive_generator
part 'Exercise_Set.g.dart'; 

@HiveType(typeId: 0) // الـ typeId اللي سجلناه في الـ main
class ExerciseSet extends HiveObject {
  @HiveField(0)
  final String exerciseName;

  @HiveField(1)
  final double weight;

  @HiveField(2)
  final int reps;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String? notes;

  ExerciseSet({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.date,
    this.notes,
  });

  // اختيارياً: دالة لتحويل البيانات من/إلى JSON إذا كنت ستحفظها في Firebase لاحقاً
  Map<String, dynamic> toJson() {
    return {
      'exerciseName': exerciseName,
      'weight': weight,
      'reps': reps,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      exerciseName: json['exerciseName'],
      weight: (json['weight'] as num).toDouble(),
      reps: json['reps'],
      date: DateTime.parse(json['date']),
      notes: json['notes'],
    );
  }
}