import 'package:hive/hive.dart';

part 'progress_photo.g.dart';

/// A single progress-photo check-in.
///
/// Pairing into Before/After is deliberately not stored here — it is
/// always derived at read time by sorting on [date], mirroring how
/// BodyMeasurement comparisons work. This keeps a photo useful even if
/// it was never tied to a measurement check-in.
@HiveType(typeId: 3)
class ProgressPhoto extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final String imagePath;

  @HiveField(2)
  final String? note;

  ProgressPhoto({
    required this.date,
    required this.imagePath,
    this.note,
  });
}
