// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_template_exercise_assignment.dart';

class WorkoutTemplateExerciseAssignmentAdapter
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

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutTemplateExerciseAssignmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
