// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'body_measurement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BodyMeasurementAdapter extends TypeAdapter<BodyMeasurement> {
  @override
  final int typeId = 2;

  @override
  BodyMeasurement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BodyMeasurement(
      date: fields[0] as DateTime,
      chest: fields[1] as double?,
      waist: fields[2] as double?,
      hips: fields[3] as double?,
      rightArm: fields[4] as double?,
      leftArm: fields[5] as double?,
      rightThigh: fields[6] as double?,
      leftThigh: fields[7] as double?,
      rightCalf: fields[8] as double?,
      leftCalf: fields[9] as double?,
      shoulders: fields[10] as double?,
      neck: fields[11] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, BodyMeasurement obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.chest)
      ..writeByte(2)
      ..write(obj.waist)
      ..writeByte(3)
      ..write(obj.hips)
      ..writeByte(4)
      ..write(obj.rightArm)
      ..writeByte(5)
      ..write(obj.leftArm)
      ..writeByte(6)
      ..write(obj.rightThigh)
      ..writeByte(7)
      ..write(obj.leftThigh)
      ..writeByte(8)
      ..write(obj.rightCalf)
      ..writeByte(9)
      ..write(obj.leftCalf)
      ..writeByte(10)
      ..write(obj.shoulders)
      ..writeByte(11)
      ..write(obj.neck);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BodyMeasurementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
