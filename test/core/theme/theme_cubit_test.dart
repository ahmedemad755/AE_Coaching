import 'dart:async';

import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/theme/theme_cubit.dart';
import 'package:ae_coaching/core/theme/theme_preference_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryThemeStore implements ThemePreferenceStore {
  final values = <String, ThemeMode>{};

  @override
  ThemeMode read(String uid) => values[uid] ?? ThemeMode.system;

  @override
  Future<void> write(String uid, ThemeMode mode) async {
    values[uid] = mode;
  }
}

void main() {
  test(
    'restores each user preference as the authenticated user changes',
    () async {
      final store = _MemoryThemeStore()
        ..values['user-a'] = ThemeMode.dark
        ..values['user-b'] = ThemeMode.dark;
      final userChanges = StreamController<String?>.broadcast();
      final cubit = ThemeCubit(
        store: store,
        userChanges: userChanges.stream,
        initialUid: 'user-a',
      );
      addTearDown(() async {
        await cubit.close();
        await userChanges.close();
      });

      expect(cubit.state, ThemeMode.dark);
      await cubit.setThemeMode(ThemeMode.light);
      expect(store.read('user-a'), ThemeMode.light);

      userChanges.add('user-b');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, ThemeMode.dark);

      userChanges.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, ThemeMode.system);

      userChanges.add('user-a');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, ThemeMode.light);
    },
  );

  testWidgets(
    'System follows live platform changes, explicit modes override them, and UI state survives',
    (tester) async {
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );

      var mode = ThemeMode.system;
      Widget buildApp() => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: const _WorkoutStateProbe(key: ValueKey('workout-probe')),
      );

      await tester.pumpWidget(buildApp());
      expect(
        Theme.of(tester.element(find.byType(_WorkoutStateProbe))).brightness,
        Brightness.dark,
      );

      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.light;
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(_WorkoutStateProbe))).brightness,
        Brightness.light,
      );

      await tester.tap(find.text('Add set'));
      await tester.pump();
      expect(find.text('Sets: 1'), findsOneWidget);

      mode = ThemeMode.light;
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Sets: 1'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(_WorkoutStateProbe))).brightness,
        Brightness.light,
      );

      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(_WorkoutStateProbe))).brightness,
        Brightness.light,
      );

      mode = ThemeMode.dark;
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(_WorkoutStateProbe))).brightness,
        Brightness.dark,
      );
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.light;
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(_WorkoutStateProbe))).brightness,
        Brightness.dark,
      );
      expect(find.text('Sets: 1'), findsOneWidget);
    },
  );
}

class _WorkoutStateProbe extends StatefulWidget {
  const _WorkoutStateProbe({super.key});

  @override
  State<_WorkoutStateProbe> createState() => _WorkoutStateProbeState();
}

class _WorkoutStateProbeState extends State<_WorkoutStateProbe> {
  int sets = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('Sets: $sets'),
        TextButton(
          onPressed: () => setState(() => sets++),
          child: const Text('Add set'),
        ),
      ],
    ),
  );
}
