// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutTemplateAdapter extends TypeAdapter<WorkoutTemplate> {
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
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutTemplate obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.orderIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
