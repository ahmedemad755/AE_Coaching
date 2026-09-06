import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/features/measurements/presentation/cubit/measurement_cubit.dart';
import 'package:ae_coaching/features/measurements/presentation/widgets/measurement_avatar.dart';
import 'package:ae_coaching/features/measurements/presentation/widgets/measurement_field_defs.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Body Measurements analytics.
///
/// Kept fully separate from Workout Volume analytics. For each body
/// part this screen independently gathers its own non-null history
/// (a value missing from one check-in never breaks the comparison for
/// another field) and shows the change objectively — as +/- cm and
/// +/- percentage — without labeling it "improved" or "worse", since
/// that judgment depends on the body part (see feature spec).
class MeasurementAnalyticsScreen extends StatefulWidget {
  const MeasurementAnalyticsScreen({super.key});

  @override
  State<MeasurementAnalyticsScreen> createState() => _MeasurementAnalyticsScreenState();
}

class _MeasurementAnalyticsScreenState extends State<MeasurementAnalyticsScreen> {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _muted = Color(0xff7d8792);

  // Retains the last successfully loaded box so a transient state (the
  // background Firestore sync) never flashes a spinner/error over
  // analytics that are already on screen.
  Box<BodyMeasurement>? _box;

  @override
  void initState() {
    super.initState();
    final state = context.read<MeasurementCubit>().state;
    if (state is MeasurementSuccess) {
      _box = state.box;
    }
  }

  /// Builds the ascending-by-date, non-null value series for [def]
  /// across every stored check-in.
  List<MapEntry<DateTime, double>> _seriesFor(
    MeasurementFieldDef def,
    List<BodyMeasurement> sortedAscending,
  ) {
    final points = <MapEntry<DateTime, double>>[];
    for (final m in sortedAscending) {
      final value = def.getValue(m);
      if (value != null) {
        points.add(MapEntry(m.date, value));
      }
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xfff5f9fc),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Text(l10n.measurementAnalyticsTitle),
      ),
      body: BlocConsumer<MeasurementCubit, MeasurementState>(
        listener: (context, state) {
          if (state is MeasurementSuccess && _box != state.box) {
            setState(() => _box = state.box);
          }
        },
        builder: (context, state) {
          final box = _box;

          if (box == null) {
            if (state is MeasurementError) {
              return Center(
                child: Text(
                  l10n.unableToLoadAnalytics,
                  style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          return ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<BodyMeasurement> liveBox, _) {
              final sortedAscending = liveBox.values.toList()
                ..sort((a, b) => a.date.compareTo(b.date));

              if (sortedAscending.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.noMeasurementsHistoryEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                itemCount: measurementFieldDefs.length,
                itemBuilder: (context, index) {
                  final def = measurementFieldDefs[index];
                  final points = _seriesFor(def, sortedAscending);
                  return _FieldAnalyticsCard(l10n: l10n, def: def, points: points);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FieldAnalyticsCard extends StatelessWidget {
  final AppLocalizations l10n;
  final MeasurementFieldDef def;
  final List<MapEntry<DateTime, double>> points;

  const _FieldAnalyticsCard({required this.l10n, required this.def, required this.points});

  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MeasurementAvatar(imagePath: def.imagePath, size: 30),
              const SizedBox(width: 10),
              Text(
                def.localizedLabel(l10n),
                style: const TextStyle(
                  color: _dark,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (points.length < 2)
            Text(
              l10n.notEnoughDataYet,
              style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
            )
          else
            ..._buildComparisons(),
        ],
      ),
    );
  }

  List<Widget> _buildComparisons() {
    final previous = points[points.length - 2].value;
    final current = points.last.value;
    final sinceDiff = current - previous;
    final sincePct = previous != 0 ? (sinceDiff / previous) * 100 : 0.0;

    final first = points.first.value;
    final latest = points.last.value;
    final totalDiff = latest - first;
    final totalPct = first != 0 ? (totalDiff / first) * 100 : 0.0;

    return [
      _ComparisonBlock(
        l10n: l10n,
        title: l10n.sincePreviousCheckIn,
        firstLabel: l10n.previousLabel,
        secondLabel: l10n.currentLabel,
        firstValue: previous,
        secondValue: current,
        diff: sinceDiff,
        pct: sincePct,
      ),
      const Divider(height: 24),
      _ComparisonBlock(
        l10n: l10n,
        title: l10n.overallProgress,
        firstLabel: l10n.firstLabel,
        secondLabel: l10n.latestLabel,
        firstValue: first,
        secondValue: latest,
        diff: totalDiff,
        pct: totalPct,
      ),
    ];
  }
}

class _ComparisonBlock extends StatelessWidget {
  final AppLocalizations l10n;
  final String title;
  final String firstLabel;
  final String secondLabel;
  final double firstValue;
  final double secondValue;
  final double diff;
  final double pct;

  const _ComparisonBlock({
    required this.l10n,
    required this.title,
    required this.firstLabel,
    required this.secondLabel,
    required this.firstValue,
    required this.secondValue,
    required this.diff,
    required this.pct,
  });

  static const Color _blue = Color(0xff2f80ed);
  static const Color _muted = Color(0xff7d8792);

  String _signed(double v, String suffix) {
    final sign = v > 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(1)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final IconData directionIcon = diff > 0
        ? Icons.arrow_upward
        : (diff < 0 ? Icons.arrow_downward : Icons.remove);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _MiniStat(l10n: l10n, label: firstLabel, value: firstValue),
            ),
            Icon(Icons.trending_flat, color: _muted.withValues(alpha: 0.6)),
            Expanded(
              child: _MiniStat(l10n: l10n, label: secondLabel, value: secondValue),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xffeaf2fc),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(directionIcon, color: _blue, size: 16),
                  const SizedBox(height: 2),
                  Text(
                    _signed(diff, ' ${l10n.cmUnit}'),
                    style: const TextStyle(
                      color: _blue,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    _signed(pct, '%'),
                    style: TextStyle(
                      color: _blue.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final AppLocalizations l10n;
  final String label;
  final double value;

  const _MiniStat({required this.l10n, required this.label, required this.value});

  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        Text(
          '${value.toStringAsFixed(1)} ${l10n.cmUnit}',
          style: const TextStyle(color: _dark, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
