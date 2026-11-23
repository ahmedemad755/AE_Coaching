// Byte-for-byte copies of the Hive adapters shipped BEFORE activities and
// cloud sync (Stage 2), renamed. They stand in for an older app build in
// the downgrade tests: whatever they read must not crash, and what they
// write is exactly what an older build would write back.
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:hive/hive.dart';

class LegacyWorkoutTemplateAdapter extends TypeAdapter<WorkoutTemplate> {
  @override
  final int typeId = 4;

  @override
  WorkoutTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutTemplate(
      id: fields[0] as String,
      programId: fields[1] as String,
      name: fields[2] as String,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime?,
      isArchived: fields[5] as bool,
      orderIndex: fields[6] as int?,
      exerciseAssignments:
          (fields[7] as List?)?.cast<WorkoutTemplateExerciseAssignment>() ??
          const <WorkoutTemplateExerciseAssignment>[],
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutTemplate obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.programId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.isArchived)
      ..writeByte(6)
      ..write(obj.orderIndex)
      ..writeByte(7)
      ..write(obj.exerciseAssignments);
  }
}

class LegacyAssignmentAdapter
    extends TypeAdapter<WorkoutTemplateExerciseAssignment> {
  @override
  final int typeId = 7;

  @override
  WorkoutTemplateExerciseAssignment read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    return WorkoutTemplateExerciseAssignment(
      assignmentId: fields[0] as String,
      exerciseId: fields[1] as String,
      exerciseNameSnapshot: fields[2] as String,
      referenceType: fields[3] as String,
      workingSets: fields[4] as int?,
      targetRepsMin: fields[5] as int?,
      targetRepsMax: fields[6] as int?,
      restSeconds: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutTemplateExerciseAssignment obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.assignmentId)
      ..writeByte(1)
      ..write(obj.exerciseId)
      ..writeByte(2)
      ..write(obj.exerciseNameSnapshot)
      ..writeByte(3)
      ..write(obj.referenceType)
      ..writeByte(4)
      ..write(obj.workingSets)
      ..writeByte(5)
      ..write(obj.targetRepsMin)
      ..writeByte(6)
      ..write(obj.targetRepsMax)
      ..writeByte(7)
      ..write(obj.restSeconds);
  }
}

class LegacyCustomExerciseAdapter extends TypeAdapter<CustomExercise> {
  @override
  final int typeId = 6;

  @override
  CustomExercise read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    return CustomExercise(
      id: fields[0] as String,
      name: fields[1] as String,
      muscleGroup: fields[2] as String?,
      equipment: fields[3] as String?,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CustomExercise obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.muscleGroup)
      ..writeByte(3)
      ..write(obj.equipment)
      ..writeByte(4)
      ..write(obj.createdAt);
  }
}
