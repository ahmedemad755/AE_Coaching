import 'dart:io';
import 'dart:ui' as ui;

import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/views/widgets/home_dashboard.dart';
import 'package:ae_coaching/features/views/widgets/home_dashboard_cards.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program_draft.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/repositories/combined_exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/standard_workout_template_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_cascade_deletion_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_import_service.dart';
import 'package:ae_coaching/features/workout/domain/services/home_workout_overview_service.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/home_workout_overview_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/active_workout_session_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/standard_workout_templates_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_program_details_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../workout/support/standard_template_fixtures.dart';

class _NoDeletion implements WorkoutCascadeDeletionService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedSets implements SessionExerciseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Programs extends WorkoutProgramCubit {
  _Programs(StandardTemplateFixture f)
    : super(repository: f.programs, deletionService: _NoDeletion());
  int refreshes = 0;
  @override
  Future<void> refreshPrograms() async {
    refreshes++;
    await super.refreshPrograms();
  }
}

class _Overview extends HomeWorkoutOverviewCubit {
  _Overview(StandardTemplateFixture f, WorkoutSessionRepository sessions)
    : super(
        programRepository: f.programs,
        templateRepository: f.days,
        sessionRepository: sessions,
        setRepository: _UnusedSets(),
      );
  HomeWorkoutOverview next = HomeWorkoutOverview.empty;
  int loads = 0;
  @override
  Future<void> loadOverview() async {
    loads++;
    emit(HomeWorkoutOverviewLoaded(next));
  }

  void show(HomeWorkoutOverviewState state) => emit(state);
}

class _Custom extends CustomExerciseRepository {
  _Custom(StandardTemplateFixture f)
    : super(storageManager: f.storage, uidOverride: () => f.uid);
  @override
  Future<List<CustomExercise>> getAllExercises() async => [];
}

