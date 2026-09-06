import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/features/measurements/presentation/cubit/measurement_cubit.dart';
import 'package:ae_coaching/features/measurements/presentation/screens/add_edit_measurement_screen.dart';
import 'package:ae_coaching/features/measurements/presentation/widgets/measurement_values_list.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

/// Lists every recorded check-in, newest first, with view/edit/delete.
class MeasurementHistoryScreen extends StatefulWidget {
  const MeasurementHistoryScreen({super.key});

  @override
  State<MeasurementHistoryScreen> createState() => _MeasurementHistoryScreenState();
}

class _MeasurementHistoryScreenState extends State<MeasurementHistoryScreen> {
  static const Color _blue = Color(0xff2f80ed);
  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);

  // Retains the last successfully loaded box so a transient state (a
  // background Firestore sync, or a delete round-trip) never flashes a
  // spinner/error over data that is already on screen.
  Box<BodyMeasurement>? _box;

  @override
  void initState() {
    super.initState();
    final state = context.read<MeasurementCubit>().state;
    if (state is MeasurementSuccess) {
      _box = state.box;
    }
  }

  Future<bool> _confirmDelete(BuildContext context, DateTime date) async {
    final l10n = AppLocalizations.of(context)!;
    final dateLocale = Localizations.localeOf(context).toString();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xfff5f9fc),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          l10n.deleteCheckInTitle,
          style: const TextStyle(fontWeight: FontWeight.w900, color: _dark),
        ),
        content: Text(
          l10n.deleteCheckInBody(DateFormat('d MMM yyyy', dateLocale).format(date)),
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: const TextStyle(color: _blue)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.delete, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateLocale = Localizations.localeOf(context).toString();
    return Scaffold(
      backgroundColor: const Color(0xfff5f9fc),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        title: Text(l10n.measurementHistoryTitle),
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
                child: Text(
                  l10n.unableToLoadHistory,
                  style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
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

              if (all.isEmpty) {
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
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                itemCount: all.length,
                itemBuilder: (context, index) {
                  final measurement = all[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        leading: const CircleAvatar(
                          radius: 17,
                          backgroundColor: Color(0xffd6e9ff),
                          child: Icon(Icons.straighten, color: _blue, size: 18),
                        ),
                        title: Text(
                          DateFormat('d MMM yyyy', dateLocale).format(measurement.date),
                          style: const TextStyle(color: _dark, fontWeight: FontWeight.w900),
                        ),
                        children: [
                          const Divider(height: 18),
                          MeasurementValuesList(measurement: measurement),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BlocProvider.value(
                                          value: context.read<MeasurementCubit>(),
                                          child: AddEditMeasurementScreen(existing: measurement),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: Text(l10n.edit),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _blue,
                                    side: const BorderSide(color: _blue),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final confirmed =
                                        await _confirmDelete(context, measurement.date);
                                    if (confirmed) {
                                      // ignore: use_build_context_synchronously
                                      context.read<MeasurementCubit>().deleteMeasurement(measurement.key);
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: Text(l10n.delete),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
