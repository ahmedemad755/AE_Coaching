import 'package:hive/hive.dart';

// هذا الملف سيتم إنتاجه بواسطة hive_generator
part 'Exercise_Set.g.dart'; 

@HiveType(typeId: 0) // الـ typeId الخاص بالـ Model
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

  /// Which WorkoutProgram this set was logged under, if any.
  ///
  /// Null for every set logged before this phase (legacy) and for any
  /// set logged outside an active WorkoutSession — that is a valid,
  /// permanent state, not a placeholder to be filled in later. See
  /// [hasConsistentSessionLinkage].
  @HiveField(5)
  final String? programId;

  @HiveField(6)
  final String? workoutTemplateId;

  @HiveField(7)
  final String? workoutSessionId;

  ExerciseSet({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.date,
    this.notes,
    this.programId,
    this.workoutTemplateId,
    this.workoutSessionId,
  });

  /// True when the three session-linkage fields are in one of the two
  /// valid shapes: all null (legacy / not tied to a session) or all
  /// non-null (fully linked to a session). False for any partial
  /// combination (e.g. `workoutSessionId` set but `workoutTemplateId`
  /// null) — a state this model is never meant to be saved in.
  ///
  /// Purely informational for now: nothing in this phase enforces or
  /// rejects it automatically — this exists so a future save path (or
  /// a test) can check it explicitly.
  bool get hasConsistentSessionLinkage {
    final linkedCount = [programId, workoutTemplateId, workoutSessionId].where((v) => v != null).length;
    return linkedCount == 0 || linkedCount == 3;
  }

  // دالة لتحويل البيانات من/إلى JSON للحفظ والمزامنة مع Firebase Firestore
  Map<String, dynamic> toJson() {
    return {
      'exerciseName': exerciseName,
      'weight': weight,
      'reps': reps,
      'date': date.toIso8601String(),
      'notes': notes,
      'programId': programId,
      'workoutTemplateId': workoutTemplateId,
      'workoutSessionId': workoutSessionId,
    };
  }

  factory ExerciseSet.fromJson(Map<String, dynamic> json) {
    return ExerciseSet(
      exerciseName: json['exerciseName'] as String,
      weight: (json['weight'] as num).toDouble(),
      reps: json['reps'] as int,
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
      // Absent in any legacy Firestore document written before this
      // phase — Map access on a missing key returns null already, and
      // casting null to a nullable type is always safe, so no extra
      // null-guarding is needed here.
      programId: json['programId'] as String?,
      workoutTemplateId: json['workoutTemplateId'] as String?,
      workoutSessionId: json['workoutSessionId'] as String?,
    );
  }
}