import 'package:hive/hive.dart';

part 'body_measurement.g.dart';

@HiveType(typeId: 2)
class BodyMeasurement extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final double? chest;

  @HiveField(2)
  final double? waist;

  @HiveField(3)
  final double? hips;

  @HiveField(4)
  final double? rightArm;

  @HiveField(5)
  final double? leftArm;

  @HiveField(6)
  final double? rightThigh;

  @HiveField(7)
  final double? leftThigh;

  @HiveField(8)
  final double? rightCalf;

  @HiveField(9)
  final double? leftCalf;

  @HiveField(10)
  final double? shoulders;

  @HiveField(11)
  final double? neck;

  BodyMeasurement({
    required this.date,
    this.chest,
    this.waist,
    this.hips,
    this.rightArm,
    this.leftArm,
    this.rightThigh,
    this.leftThigh,
    this.rightCalf,
    this.leftCalf,
    this.shoulders,
    this.neck,
  });

  BodyMeasurement copyWith({
    DateTime? date,
    double? chest,
    double? waist,
    double? hips,
    double? rightArm,
    double? leftArm,
    double? rightThigh,
    double? leftThigh,
    double? rightCalf,
    double? leftCalf,
    double? shoulders,
    double? neck,
  }) {
    return BodyMeasurement(
      date: date ?? this.date,
      chest: chest ?? this.chest,
      waist: waist ?? this.waist,
      hips: hips ?? this.hips,
      rightArm: rightArm ?? this.rightArm,
      leftArm: leftArm ?? this.leftArm,
      rightThigh: rightThigh ?? this.rightThigh,
      leftThigh: leftThigh ?? this.leftThigh,
      rightCalf: rightCalf ?? this.rightCalf,
      leftCalf: leftCalf ?? this.leftCalf,
      shoulders: shoulders ?? this.shoulders,
      neck: neck ?? this.neck,
    );
  }

  Map<String, double?> toMap() {
    return {
      'Chest': chest,
      'Waist': waist,
      'Hips': hips,
      'Right Arm': rightArm,
      'Left Arm': leftArm,
      'Right Thigh': rightThigh,
      'Left Thigh': leftThigh,
      'Right Calf': rightCalf,
      'Left Calf': leftCalf,
      'Shoulders': shoulders,
      'Neck': neck,
    };
  }

  // Cloud sync (Firestore) — mirrors ExerciseSet.toJson/fromJson so
  // BodyMeasurement check-ins can survive logout/uninstall the same way
  // workout sets already do.
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'chest': chest,
      'waist': waist,
      'hips': hips,
      'rightArm': rightArm,
      'leftArm': leftArm,
      'rightThigh': rightThigh,
      'leftThigh': leftThigh,
      'rightCalf': rightCalf,
      'leftCalf': leftCalf,
      'shoulders': shoulders,
      'neck': neck,
    };
  }

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic value) =>
        value == null ? null : (value as num).toDouble();

    return BodyMeasurement(
      date: DateTime.parse(json['date'] as String),
      chest: asDouble(json['chest']),
      waist: asDouble(json['waist']),
      hips: asDouble(json['hips']),
      rightArm: asDouble(json['rightArm']),
      leftArm: asDouble(json['leftArm']),
      rightThigh: asDouble(json['rightThigh']),
      leftThigh: asDouble(json['leftThigh']),
      rightCalf: asDouble(json['rightCalf']),
      leftCalf: asDouble(json['leftCalf']),
      shoulders: asDouble(json['shoulders']),
      neck: asDouble(json['neck']),
    );
  }
}