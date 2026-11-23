import 'package:ae_coaching/core/theme/appearance_settings_dialog.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/theme/theme_cubit.dart';
import 'package:ae_coaching/core/theme/theme_preference_store.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryThemeStore implements ThemePreferenceStore {
  ThemeMode value = ThemeMode.system;

  @override
  ThemeMode read(String uid) => value;

  @override
  Future<void> write(String uid, ThemeMode mode) async {
    value = mode;
  }
}

void main() {
  testWidgets('shows localized theme choices in Arabic RTL and applies Dark', (
    tester,
  ) async {
    final cubit = ThemeCubit(
      store: _MemoryThemeStore(),
      userChanges: const Stream.empty(),
      initialUid: 'user-a',
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, mode) => MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AppearanceSettingsDialog(),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('\u0627\u0644\u0645\u0638\u0647\u0631'), findsOneWidget);
    expect(find.text('\u0641\u0627\u062a\u062d'), findsOneWidget);
    expect(find.text('\u062f\u0627\u0643\u0646'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(AlertDialog))),
      TextDirection.rtl,
    );

    await tester.tap(find.text('\u062f\u0627\u0643\u0646'));
    await tester.pumpAndSettle();
    expect(cubit.state, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
  });
}
