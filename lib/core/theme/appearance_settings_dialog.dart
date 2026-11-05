import 'package:ae_coaching/core/theme/theme_cubit.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppearanceSettingsDialog extends StatelessWidget {
  const AppearanceSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.appearanceTitle),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      content: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, selectedMode) => RadioGroup<ThemeMode>(
          groupValue: selectedMode,
          onChanged: (mode) async {
            if (mode == null) return;
            try {
              await context.read<ThemeCubit>().setThemeMode(mode);
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.themePreferenceSaveError)),
                );
              }
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ThemeModeOption(
                mode: ThemeMode.system,
                label: l10n.themeSystemDefault,
              ),
              _ThemeModeOption(mode: ThemeMode.light, label: l10n.themeLight),
              _ThemeModeOption(mode: ThemeMode.dark, label: l10n.themeDark),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  final ThemeMode mode;
  final String label;

  const _ThemeModeOption({required this.mode, required this.label});

  @override
  Widget build(BuildContext context) =>
      RadioListTile<ThemeMode>(value: mode, title: Text(label));
}
