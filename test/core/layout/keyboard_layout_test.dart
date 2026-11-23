import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_picker_dialog.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/create_program_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/log_set_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/name_only_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/rename_program_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_exercise_targets_dialog.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'keyboard_phone.dart';

class _CustomExercises extends CustomExerciseRepository {
  _CustomExercises()
    : super(storageManager: UserStorageManager(), uidOverride: () => 'layout');

  @override
  Future<List<CustomExercise>> getAllExercises() async => const [];
}

class _Catalog implements ExerciseLibraryCatalog {
  const _Catalog(this.custom);

  final CustomExerciseRepository custom;

  @override
  Future<List<ExerciseLibraryItem>> search({
    String query = '',
    Set<String> muscleGroups = const {},
    Set<String> equipment = const {},
  }) async => [
    for (var i = 0; i < 8; i++)
      ExerciseLibraryItem(
        id: 'e$i',
        nameEn: 'Incline dumbbell bench press variation $i',
        nameAr: 'ضغط صدر بالدمبل على مقعد مائل $i',
        muscleGroup: 'chest',
        equipment: 'dumbbell',
        source: ExerciseLibraryItemSource.builtIn,
      ),
  ];
}

/// Every keyboard dialog on a small phone with the keyboard open, in both
/// languages, at normal and large font sizes: nothing may overflow, and the
/// primary action must stay reachable above the keyboard.
void main() {
  Widget launcher(String language, WidgetBuilder dialog) => MaterialApp(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('open'),
            onPressed: () =>
                showDialog<void>(context: context, builder: dialog),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  final longName =
      'Single-arm dumbbell bench press on an incline with a long pause';
  final dialogs = <String, WidgetBuilder>{
    'log set (with last-time sets and notes)': (_) => LogSetDialog(
      exerciseName: longName,
      previousSets: [
        for (var i = 0; i < 3; i++)
          ExerciseSet(
            exerciseName: longName,
            weight: 62.5,
            reps: 10,
            date: DateTime(2026, 11, 1),
            notes: 'Slow eccentric, felt the shoulder a little on the last rep',
          ),
      ],
    ),
    'create program': (_) => const CreateProgramDialog(),
    'name only (create / rename day)': (context) => NameOnlyDialog(
      title: AppLocalizations.of(context)!.renameProgramTitle,
      hint: AppLocalizations.of(context)!.programNameHint,
      saveLabel: AppLocalizations.of(context)!.save,
      cancelLabel: AppLocalizations.of(context)!.cancel,
      emptyValueMessage: 'empty',
      initialValue: longName,
    ),
    'rename program': (_) => RenameProgramDialog(currentName: longName),
    'exercise targets': (_) => WorkoutExerciseTargetsDialog(
      assignment: WorkoutTemplateExerciseAssignment(
        assignmentId: 'a',
        exerciseId: 'e',
        exerciseNameSnapshot: longName,
        referenceType: 'builtIn',
        workingSets: 3,
        targetRepsMin: 8,
        targetRepsMax: 12,
        restSeconds: 90,
      ),
    ),
  };

  for (final fullScreen in [false, true]) {
    for (final language in ['en', 'ar']) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          'exercise picker${fullScreen ? ' (full screen)' : ''} · $language · text ×$scale: '
          'search and "create custom exercise" fit above the keyboard',
          (tester) async {
            useSmallPhone(tester, textScale: scale);
            final custom = _CustomExercises();
            await tester.pumpWidget(
              launcher(
                language,
                (_) => ExercisePickerDialog(
                  catalog: _Catalog(custom),
                  customExercises: custom,
                  languageCode: language,
                  fullScreen: fullScreen,
                ),
              ),
            );
            await tester.tap(find.byKey(const ValueKey('open')));
            await tester.pumpAndSettle();
            expectNoOverflow(tester);
            // Keyboard closed: the add button sits above the navigation bar.
            final add = find.descendant(
              of: find.byType(ExercisePickerDialog),
              matching: find.byWidgetPredicate((w) => w is FilledButton),
            );
            expect(
              tester.getRect(add).bottom,
              lessThanOrEqualTo(smallPhone.height - navigationBar),
            );

            // Typing in the search field.
            await tester.showKeyboard(find.byType(TextField).first);
            await setKeyboard(tester, open: true);
            expectNoOverflow(tester);
            expectActionsAboveKeyboard(tester);

            // Closing the keyboard restores the full header without a
            // single overflowing frame.
            await setKeyboard(tester, open: false);
            expectNoOverflow(tester);

            // Create custom exercise (3 fields).
            final l10n = AppLocalizations.of(
              tester.element(find.byType(ExercisePickerDialog)),
            )!;
            await tester.tap(find.text(l10n.createCustomExerciseButton));
            await tester.pumpAndSettle();
            await setKeyboard(tester, open: true);
            expectNoOverflow(tester);
            final createDialog = find.ancestor(
              of: find.text(l10n.createCustomExerciseTitle),
              matching: find.byType(AlertDialog),
            );
            final create = find.descendant(
              of: createDialog,
              matching: find.byType(FilledButton),
            );
            expect(
              tester.getRect(create).bottom,
              lessThanOrEqualTo(smallPhone.height - keyboardHeight),
            );
          },
        );
      }
    }
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      'exercise picker · $language · landscape phone: compact, filters still reachable',
      (tester) async {
        tester.view
          ..physicalSize = const Size(640, 360)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final custom = _CustomExercises();
        await tester.pumpWidget(
          launcher(
            language,
            (_) => ExercisePickerDialog(
              catalog: _Catalog(custom),
              customExercises: custom,
              languageCode: language,
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        await tester.tap(find.byKey(const ValueKey('picker-compact-filters')));
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
        expect(find.byType(FilterChip), findsWidgets); // the filters sheet
      },
    );
  }

  for (final MapEntry(key: name, value: dialog) in dialogs.entries) {
    for (final language in ['en', 'ar']) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '$name · $language · text ×$scale: fits above the keyboard',
          (tester) async {
            useSmallPhone(tester, keyboard: true, textScale: scale);
            await tester.pumpWidget(launcher(language, dialog));
            await tester.tap(find.byKey(const ValueKey('open')));
            await tester.pumpAndSettle();
            expectNoOverflow(tester);
            expectActionsAboveKeyboard(tester);
          },
        );
      }
    }
  }
}
