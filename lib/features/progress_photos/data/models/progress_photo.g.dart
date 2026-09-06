// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_photo.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProgressPhotoAdapter extends TypeAdapter<ProgressPhoto> {
  @override
  final int typeId = 3;

  @override
  ProgressPhoto read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProgressPhoto(
      date: fields[0] as DateTime,
      imagePath: fields[1] as String,
      note: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProgressPhoto obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.imagePath)
      ..writeByte(2)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressPhotoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
