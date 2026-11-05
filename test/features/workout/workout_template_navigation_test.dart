import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program_draft.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/standard_workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_cascade_deletion_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/standard_workout_templates_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_program_draft_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_programs_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/standard_template_fixtures.dart';

class _NoDeletion implements WorkoutCascadeDeletionService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Programs extends WorkoutProgramCubit {
  int refreshCount = 0;
  _Programs(WorkoutProgramRepository repository)
    : super(repository: repository, deletionService: _NoDeletion());
  void showFixture() => emit(
    const WorkoutProgramError(
      operation: WorkoutProgramOperation.load,
      message: 'Navigation fixture',
    ),
  );
  @override
  Future<void> loadPrograms() async => showFixture();
  @override
  Future<void> refreshPrograms() async {
    refreshCount++;
    showFixture();
  }
}

class _Sessions extends WorkoutSessionCubit {
  _Sessions()
    : super(
        repository: WorkoutSessionRepository(
          storageManager: UserStorageManager(),
          remoteDataSource: TemplateSessionRemote(),
          uidOverride: () => 'navigation-owner',
        ),
      );
  @override
  Future<void> checkActiveSession() async => emit(const WorkoutSessionNone());
}

class _Custom extends CustomExerciseRepository {
  _Custom()
    : super(
        storageManager: UserStorageManager(),
        uidOverride: () => 'navigation-owner',
      );
  @override
  Future<List<CustomExercise>> getAllExercises() async => [];
}

class _Importer extends WorkoutTemplateImportService {
  final WorkoutTemplateImportResult result = WorkoutTemplateImportResult(
    WorkoutProgram(
      id: 'navigation-copy',
      name: 'Navigation Copy',
      createdAt: DateTime(2026),
    ),
    cloudSyncIncomplete: false,
  );
  int saves = 0;
  _Importer(StandardTemplateFixture f)
    : super(
        programs: f.programs,
        templates: f.days,
        currentUserId: () => 'navigation-owner',
      );
  @override
  Future<WorkoutTemplateImportResult> save(WorkoutProgramDraft draft) async {
    saves++;
    return result; // No Hive or remote writes in navigation tests.
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StandardWorkoutTemplateRepository templates;
  late _Importer importer;
  late _Programs programs;
  late _Sessions sessions;
  setUp(() async {
    await sl.reset();
    templates = standardTemplateCatalog();
    await templates.loadTemplates();
    final f =
        StandardTemplateFixture(); // Only construct repositories; do not open Hive.
    importer = _Importer(f);
    programs = _Programs(f.programs);
    sessions = _Sessions();
    final custom = _Custom();
    sl.registerSingleton<StandardWorkoutTemplateRepository>(templates);
    sl.registerSingleton<WorkoutTemplateImportService>(importer);
    sl.registerSingleton<CustomExerciseRepository>(custom);
    sl.registerSingleton<CombinedExerciseLibraryCatalog>(
      CombinedExerciseLibraryCatalog(
        builtInCatalog: templates.catalog,
        customExercises: custom,
      ),
    );
  });
  tearDown(() async {
    await programs.close();
    await sessions.close();
    await sl.reset();
  });

  Widget app() => MaterialApp(
    theme: AppTheme.dark,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    onGenerateRoute: AppRouter.onGenerateRoute,
    home: MultiBlocProvider(
      providers: [
        BlocProvider<WorkoutProgramCubit>.value(value: programs),
        BlocProvider<WorkoutSessionCubit>.value(value: sessions),
      ],
      child: const WorkoutProgramsScreen(),
    ),
  );
  Future<void> openLibrary(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('browse-workout-templates')));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(StandardWorkoutTemplatesScreen));
    final route = ModalRoute.of<WorkoutTemplateImportResult>(context)!;
    expect(route, isA<MaterialPageRoute<WorkoutTemplateImportResult>>());
    expect(route.settings.name, AppNavigator.workoutTemplates);
  }

  Future<void> openPreview(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('split-push_pull_legs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('variant-ppl_3')));
    await tester.pumpAndSettle();
    expect(
      ModalRoute.of<WorkoutTemplateImportResult>(
        tester.element(find.byType(StandardWorkoutTemplatePreviewScreen)),
      ),
      isA<MaterialPageRoute<WorkoutTemplateImportResult>>(),
    );
  }

  Future<void> openDraft(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('use-workout-template')));
    await tester.pumpAndSettle();
    expect(
      ModalRoute.of<WorkoutTemplateImportResult>(
        tester.element(find.byType(WorkoutProgramDraftScreen)),
      ),
      isA<MaterialPageRoute<WorkoutTemplateImportResult>>(),
    );
  }

  testWidgets(
    'old untyped named factory reproduces the exact runtime TypeError',
    (tester) async {
      Object? caught;
      await tester.pumpWidget(
        MaterialApp(
          // Deliberately reproduce the former faulty factory in this fixture only.
          onGenerateRoute: (_) => MaterialPageRoute<dynamic>(
            builder: (_) => const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                try {
                  await Navigator.pushNamed<WorkoutTemplateImportResult>(
                    context,
                    AppNavigator.workoutTemplates,
                  );
                } catch (error) {
                  caught = error;
                }
              },
              child: const Text('Open broken route'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open broken route'));
      await tester.pumpAndSettle();
      expect(caught, isA<TypeError>());
      expect(caught.toString(), contains('MaterialPageRoute<dynamic>'));
      expect(
        caught.toString(),
        contains('Route<WorkoutTemplateImportResult?>'),
      );
    },
  );

  testWidgets(
    'real My Programs named route opens, preview/draft save returns one typed result through all routes',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await openLibrary(tester);
      await openPreview(tester);
      await openDraft(tester);
      await tester.tap(find.byKey(const ValueKey('save-template-copy')));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutProgramsScreen), findsOneWidget);
      expect(find.byType(WorkoutProgramDraftScreen), findsNothing);
      expect(importer.saves, 1);
      expect(programs.refreshCount, 1);
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(WorkoutProgramsScreen)),
          )!.standardTemplateSaved,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'named browser cancellation and preview back return null without saving or refreshing',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await openLibrary(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(programs.refreshCount, 0);
      await openLibrary(tester);
      await openPreview(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(StandardWorkoutTemplatesScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(programs.refreshCount, 0);
      expect(importer.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discard draft returns null to preview; dismissing confirmation keeps typed route',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await openLibrary(tester);
      await openPreview(tester);
      await openDraft(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkoutProgramDraftScreen)),
      )!;
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(WorkoutProgramDraftScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.discardProgramDraft));
      await tester.pumpAndSettle();
      expect(find.byType(StandardWorkoutTemplatePreviewScreen), findsOneWidget);
      expect(programs.refreshCount, 0);
      expect(importer.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
