import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/features/measurements/presentation/cubit/measurement_cubit.dart';
import 'package:ae_coaching/features/measurements/presentation/screens/add_edit_measurement_screen.dart';
import 'package:ae_coaching/features/measurements/presentation/screens/measurement_analytics_screen.dart';
import 'package:ae_coaching/features/measurements/presentation/screens/measurement_history_screen.dart';
import 'package:ae_coaching/features/measurements/presentation/widgets/measurement_values_list.dart';
import 'package:ae_coaching/features/progress_photos/presentation/cubit/progress_photo_cubit.dart';
import 'package:ae_coaching/features/progress_photos/presentation/screens/progress_photos_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

/// Body Measurements home screen: shows the latest check-in and gives
/// access to Add / History / Analytics.
///
/// Completely separate from the Workout Tracker — it only ever talks
/// to [MeasurementCubit], never to WorkoutCubit or the workout Hive
/// boxes.
class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _muted = Color(0xff7d8792);

  // Retains the last successfully loaded box across transient states
  // (e.g. the silent background Firestore sync, or a save/delete
  // round-trip) so the screen never flashes a spinner/error over data
  // that is already on screen — same pattern hom.dart uses for the
  // workout box.
  Box<BodyMeasurement>? _box;

  @override
  void initState() {
    super.initState();
    context.read<MeasurementCubit>().loadMeasurements();
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Also provides ProgressPhotoCubit: after saving a NEW check-in,
        // AddEditMeasurementScreen offers an optional "add a progress
        // photo?" prompt. Editing an existing check-in never needs it.
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<MeasurementCubit>()),
            BlocProvider(create: (_) => sl<ProgressPhotoCubit>()),
          ],
          child: const AddEditMeasurementScreen(),
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<MeasurementCubit>(),
          child: const MeasurementHistoryScreen(),
        ),
      ),
    );
  }

  void _openAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<MeasurementCubit>(),
          child: const MeasurementAnalyticsScreen(),
        ),
      ),
    );
  }

  void _openPhotos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<ProgressPhotoCubit>(),
          child: const ProgressPhotosScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xfff5f9fc),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Text(l10n.bodyMeasurementsTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 10,
        icon: const Icon(Icons.add_circle_outline),
        label: Text(
          l10n.addMeasurementButton,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: BlocConsumer<MeasurementCubit, MeasurementState>(
        listener: (context, state) {
          if (state is MeasurementSuccess && _box != state.box) {
            setState(() => _box = state.box);
          }
          if (state is MeasurementError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, state) {
          final box = _box;

          if (box == null) {
            if (state is MeasurementError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.somethingWrongLoadingMeasurements,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.read<MeasurementCubit>().loadMeasurements(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator(color: _blue));
          }

          return ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<BodyMeasurement> liveBox, _) {
              final all = liveBox.values.toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                children: [
                  if (all.isEmpty)
                    _EmptyState(onAdd: _openAdd)
                  else
                    _LatestCheckInCard(measurement: all.first),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.history,
                          label: l10n.historyButton,
                          onTap: _openHistory,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.analytics_outlined,
                          label: l10n.analyticsButton,
                          onTap: _openAnalytics,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.photo_camera_back_outlined,
                          label: l10n.photosButton,
                          onTap: _openPhotos,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _LatestCheckInCard extends StatelessWidget {
  final BodyMeasurement measurement;

  const _LatestCheckInCard({required this.measurement});

  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateLocale = Localizations.localeOf(context).toString();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.lastCheckInLabel,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('d MMM yyyy', dateLocale).format(measurement.date),
            style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(height: 16),
          MeasurementValuesList(measurement: measurement),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.straighten, color: _blue, size: 40),
          const SizedBox(height: 14),
          Text(
            l10n.noMeasurementsYetTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.addFirstCheckInSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l10n.addMeasurementButton),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  static const Color _blue = Color(0xff2f80ed);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: _blue, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: _blue,
        side: const BorderSide(color: _blue),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
