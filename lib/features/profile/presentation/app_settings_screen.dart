import 'package:ae_coaching/core/localization/locale_cubit.dart';
import 'package:ae_coaching/core/notifications/fcm_device_service.dart';
import 'package:ae_coaching/core/notifications/inactivity_reminder_service.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/theme/theme_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/exercise_sources_screen.dart';
import 'package:ae_coaching/features/profile/presentation/profile_navigation.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key, required this.onLogout});

  final ProfileLogoutCallback onLogout;

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen>
    with WidgetsBindingObserver {
  late Future<AuthorizationStatus> _permissionStatus;
  late Stream<bool> _reminderPreference;
  bool _savingReminder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _permissionStatus = sl<FcmDeviceService>()
        .notificationAuthorizationStatus();
    _reminderPreference = sl<InactivityReminderService>().watch();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {
        _permissionStatus = sl<FcmDeviceService>()
            .notificationAuthorizationStatus();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _setTheme(ThemeMode mode) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<ThemeCubit>().setThemeMode(mode);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.themePreferenceSaveError)));
      }
    }
  }

  Future<void> _showPermissionHelp() async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsPermissionHelpAction),
        content: Text(l10n.settingsPermissionHelpBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _setReminder(bool enabled) async {
    if (_savingReminder) return;
    setState(() => _savingReminder = true);
    try {
      await sl<InactivityReminderService>().setEnabled(enabled);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.inactivityReminderSaveFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingReminder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text(l10n.appSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _SectionTitle(title: l10n.settingsLanguage),
          BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) => Column(
              children: [
                _ChoiceTile(
                  title: 'العربية',
                  selected: locale.languageCode == 'ar',
                  onTap: () =>
                      context.read<LocaleCubit>().setLocale(const Locale('ar')),
                ),
                _ChoiceTile(
                  title: 'English',
                  selected: locale.languageCode == 'en',
                  onTap: () =>
                      context.read<LocaleCubit>().setLocale(const Locale('en')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: l10n.appearanceTitle),
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, mode) => Column(
              children: [
                _ChoiceTile(
                  title: l10n.themeSystemDefault,
                  icon: Icons.brightness_auto_outlined,
                  selected: mode == ThemeMode.system,
                  onTap: () => _setTheme(ThemeMode.system),
                ),
                _ChoiceTile(
                  title: l10n.themeLight,
                  icon: Icons.light_mode_outlined,
                  selected: mode == ThemeMode.light,
                  onTap: () => _setTheme(ThemeMode.light),
                ),
                _ChoiceTile(
                  title: l10n.themeDark,
                  icon: Icons.dark_mode_outlined,
                  selected: mode == ThemeMode.dark,
                  onTap: () => _setTheme(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: l10n.settingsNotifications),
          StreamBuilder<bool>(
            stream: _reminderPreference,
            builder: (context, snapshot) => SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.inactivityRemindersTitle),
              value: snapshot.data ?? true,
              onChanged: _savingReminder || !snapshot.hasData
                  ? null
                  : _setReminder,
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 4,
              end: 4,
              bottom: 8,
            ),
            child: Text(
              l10n.settingsNotificationPermissionNote,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ),
          FutureBuilder<AuthorizationStatus>(
            future: _permissionStatus,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(
                  leading: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_none),
                  title: Text(l10n.settingsNotificationNotRequested),
                );
              }
              final status = snapshot.data!;
              final allowed =
                  status.name == 'authorized' ||
                  status.name == 'provisional' ||
                  status.name == 'ephemeral';
              final notRequested = status.name == 'notDetermined';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  allowed
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  color: allowed ? colors.success : colors.textMuted,
                ),
                title: Text(
                  allowed
                      ? l10n.settingsNotificationAuthorized
                      : notRequested
                      ? l10n.settingsNotificationNotRequested
                      : l10n.settingsNotificationDenied,
                ),
                trailing: allowed
                    ? null
                    : IconButton(
                        tooltip: l10n.settingsPermissionHelpAction,
                        onPressed: _showPermissionHelp,
                        icon: const Icon(Icons.help_outline),
                      ),
              );
            },
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.repdbDataSources),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ExerciseSourcesScreen(),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(l10n.logoutTooltip),
            subtitle: Text(l10n.settingsLogoutDescription),
            onTap: widget.onLogout,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: icon == null ? null : Icon(icon),
    title: Text(title),
    trailing: selected
        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
        : const SizedBox(width: 24),
    onTap: onTap,
  );
}
