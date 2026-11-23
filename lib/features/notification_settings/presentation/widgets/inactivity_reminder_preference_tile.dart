import 'package:ae_coaching/core/feedback/app_feedback.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/notification_settings/presentation/cubit/notification_preferences_cubit.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The workout inactivity reminder switch. Reports saving through the
/// global feedback overlay and never claims success before the server
/// confirmed it.
class InactivityReminderPreferenceTile extends StatelessWidget {
  const InactivityReminderPreferenceTile({super.key});

  Future<void> _toggle(BuildContext context, bool enabled) async {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<NotificationPreferencesCubit>();
    final loading = AppFeedback.loading(l10n.inactivityReminderSaving);
    switch (await cubit.setEnabled(enabled)) {
      case PreferenceSaveOutcome.confirmed:
        loading.success(l10n.inactivityReminderSaved);
      case PreferenceSaveOutcome.pendingSync:
        loading.dismiss();
        AppFeedback.info(l10n.inactivityReminderSavedOffline, dedupeKey: 'inactivity-reminder-pending');
      case PreferenceSaveOutcome.rejected:
      case PreferenceSaveOutcome.failed:
      case PreferenceSaveOutcome.accountChanged:
        loading.error(l10n.inactivityReminderSaveFailed);
      case PreferenceSaveOutcome.busy:
        loading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muted = Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.textMuted);
    return BlocBuilder<NotificationPreferencesCubit, NotificationPreferencesState>(
      builder: (context, state) {
        final String subtitle;
        Widget? action;
        switch (state.status) {
          case NotificationPreferencesStatus.loading:
            subtitle = l10n.inactivityReminderLoading;
          case NotificationPreferencesStatus.ready:
            subtitle = state.pendingSync ? l10n.inactivityReminderPendingSync : l10n.inactivityRemindersSubtitle;
          case NotificationPreferencesStatus.offline:
            subtitle = l10n.inactivityReminderOffline;
          case NotificationPreferencesStatus.unavailable:
            subtitle = l10n.inactivityReminderUnavailable;
          case NotificationPreferencesStatus.failure:
            subtitle = l10n.inactivityReminderLoadFailed;
            action = TextButton(
              onPressed: () => context.read<NotificationPreferencesCubit>().start(),
              child: Text(l10n.retry),
            );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              key: const ValueKey('inactivity-reminder-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.inactivityRemindersTitle),
              subtitle: Text(subtitle, style: muted),
              value: state.enabled,
              onChanged: state.canToggle ? (value) => _toggle(context, value) : null,
            ),
            if (action != null) Align(alignment: AlignmentDirectional.centerStart, child: action),
          ],
        );
      },
    );
  }
}
