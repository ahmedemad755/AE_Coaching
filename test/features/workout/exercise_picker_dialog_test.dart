import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_name_normalizer.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_picker_dialog.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/exercise_library_card.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CustomRepository extends CustomExerciseRepository {
  final List<CustomExercise> exercises = [];

  _CustomRepository()
    : super(storageManager: UserStorageManager(), uidOverride: () => 'test');

  @override
  Future<List<CustomExercise>> getAllExercises() async => List.of(exercises);

  @override
  Future<CustomExercise> createExercise({
    required String name,
    String? muscleGroup,
    String? equipment,
  }) async {
    final exercise = CustomExercise(
      id: 'custom-${exercises.length}',
      name: name,
      muscleGroup: muscleGroup,
      equipment: equipment,
      createdAt: DateTime.now(),
    );
    exercises.add(exercise);
    return exercise;
  }
}

class _Catalog implements ExerciseLibraryCatalog {
  final CustomExerciseRepository customExercises;

  const _Catalog(this.customExercises);
  static const items = [
    ExerciseLibraryItem(
      id: 'bench',
      nameEn: 'Bench Press',
      nameAr: 'بنش صدر',
      muscleGroup: 'chest',
      equipment: 'barbell',
      source: ExerciseLibraryItemSource.builtIn,
    ),
    ExerciseLibraryItem(
      id: 'row',
      nameEn: 'Cable Row',
      nameAr: 'سحب كيبل',
      muscleGroup: 'back',
      equipment: 'cable',
      source: ExerciseLibraryItemSource.builtIn,
    ),
  ];

  @override
  Future<List<ExerciseLibraryItem>> search({
    String query = '',
    Set<String> muscleGroups = const {},
    Set<String> equipment = const {},
  }) async {
    final normalized = normalizeExerciseName(query);
    final all = [
      ...items,
      ...(await customExercises.getAllExercises()).map(
        ExerciseLibraryItem.fromCustom,
      ),
    ];
    return all.where((item) {
      final matchesName =
          normalized.isEmpty ||
          normalizeExerciseName(item.nameEn).contains(normalized) ||
          normalizeExerciseName(item.nameAr ?? '').contains(normalized);
      return matchesName &&
          (muscleGroups.isEmpty || muscleGroups.contains(item.muscleGroup)) &&
          (equipment.isEmpty || equipment.contains(item.equipment));
    }).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _CustomRepository customExercises;

  setUp(() {
    customExercises = _CustomRepository();
  });

  Widget app(
    Locale locale, {
    ThemeMode themeMode = ThemeMode.light,
    double textScale = 1,
  }) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ExercisePickerDialog(
      catalog: _Catalog(customExercises),
      customExercises: customExercises,
      languageCode: locale.languageCode,
    ),
  );

  testWidgets('All clears search and filters without clearing selection', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press'));
    await tester.enterText(find.byType(TextField).first, 'row');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Cable Row'), findsOneWidget);
    expect(find.text('Add selected (1)'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const ValueKey('exercise-selection-bench')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('small picker supports large text and keyboard inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      app(const Locale('ar'), themeMode: ThemeMode.dark, textScale: 1.3),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseLibraryCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection survives search changes and no result counts appear', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Cable Row'), findsOneWidget);

    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    expect(find.text('Add selected (1)'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'cable');
    await tester.pumpAndSettle();
    expect(find.text('Cable Row'), findsOneWidget);
    expect(find.text('Add selected (1)'), findsOneWidget);
    expect(find.textContaining('results found'), findsNothing);
    expect(find.textContaining('180'), findsNothing);
  });

  testWidgets('failed save keeps selection open for retry', (tester) async {
    var attempts = 0;
    List<ExerciseLibraryItem>? returned;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                returned = await showDialog<List<ExerciseLibraryItem>>(
                  context: context,
                  builder: (_) => ExercisePickerDialog(
                    catalog: _Catalog(customExercises),
                    customExercises: customExercises,
                    languageCode: 'en',
                    onAddSelected: (_) async {
                      attempts++;
                      if (attempts == 1) {
                        throw StateError('temporary save error');
                      }
                    },
                  ),
                );
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add selected (1)'));
    await tester.pumpAndSettle();

    expect(find.byType(ExercisePickerDialog), findsOneWidget);
    expect(find.text('Add selected (1)'), findsOneWidget);
    expect(find.text('Could not add the selected exercises.'), findsOneWidget);
    expect(returned, isNull);

    await tester.tap(find.text('Add selected (1)'));
    await tester.pumpAndSettle();
    expect(find.byType(ExercisePickerDialog), findsNothing);
    expect(returned!.single.id, 'bench');
    expect(attempts, 2);
  });

  testWidgets('system back closes the picker without losing the host screen', (
    tester,
  ) async {
    var returnedFromPicker = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => ExercisePickerDialog(
                    catalog: _Catalog(customExercises),
                    customExercises: customExercises,
                    languageCode: 'en',
                  ),
                );
                returnedFromPicker = true;
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Open picker'), findsOneWidget);
    expect(find.byType(ExercisePickerDialog), findsNothing);
    expect(returnedFromPicker, isTrue);
  });

  testWidgets('Arabic locale renders Arabic exercise names', (tester) async {
    await tester.pumpWidget(app(const Locale('ar')));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(ExercisePickerDialog))),
      TextDirection.rtl,
    );
    expect(find.text('بنش صدر'), findsOneWidget);
    expect(find.text('سحب كيبل'), findsOneWidget);
  });

  testWidgets('dark picker keeps selection and filters usable in RTL', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Locale('ar'), themeMode: ThemeMode.dark));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(ExercisePickerDialog))),
      TextDirection.rtl,
    );
    expect(find.byType(ExerciseLibraryCard), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('exercise-selection-bench')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(find.text(l10n.addSelectedExercisesButton(1)), findsOneWidget);
    await tester.tap(find.text(l10n.exerciseFiltersTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('muscle-filter-chest')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.addSelectedExercisesButton(1)), findsOneWidget);
  });

  testWidgets('muscle and equipment filters apply together', (tester) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('muscle-filter-chest')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment-filter-barbell')));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Cable Row'), findsNothing);
  });

  testWidgets('custom exercise creation immediately selects the saved item', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create custom exercise'));
    await tester.pumpAndSettle();
    final nameField = find.byType(TextField).at(1);
    await tester.tap(nameField);
    await tester.enterText(nameField, 'My New Exercise');
    await tester.pump();
    final createButton = find.widgetWithText(FilledButton, 'Create');
    expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('My New Exercise'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('My New Exercise'), findsOneWidget);
    expect(find.text('Add selected (1)'), findsOneWidget);
    expect(
      (await customExercises.getAllExercises()).single.name,
      'My New Exercise',
    );
  });
}
