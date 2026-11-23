import 'dart:async';

import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/rest_timer_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/rest_timer_sound.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

String _formatRemaining(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${minutes.toString().padLeft(2, '0')}:$seconds';
}

class RestTimerWidget extends StatefulWidget {
  final bool lockCountdownControls;
  final VoidCallback? onStarted;
  final VoidCallback? onCompleted;

  const RestTimerWidget({
    super.key,
    this.lockCountdownControls = false,
    this.onStarted,
    this.onCompleted,
  });

  @override
  State<RestTimerWidget> createState() => _RestTimerWidgetState();
}

class _RestTimerWidgetState extends State<RestTimerWidget> {
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;

  @override
  void initState() {
    super.initState();
    final duration = context.read<RestTimerCubit>().state.configuredDuration;
    _minutesController = TextEditingController(
      text: duration.inMinutes.toString(),
    );
    _secondsController = TextEditingController(
      text: duration.inSeconds.remainder(60).toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _updateDuration() {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    if (seconds > 59) return;
    context.read<RestTimerCubit>().configure(
      Duration(minutes: minutes, seconds: seconds),
    );
  }

  Widget _durationField({
    required TextEditingController controller,
    required String label,
    required String key,
  }) {
    final colors = context.appColors;
    return SizedBox(
      width: 72,
      height: 48,
      child: TextField(
        key: ValueKey(key),
        controller: controller,
        enabled:
            !context.watch<RestTimerCubit>().state.isRunning &&
            !widget.lockCountdownControls,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 3,
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 6),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        onChanged: (_) => _updateDuration(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return BlocListener<RestTimerCubit, RestTimerState>(
      listenWhen: (previous, current) =>
          previous.isRunning &&
          !current.isRunning &&
          current.remaining == Duration.zero,
      listener: (context, state) {
        widget.onCompleted?.call();
        unawaited(RestTimerSound.play());
      },
      child: BlocBuilder<RestTimerCubit, RestTimerState>(
        builder: (context, state) {
          final cubit = context.read<RestTimerCubit>();
          final scheme = Theme.of(context).colorScheme;
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: scheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.restTimerLabel,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      _formatRemaining(state.remaining),
                      key: const ValueKey('rest-timer-remaining'),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (state.isRunning ||
                        state.remaining != state.configuredDuration)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.replay,
                          size: 18,
                          color: colors.textMuted,
                        ),
                        tooltip: l10n.resetRestTimerTooltip,
                        onPressed: widget.lockCountdownControls
                            ? null
                            : cubit.reset,
                      ),
                    TextButton(
                      onPressed: widget.lockCountdownControls
                          ? null
                          : state.isRunning
                          ? cubit.stop
                          : (state.configuredDuration > Duration.zero
                                ? () {
                                    cubit.startCountdown();
                                    widget.onStarted?.call();
                                  }
                                : null),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        state.isRunning
                            ? l10n.stopRestTimerButton
                            : l10n.startRestTimerButton,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.restDurationLabel,
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ),
                    _durationField(
                      controller: _minutesController,
                      label: l10n.restMinutesLabel,
                      key: 'rest-minutes-input',
                    ),
                    const SizedBox(width: 8),
                    _durationField(
                      controller: _secondsController,
                      label: l10n.restSecondsLabel,
                      key: 'rest-seconds-input',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 5,
                    color: scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
