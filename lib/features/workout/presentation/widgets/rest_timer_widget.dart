import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

String _formatElapsed(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Optional, non-blocking rest timer shown on the active workout
/// screen (Phase 17). Manual count-up only — the user starts and stops
/// it themselves; it never auto-starts and never ends on its own. See
/// [RestTimerCubit]'s class docs.
class RestTimerWidget extends StatelessWidget {
  const RestTimerWidget({super.key});

  static const Color _dark = Color(0xff202936);
  static const Color _muted = Color(0xff7d8792);
  static const Color _blue = Color(0xff2f80ed);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<RestTimerCubit, RestTimerState>(
      builder: (context, state) {
        final cubit = context.read<RestTimerCubit>();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xffd5e3f2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: _blue, size: 20),
              const SizedBox(width: 8),
              Text(l10n.restTimerLabel, style: const TextStyle(color: _dark, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 10),
              Text(
                _formatElapsed(state.elapsed),
                style: const TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const Spacer(),
              if (state.elapsed > Duration.zero)
                IconButton(
                  icon: const Icon(Icons.replay, size: 18, color: _muted),
                  tooltip: l10n.resetRestTimerTooltip,
                  onPressed: cubit.reset,
                ),
              TextButton(
                onPressed: state.isRunning ? cubit.stop : cubit.start,
                child: Text(state.isRunning ? l10n.stopRestTimerButton : l10n.startRestTimerButton),
              ),
            ],
          ),
        );
      },
    );
  }
}