class _Importer extends WorkoutTemplateImportService {
  _Importer(StandardTemplateFixture f)
    : super(
        programs: f.programs,
        templates: f.days,
        currentUserId: () => f.uid,
      );
  int saves = 0;
  @override
  Future<WorkoutTemplateImportResult> save(WorkoutProgramDraft draft) async {
    saves++;
    // Persistence is covered by the real importer regression suite. This
    // fixture verifies the real three-route result contract without disk I/O.
    return WorkoutTemplateImportResult(
      WorkoutProgram(
        id: draft.programId,
        name: draft.name,
        createdAt: DateTime(2026),
      ),
      cloudSyncIncomplete: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'Roboto': 'C:/Windows/Fonts/arial.ttf',
      'MaterialIcons':
          'C:/flutter/src/flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(font.value);
      if (file.existsSync()) {
        await (FontLoader(font.key)
              ..addFont(file.readAsBytes().then((b) => b.buffer.asByteData())))
            .load();
      }
    }
  });
  late StandardTemplateFixture f;
  late _Programs programs;
  late WorkoutSessionCubit sessions;
  late _Overview overview;
  late _Importer importer;
  late List<RouteSettings> destinations;
  int profiles = 0, settings = 0, analysis = 0;

  setUp(() async {
    await sl.reset();
    f = StandardTemplateFixture();
    await f.open();
    await f.programs.getUserBox();
    final repository = WorkoutSessionRepository(
      storageManager: f.storage,
      remoteDataSource: TemplateSessionRemote(),
      uidOverride: () => f.uid,
    );
    await repository.getUserBox();
    sessions = WorkoutSessionCubit(repository: repository);
    programs = _Programs(f);
    await programs.loadPrograms();
    overview = _Overview(f, repository);
    await overview.loadOverview();
    importer = _Importer(f);
    final catalog = standardTemplateCatalog();
    await catalog.loadTemplates();
    final custom = _Custom(f);
    sl.registerSingleton<StandardWorkoutTemplateRepository>(catalog);
    sl.registerSingleton<WorkoutTemplateImportService>(importer);
    sl.registerSingleton<CustomExerciseRepository>(custom);
    sl.registerSingleton<CombinedExerciseLibraryCatalog>(
      CombinedExerciseLibraryCatalog(
        builtInCatalog: catalog.catalog,
        customExercises: custom,
      ),
    );
    destinations = [];
    profiles = settings = analysis = 0;
  });
  tearDown(() async {
    await programs.close();
    await sessions.close();
    await overview.close();
    await sl.reset();
    await f.close();
  });

  Widget app({
    String language = 'en',
    ThemeMode theme = ThemeMode.dark,
    double scale = 1,
    String? name,
  }) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: theme,
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: RepaintBoundary(
        key: const ValueKey('dashboard-capture'),
        child: child,
      ),
    ),
    onGenerateRoute: (route) {
      destinations.add(route);
      if (route.name == AppNavigator.workoutTemplates) {
        return AppRouter.onGenerateRoute(route);
      }
      return MaterialPageRoute<void>(
        settings: route,
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(route.name!)),
          body: const Text('Destination'),
        ),
      );
    },
    home: MultiBlocProvider(
      providers: [
        BlocProvider<WorkoutProgramCubit>.value(value: programs),
        BlocProvider<WorkoutSessionCubit>.value(value: sessions),
        BlocProvider<HomeWorkoutOverviewCubit>.value(value: overview),
      ],
      child: HomeDashboard(
        name: name ?? (language == 'ar' ? 'أحمد عماد' : 'Ahmed Emad'),
        onProfile: () => profiles++,
        onSettings: () => settings++,
        onProgressAnalysis: () => analysis++,
        currentUserId: () => f.uid,
        volume: const Text('Today volume fixture'),
      ),
    ),
  );
  void phone(WidgetTester tester, [double width = 320]) {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> visible(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      140,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('dashboard-capture')),
    );
    await tester.runAsync(() async {
      final shot = await boundary.toImage(pixelRatio: 1);
      final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/home-dashboard-previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      shot.dispose();
    });
  }

  Future<WorkoutProgram> active(
    WidgetTester tester, {
    String name = 'Strength plan',
  }) async {
    final program = (await tester.runAsync(
      () => f.programs.createProgram(name: name, makeActive: true),
    ))!;
    await programs.refreshPrograms();
    overview.next = HomeWorkoutOverview(
      activeSession: null,
      activeProgram: HomeActiveProgramSummary(
        program: program,
        sessionsCompletedThisWeek: 2,
      ),
      recentSessions: [],
    );
    await overview.loadOverview();
    return program;
  }

  for (final language in ['en', 'ar']) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '$language $theme dashboard uses real program, grid and one bar',
        (tester) async {
          phone(tester, 390);
          final program = await active(
            tester,
            name: language == 'ar'
                ? 'برنامج القوة الأسبوعي'
                : 'Weekly strength plan',
          );
          await tester.pumpWidget(app(language: language, theme: theme));
          await tester.pumpAndSettle();
          expect(find.byType(HomeNavigationCard), findsNWidgets(4));
          final left = find.byKey(const ValueKey('home-programs'));
          final right = find.byKey(const ValueKey('home-templates'));
          expect(tester.getTopLeft(left).dy, tester.getTopLeft(right).dy);
          expect(tester.getSize(left).height, tester.getSize(right).height);
          expect(
            tester
                .getSize(find.byKey(const ValueKey('home-start-workout')))
                .height,
            tester.getSize(left).height,
          );
          expect(tester.widget<HomeNavigationCard>(right).emphasized, isTrue);
          expect(
            Directionality.of(tester.element(left)),
            language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(
            tester.getTopLeft(left).dx,
            language == 'ar'
                ? greaterThan(tester.getTopLeft(right).dx)
                : lessThan(tester.getTopLeft(right).dx),
          );
          expect(find.byKey(const ValueKey('home-nav-0')), findsOneWidget);
          expect(find.byIcon(Icons.notifications_outlined), findsNothing);
          await capture(tester, '$language-${theme.name}-top');
          await visible(
            tester,
            find.byKey(ValueKey('home-active-program-${program.id}')),
          );
          expect(find.text(program.name), findsOneWidget);
          final card = tester.widget<ActiveProgramCard>(
            find.byType(ActiveProgramCard),
          );
          expect(card.sessionsCompletedThisWeek, 2);
          await visible(
            tester,
            find.byKey(const ValueKey('home-body-metrics')),
          );
          await capture(tester, '$language-${theme.name}-actions');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
    testWidgets(
      '$language 320dp and 200% text stays readable with a long name',
      (tester) async {
        phone(tester);
        await active(
          tester,
          name: language == 'ar'
              ? 'برنامج القوة وبناء العضلات لأيام التدريب الأسبوعية'
              : 'Weekly strength and muscle building training program',
        );
        await tester.pumpWidget(
          app(
            language: language,
            scale: 2,
            name: language == 'ar'
                ? 'أحمد عماد عبد الرحمن محمد السيد الطويل'
                : 'Ahmed Emad Abdelrahman Mohamed El Sayed',
          ),
        );
        await tester.pumpAndSettle();
        final first = find.byKey(const ValueKey('home-programs'));
        final next = find.byKey(const ValueKey('home-templates'));
        expect(
          tester.getTopLeft(next).dy,
          greaterThan(tester.getBottomLeft(first).dy),
        );
        await visible(tester, find.byKey(const ValueKey('home-body-metrics')));
        await visible(tester, find.text('Today volume fixture'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language active and completed session cards fit at 200% text',
      (tester) async {
        phone(tester);
        final program = await active(tester);
        final session = WorkoutSession(
          id: 'large-text-session',
          programId: program.id,
          workoutTemplateId: 'day',
          workoutNameSnapshot: language == 'ar'
              ? 'تمرين الجزء العلوي من الجسم'
              : 'Upper body strength session',
          date: DateTime(2026, 11, 2),
          startedAt: DateTime.now(),
          status: 'inProgress',
        );
        final completed = session.copyWith(
          status: 'completed',
          completedAt: DateTime.now(),
        );
        overview.next = HomeWorkoutOverview(
          activeSession: session,
          activeProgram: overview.next.activeProgram,
          recentSessions: [
            HomeSessionSummary(
              session: completed,
              template: null,
              exerciseCount: 2,
              setCount: 6,
              exerciseNames: ['Bench press', 'Barbell row'],
            ),
          ],
        );
        await overview.loadOverview();
        await tester.pumpWidget(app(language: language, scale: 2));
        await tester.pumpAndSettle();
        await visible(
          tester,
          find.byKey(ValueKey('home-active-session-${session.id}')),
        );
        await visible(
          tester,
          find.byKey(ValueKey('home-recent-session-${session.id}')),
        );
        await visible(tester, find.text('Today volume fixture'));
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'empty program state opens the actual typed template route; cancellation does not refresh',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(ActiveProgramCard), findsNothing);
      final explore = find.descendant(
        of: find.byWidgetPredicate((widget) => widget is FilledButton),
        matching: find.text('Workout Templates'),
      );
      await visible(tester, explore);
      final before = programs.refreshes;
      await tester.tap(explore);
      await tester.pumpAndSettle();
      final route = ModalRoute.of<WorkoutTemplateImportResult>(
        tester.element(find.byType(StandardWorkoutTemplatesScreen)),
      );
      expect(route, isA<MaterialPageRoute<WorkoutTemplateImportResult>>());
      await back(tester);
      expect(programs.refreshes, before);
      expect(importer.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home import saves through browser preview and draft, refreshes and keeps activation unchanged',
    (tester) async {
      phone(tester, 390);
      final existing = await active(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final before = programs.refreshes;
      await tester.tap(find.byKey(const ValueKey('home-templates')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('split-push_pull_legs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('variant-ppl_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('use-workout-template')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-template-copy')));
      await tester.pumpAndSettle();
      expect(importer.saves, 1);
      expect(programs.refreshes, before + 1);
      expect(
        f.programs.getActiveProgram(await f.programs.getUserBox())!.id,
        existing.id,
      );
      expect(find.text('Program saved to My Programs.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'import result from another account never refreshes or shows a success notice',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final before = programs.refreshes;
      await tester.tap(find.byKey(const ValueKey('home-templates')));
      await tester.pumpAndSettle();
      final context = tester.element(
        find.byType(StandardWorkoutTemplatesScreen),
      );
      f.uid = 'Owner-B';
      Navigator.pop<WorkoutTemplateImportResult>(
        context,
        WorkoutTemplateImportResult(
          WorkoutProgram(
            id: 'old-owner-copy',
            name: 'Old owner',
            createdAt: DateTime(2026),
          ),
          cloudSyncIncomplete: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(programs.refreshes, before);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all primary, quick and bottom navigation actions use existing destinations',
    (tester) async {
      phone(tester, 390);
      final program = await active(tester);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (final entry in {
        'home-programs': AppNavigator.workoutPrograms,
        'home-start-workout': AppNavigator.workoutProgramDetails,
        'home-progress': AppNavigator.myProgress,
        'home-log-workout': AppNavigator.workoutProgramDetails,
        'home-body-metrics': AppNavigator.measurements,
        'home-history': AppNavigator.myProgress,
        'home-nav-1': AppNavigator.workoutPrograms,
        'home-nav-2': AppNavigator.myProgress,
      }.entries) {
        final target = find.byKey(ValueKey(entry.key));
        if (!entry.key.startsWith('home-nav-')) await visible(tester, target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(destinations.last.name, entry.value);
        if (entry.value == AppNavigator.workoutProgramDetails) {
          expect(
            (destinations.last.arguments as WorkoutProgramDetailsArgs)
                .program
                .id,
            program.id,
          );
        }
        await back(tester);
      }
      await tester.tap(find.byKey(const ValueKey('home-nav-3')));
      expect(profiles, 1);
      await tester.tap(find.byKey(const ValueKey('home-nav-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('App settings'));
      expect(settings, 1);
      await visible(
        tester,
        find.byKey(const ValueKey('home-progress-analysis')),
      );
      await tester.tap(find.byKey(const ValueKey('home-progress-analysis')));
      expect(analysis, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Start and Log Workout resume the existing session without changing its data',
    (tester) async {
      phone(tester, 390);
      final program = await active(tester);
      final session = WorkoutSession(
        id: 'in-progress',
        programId: program.id,
        workoutTemplateId: 'day-id',
        workoutNameSnapshot: 'Upper body',
        date: DateTime.now(),
        startedAt: DateTime.now(),
        status: 'inProgress',
      );
      await tester.runAsync(
        () async =>
            (await sessions.repository.getUserBox()).put(session.id, session),
      );
      overview.next = HomeWorkoutOverview(
        activeSession: session,
        activeProgram: overview.next.activeProgram,
        recentSessions: [],
      );
      await overview.loadOverview();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (final key in ['home-start-workout', 'home-log-workout']) {
        final target = find.byKey(ValueKey(key));
        await visible(tester, target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(destinations.last.name, AppNavigator.activeWorkoutSession);
        expect(
          (destinations.last.arguments as ActiveWorkoutSessionArgs).session.id,
          session.id,
        );
        await back(tester);
      }
      expect((await sessions.repository.getUserBox()).length, 1);
      expect(session.status, 'inProgress');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no active program starts at Programs, and overview loading/errors keep navigation available',
    (tester) async {
      phone(tester, 390);
      overview.show(const HomeWorkoutOverviewLoading());
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.byKey(const ValueKey('home-templates')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-start-workout')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(destinations.last.name, AppNavigator.workoutPrograms);
      await back(tester);
      overview.show(const HomeWorkoutOverviewError('Offline fixture'));
      await tester.pumpAndSettle();
      await visible(tester, find.text('Offline fixture'));
      final before = overview.loads;
      await visible(tester, find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(overview.loads, before + 1);
      expect(tester.takeException(), isNull);
    },
  );
}
