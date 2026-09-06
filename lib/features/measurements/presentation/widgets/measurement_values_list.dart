import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/features/measurements/presentation/widgets/measurement_avatar.dart';
import 'package:ae_coaching/features/measurements/presentation/widgets/measurement_field_defs.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Renders every non-null measurement of a single check-in as
/// "Label   value cm" rows. Shared by the latest-check-in summary and
/// the history list so both stay visually consistent.
class MeasurementValuesList extends StatelessWidget {
  final BodyMeasurement measurement;
  final Color labelColor;
  final Color valueColor;

  const MeasurementValuesList({
    super.key,
    required this.measurement,
    this.labelColor = const Color(0xff7d8792),
    this.valueColor = const Color(0xff202936),
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = measurementFieldDefs
        .where((def) => def.getValue(measurement) != null)
        .toList();

    if (entries.isEmpty) {
      return Text(
        l10n.noMeasurementsRecordedCheckIn,
        style: const TextStyle(color: Color(0xff7d8792)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map(
            (def) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  MeasurementAvatar(imagePath: def.imagePath, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      def.localizedLabel(l10n),
                      style: TextStyle(
                        color: labelColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${def.getValue(measurement)!.toStringAsFixed(1)} ${l10n.cmUnit}',
                    style: TextStyle(
                      color: valueColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
