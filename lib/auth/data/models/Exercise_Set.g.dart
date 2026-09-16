// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Exercise_Set.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExerciseSetAdapter extends TypeAdapter<ExerciseSet> {
  @override
  final int typeId = 0;

  @override
  ExerciseSet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExerciseSet(
      exerciseName: fields[0] as String,
      weight: fields[1] as double,
      reps: fields[2] as int,
      date: fields[3] as DateTime,
      notes: fields[4] as String?,
      programId: fields[5] as String?,
      workoutTemplateId: fields[6] as String?,
      workoutSessionId: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseSet obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.exerciseName)
      ..writeByte(1)
      ..write(obj.weight)
      ..writeByte(2)
      ..write(obj.reps)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.programId)
      ..writeByte(6)
      ..write(obj.workoutTemplateId)
      ..writeByte(7)
      ..write(obj.workoutSessionId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseSetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
