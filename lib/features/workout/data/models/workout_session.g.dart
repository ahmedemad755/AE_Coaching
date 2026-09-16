// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkoutSessionAdapter extends TypeAdapter<WorkoutSession> {
  @override
  final int typeId = 5;

  @override
  WorkoutSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutSession(
      id: fields[0] as String,
      programId: fields[1] as String,
      workoutTemplateId: fields[2] as String,
      workoutNameSnapshot: fields[3] as String,
      date: fields[4] as DateTime,
      startedAt: fields[5] as DateTime,
      completedAt: fields[6] as DateTime?,
      status: fields[7] as String,
      totalVolume: fields[8] as double,
      previousSessionId: fields[9] as String?,
      workoutNote: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSession obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.programId)
      ..writeByte(2)
      ..write(obj.workoutTemplateId)
      ..writeByte(3)
      ..write(obj.workoutNameSnapshot)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.startedAt)
      ..writeByte(6)
      ..write(obj.completedAt)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.totalVolume)
      ..writeByte(9)
      ..write(obj.previousSessionId)
      ..writeByte(10)
      ..write(obj.workoutNote);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
