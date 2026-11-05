import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program_draft.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/standard_workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/presentation/screens/standard_workout_templates_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/standard_template_fixtures.dart';

class _Custom extends CustomExerciseRepository {
  _Custom(StandardTemplateFixture f)
    : super(storageManager: f.storage, uidOverride: () => f.uid);
  @override
  Future<List<CustomExercise>> getAllExercises() async => [];
}

// Exercise the real importer (including production catalog validation) while
// allowing its temporary Hive I/O to run outside the widget-test clock.
class _IoImporter extends WorkoutTemplateImportService {
  final WidgetTester tester;
  Future<WorkoutTemplateImportResult?>? pending;
  _IoImporter(
    StandardTemplateFixture f,
    StandardWorkoutTemplateRepository templates,
    this.tester,
  ) : super(
        programs: f.programs,
        templates: f.days,
        currentUserId: () => f.uid,
        catalog: templates.catalog,
      );
  @override
  Future<WorkoutTemplateImportResult> save(WorkoutProgramDraft draft) async {
    pending = tester.runAsync(() => super.save(draft));
    return (await pending)!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StandardTemplateFixture f;
  late StandardWorkoutTemplateRepository templates;
  setUp(() async {
    f = StandardTemplateFixture();
    await f.open();
    templates = standardTemplateCatalog();
    await templates.loadTemplates();
  });
  tearDown(() async => f.close());

  for (final language in ['en', 'ar']) {
    for (final split
        in StandardWorkoutTemplateRepository.expectedDayCounts.entries) {
      for (final variant in split.value.entries) {
        testWidgets(
          '$language selects and saves ${variant.key} without legacy warnings',
          (tester) async {
            final importer = _IoImporter(f, templates, tester);
            final custom = _Custom(f);
            final exercises = CombinedExerciseLibraryCatalog(
              builtInCatalog: templates.catalog,
              customExercises: custom,
            );
            WorkoutTemplateImportResult? saved;
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(language),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      key: const ValueKey('open'),
                      child: const Text('Open'),
                      onPressed: () async {
                        saved =
                            await Navigator.push<WorkoutTemplateImportResult>(
                              context,
                              MaterialPageRoute<WorkoutTemplateImportResult>(
                                builder: (_) => StandardWorkoutTemplatesScreen(
                                  templates: templates,
                                  importer: importer,
                                  exercises: exercises,
                                  customExercises: custom,
                                ),
                              ),
                            );
                      },
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.byKey(const ValueKey('open')));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.byKey(ValueKey('split-${split.key}')),
              300,
              scrollable: find.byType(Scrollable).first,
            );
            await Scrollable.ensureVisible(
              tester.element(find.byKey(ValueKey('split-${split.key}'))),
              alignment: 0.3,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(ValueKey('split-${split.key}')));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.byKey(ValueKey('variant-${variant.key}')),
              150,
              scrollable: find.byType(Scrollable).first,
            );
            await Scrollable.ensureVisible(
              tester.element(find.byKey(ValueKey('variant-${variant.key}'))),
              alignment: 0.5,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(ValueKey('variant-${variant.key}')));
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('use-workout-template')),
            );
            await tester.pumpAndSettle();
            final context = tester.element(
              find.byKey(const ValueKey('save-template-copy')),
            );
            final warning = AppLocalizations.of(
              context,
            )!.repdbResolveBeforeSave;
            expect(
              Directionality.of(context),
              language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            );
            await tester.tap(find.byKey(const ValueKey('save-template-copy')));
            expect(importer.pending, isNotNull);
            await importer.pending;
            await tester.pumpAndSettle();
            expect(saved, isNotNull);
            expect(find.text(warning), findsNothing);
            expect(find.byType(SnackBar), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.runAsync(() async {
              final days = (await f.days.getUserBox()).values
                  .where((d) => d.programId == saved!.program.id)
                  .toList();
              expect(days, hasLength(variant.value));
              for (final day in days) {
                for (final assignment in day.exerciseAssignments) {
                  expect(assignment.exerciseId, startsWith('repdb:'));
                }
              }
            });
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }
}
