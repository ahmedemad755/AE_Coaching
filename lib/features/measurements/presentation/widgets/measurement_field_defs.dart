import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';

/// Static description of one measurable body part.
///
/// Centralizing this list keeps the Add/Edit form, the latest
/// check-in summary, the history list and the analytics screen all
/// reading the same fields/order instead of duplicating literals.
class MeasurementFieldDef {
  final String key;
  final String label;
  final String imagePath;
  final double? Function(BodyMeasurement measurement) getValue;

  const MeasurementFieldDef({
    required this.key,
    required this.label,
    required this.imagePath,
    required this.getValue,
  });

  /// Locale-aware display label (Arabic/English). [label] itself stays a
  /// fixed English fallback/identifier — nothing persists it, so it is
  /// safe to keep unlocalized internally.
  String localizedLabel(AppLocalizations l10n) {
    switch (key) {
      case 'chest':
        return l10n.fieldChest;
      case 'waist':
        return l10n.fieldWaist;
      case 'hips':
        return l10n.fieldHips;
      case 'shoulders':
        return l10n.fieldShoulders;
      case 'neck':
        return l10n.fieldNeck;
      case 'rightArm':
        return l10n.fieldRightArm;
      case 'leftArm':
        return l10n.fieldLeftArm;
      case 'rightThigh':
        return l10n.fieldRightThigh;
      case 'leftThigh':
        return l10n.fieldLeftThigh;
      case 'rightCalf':
        return l10n.fieldRightCalf;
      case 'leftCalf':
        return l10n.fieldLeftCalf;
      default:
        return label;
    }
  }
}

// Muscle/body-part illustrations already shipped in lib/assets — declared
// as a Flutter asset folder in pubspec.yaml (`assets: - lib/assets/`).
const String _chestImage = 'lib/assets/chest.png';
const String _waistImage = 'lib/assets/wist.png';
const String _hipImage = 'lib/assets/hip.png';
const String _shoulderImage = 'lib/assets/shoulder.png';
const String _neckImage = 'lib/assets/neck.png';
const String _armsImage = 'lib/assets/arms.png';
const String _legImage = 'lib/assets/leg.png';
const String _calfsImage = 'lib/assets/calfs.png';

final List<MeasurementFieldDef> measurementFieldDefs = [
  MeasurementFieldDef(
      key: 'chest', label: 'Chest', imagePath: _chestImage, getValue: (m) => m.chest),
  MeasurementFieldDef(
      key: 'waist', label: 'Waist', imagePath: _waistImage, getValue: (m) => m.waist),
  MeasurementFieldDef(
      key: 'hips', label: 'Hips', imagePath: _hipImage, getValue: (m) => m.hips),
  MeasurementFieldDef(
      key: 'shoulders',
      label: 'Shoulders',
      imagePath: _shoulderImage,
      getValue: (m) => m.shoulders),
  MeasurementFieldDef(
      key: 'neck', label: 'Neck', imagePath: _neckImage, getValue: (m) => m.neck),
  MeasurementFieldDef(
      key: 'rightArm',
      label: 'Right Arm',
      imagePath: _armsImage,
      getValue: (m) => m.rightArm),
  MeasurementFieldDef(
      key: 'leftArm',
      label: 'Left Arm',
      imagePath: _armsImage,
      getValue: (m) => m.leftArm),
  MeasurementFieldDef(
      key: 'rightThigh',
      label: 'Right Thigh',
      imagePath: _legImage,
      getValue: (m) => m.rightThigh),
  MeasurementFieldDef(
      key: 'leftThigh',
      label: 'Left Thigh',
      imagePath: _legImage,
      getValue: (m) => m.leftThigh),
  MeasurementFieldDef(
      key: 'rightCalf',
      label: 'Right Calf',
      imagePath: _calfsImage,
      getValue: (m) => m.rightCalf),
  MeasurementFieldDef(
      key: 'leftCalf',
      label: 'Left Calf',
      imagePath: _calfsImage,
      getValue: (m) => m.leftCalf),
];
