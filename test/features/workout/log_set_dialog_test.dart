import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/log_set_dialog.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('set note field stays reachable and returns with logged values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    LogSetResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<LogSetResult>(
                  context: context,
                  builder: (_) => LogSetDialog(
                    exerciseName: 'Bench Press',
                    previousSets: [
                      ExerciseSet(
                        exerciseName: 'Bench Press',
                        weight: 40,
                        reps: 8,
                        date: DateTime(2025, 5, 1),
                        notes: 'Keep elbows tucked',
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    expect(fields, findsNWidgets(3));
    expect(tester.widget<TextField>(fields.at(2)).minLines, 2);
    expect(
      tester.widget<TextField>(fields.at(2)).decoration?.prefixIcon,
      isA<Icon>().having(
        (icon) => icon.icon,
        'icon',
        Icons.sticky_note_2_outlined,
      ),
    );
    expect(find.text('Keep elbows tucked'), findsOneWidget);

    await tester.enterText(fields.at(0), '42.5');
    await tester.enterText(fields.at(1), '10');
    await tester.enterText(fields.at(2), 'Keep my shoulders relaxed');
    await tester.tap(find.text(l10n.logFirstSetButton));
    await tester.pumpAndSettle();

    expect(result?.weight, 42.5);
    expect(result?.reps, 10);
    expect(result?.notes, 'Keep my shoulders relaxed');
  });

  testWidgets('Arabic note field follows RTL direction', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const LogSetDialog(
                  exerciseName: 'ضغط صدر',
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final noteField = tester.widget<TextField>(find.byType(TextField).last);
    expect(noteField.decoration?.hintText, 'ملاحظات (اختياري)');
    expect(
      Directionality.of(tester.element(find.byType(TextField).last)),
      TextDirection.rtl,
    );
  });
}
