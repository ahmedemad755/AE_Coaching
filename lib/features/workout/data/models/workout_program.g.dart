// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_program.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutProgramAdapter extends TypeAdapter<WorkoutProgram> {
  @override
  final int typeId = 1;

  @override
  WorkoutProgram read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutProgram(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String?,
      createdAt: fields[3] as DateTime,
      startedAt: fields[4] as DateTime?,
      endedAt: fields[5] as DateTime?,
      isActive: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutProgram obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.startedAt)
      ..writeByte(5)
      ..write(obj.endedAt)
      ..writeByte(6)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutProgramAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
