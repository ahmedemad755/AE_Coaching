import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/measurements/presentation/widgets/measurement_values_list.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'Measurement history values use $mode semantic text in Arabic',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: Scaffold(
              body: Center(
                child: MeasurementValuesList(
                  measurement: BodyMeasurement(
                    date: DateTime(2026, 10, 18),
                    chest: 102.5,
                    waist: 81,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(MeasurementValuesList));
        final l10n = AppLocalizations.of(context)!;
        expect(Directionality.of(context), TextDirection.rtl);
        expect(
          Theme.of(context).brightness,
          mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
        );
        expect(find.text(l10n.fieldChest), findsOneWidget);
        expect(find.text(l10n.fieldWaist), findsOneWidget);
        expect(find.text('102.5 ${l10n.cmUnit}'), findsOneWidget);

        final measurementLabel = tester.widget<Text>(
          find.text(l10n.fieldChest),
        );
        final measurementValue = tester.widget<Text>(
          find.text('102.5 ${l10n.cmUnit}'),
        );
        expect(measurementLabel.style?.color, context.appColors.textMuted);
        expect(measurementValue.style?.color, context.appColors.textPrimary);
      },
    );
  }
}
