import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ae_coaching/core/di/sl_instance.dart';
import 'package:ae_coaching/core/bootstrap/startup_destination.dart';
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

  /// Stands in for the Hive box change notifications of the boxes the
  /// overview reads; tests add an event to simulate a data change.
  final changes = StreamController<Object?>.broadcast();

  @override
  Future<List<Stream<Object?>>> sourceChanges() async => [changes.stream];

  @override
  Future<void> loadOverview() async {
    loads++;
    emit(HomeWorkoutOverviewLoaded(next));
  }

  @override
  Future<void> close() async {
    await changes.close();
    return super.close();
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

/// How often each persistent-tab probe was created and disposed.
final _probeInits = <String, int>{};
final _probeDisposes = <String, int>{};

/// A tab body with its own State, local UI state (a tap counter), a
/// focusable control, semantics and a scrollable list, used to prove the
/// tab survives switching instead of being rebuilt.
class _TabProbe extends StatefulWidget {
  const _TabProbe(this.name);
  final String name;
  @override
  State<_TabProbe> createState() => _TabProbeState();
}

class _TabProbeState extends State<_TabProbe> {
  int taps = 0;
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _probeInits.update(widget.name, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  void dispose() {
    _probeDisposes.update(widget.name, (n) => n + 1, ifAbsent: () => 1);
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Text('${widget.name} taps $taps'),
      TextButton(
        key: ValueKey('${widget.name}-tap'),
        focusNode: focusNode,
        onPressed: () => setState(() => taps++),
        child: Semantics(
          label: '${widget.name} action',
          child: const Text('+'),
        ),
      ),
      for (var i = 0; i < 60; i++)
        SizedBox(height: 48, child: Text('${widget.name} row $i')),
    ],
  );
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
    _probeInits.clear();
    _probeDisposes.clear();
    // The route guard reads Firebase Auth; tests run as a verified user.
    final originalAuthSnapshot = AppRouter.readAuthSnapshot;
    AppRouter.readAuthSnapshot = () => const StartupAuthSnapshot(
      firebaseUid: 'test-user',
      firebaseEmail: 'test@example.com',
      firebaseEmailVerified: true,
    );
    addTearDown(() => AppRouter.readAuthSnapshot = originalAuthSnapshot);
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
    bool tabs = false,
    WidgetBuilder? programsTab,
    WidgetBuilder? progressTab,
    WidgetBuilder? moreTab,
    String? userId,
    bool reduceMotion = false,
  }) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: theme,
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        disableAnimations: reduceMotion,
      ),
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
        currentUserId: () => userId ?? f.uid,
        volume: const Text('Today volume fixture'),
        programsTab: tabs
            ? programsTab ?? (_) => const Text('Programs tab fixture')
            : null,
        progressTab: tabs
            ? progressTab ?? (_) => const Text('Progress tab fixture')
            : null,
        moreTab: tabs ? moreTab ?? (_) => const Text('More tab fixture') : null,
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
    'bottom tabs animate in place and keep the bar on every main page',
    (tester) async {
      phone(tester, 390);
      await tester.pumpWidget(app(tabs: true));
      await tester.pumpAndSettle();
      final routes = destinations.length;
      for (final entry in {
        1: 'Programs tab fixture',
        2: 'Progress tab fixture',
        3: 'More tab fixture',
      }.entries) {
        await tester.tap(find.byKey(ValueKey('home-nav-${entry.key}')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final fade = tester.widget<FadeTransition>(
          find
              .ancestor(
                of: find.text(entry.value),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        expect(fade.opacity.value, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.byKey(const ValueKey('home-nav-0')), findsOneWidget);
      }
      // System back on a tab returns to Home instead of leaving the app.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('More tab fixture'), findsNothing);
      expect(find.byKey(const ValueKey('home-programs')), findsOneWidget);
      expect(destinations.length, routes);
      expect(profiles, 0);
      expect(tester.takeException(), isNull);
    },
  );

  group('persistent tabs', () {
    Widget probes({String? userId}) => app(
      tabs: true,
      userId: userId,
      programsTab: (_) => const _TabProbe('programs'),
      progressTab: (_) => const _TabProbe('progress'),
      moreTab: (_) => const _TabProbe('more'),
    );
    Future<void> go(WidgetTester tester, int index) async {
      await tester.tap(find.byKey(ValueKey('home-nav-$index')));
      await tester.pumpAndSettle();
    }

    Finder probe(String name) => find.byWidgetPredicate(
      (w) => w is _TabProbe && w.name == name,
      skipOffstage: false,
    );
    double scrollOffset(WidgetTester tester, String name) => tester
        .state<ScrollableState>(
          find
              .descendant(of: probe(name), matching: find.byType(Scrollable))
              .first,
        )
        .position
        .pixels;

    testWidgets(
      'tabs build lazily, then each initializes once and is never disposed '
      'by repeated switching',
      (tester) async {
        phone(tester, 390);
        await tester.pumpWidget(probes());
        await tester.pumpAndSettle();
        expect(_probeInits, isEmpty, reason: 'nothing built before opened');

        await go(tester, 1);
        expect(_probeInits, {'programs': 1});

        for (var round = 0; round < 3; round++) {
          for (final index in [2, 3, 0, 1, 3, 2, 0, 1]) {
            await go(tester, index);
          }
        }
        expect(_probeInits, {'programs': 1, 'progress': 1, 'more': 1});
        expect(_probeDisposes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'local UI state and scroll position survive switching and Android Back',
      (tester) async {
        phone(tester, 390);
        await tester.pumpWidget(probes());
        await tester.pumpAndSettle();
        await go(tester, 2);
        await tester.tap(find.byKey(const ValueKey('progress-tap')));
        await tester.tap(find.byKey(const ValueKey('progress-tap')));
        await tester.pump();
        await tester.drag(find.text('progress row 3'), const Offset(0, -700));
        await tester.pumpAndSettle();
        final scrolled = scrollOffset(tester, 'progress');
        expect(scrolled, greaterThan(400));

        await go(tester, 3);
        // System Back on a tab returns to Home, keeping the tab alive.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home-programs')), findsOneWidget);
        await go(tester, 2);

        expect(scrollOffset(tester, 'progress'), scrolled);
        await tester.drag(find.byType(Scrollable).last, const Offset(0, 2000));
        await tester.pumpAndSettle();
        expect(find.text('progress taps 2'), findsOneWidget);
        expect(_probeInits['progress'], 1);
      },
    );

    testWidgets(
      'hidden tabs take no pointer input, focus or semantics, and pause '
      'their tickers',
      (tester) async {
        phone(tester, 390);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(probes());
        await tester.pumpAndSettle();
        await go(tester, 1);
        await go(tester, 2);

        final hidden = tester.state<_TabProbeState>(probe('programs'));
        expect(find.text('programs taps 0'), findsNothing); // offstage
        expect(TickerMode.of(hidden.context), isFalse);
        expect(
          TickerMode.of(
            tester.state<_TabProbeState>(probe('progress')).context,
          ),
          isTrue,
        );

        hidden.focusNode.requestFocus();
        await tester.pump();
        expect(hidden.focusNode.hasFocus, isFalse);

        // The label is merged into its button's node ("<name> action\n+").
        expect(find.bySemanticsLabel(RegExp('programs action')), findsNothing);
        expect(
          find.bySemanticsLabel(RegExp('progress action')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('programs-tap'), skipOffstage: false),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(hidden.taps, 0);
        semantics.dispose();
      },
    );

    testWidgets('switching tabs alone loads no data', (tester) async {
      phone(tester, 390);
      await tester.pumpWidget(probes());
      await tester.pumpAndSettle();
      await go(tester, 1);
      final loads = overview.loads;
      final refreshes = programs.refreshes;

      for (var round = 0; round < 5; round++) {
        for (final index in [0, 1, 2, 3, 0, 2]) {
          await go(tester, index);
        }
      }
      expect(overview.loads, loads);
      expect(programs.refreshes, refreshes);
    });

    testWidgets(
      'a data change refreshes Home once: now while visible, later when hidden',
      (tester) async {
        phone(tester, 390);
        await tester.pumpWidget(probes());
        await tester.pumpAndSettle();
        final base = overview.loads;

        overview.changes.add(null);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(overview.loads, base + 1, reason: 'visible: refresh now');

        await go(tester, 1);
        for (var i = 0; i < 5; i++) {
          overview.changes.add(null);
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(overview.loads, base + 1, reason: 'hidden: just remembered');

        await go(tester, 0);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(overview.loads, base + 2, reason: 'one catch-up on return');

        await go(tester, 1);
        await go(tester, 0);
        await tester.pump(const Duration(milliseconds: 200));
        expect(overview.loads, base + 2, reason: 'no new change, no reload');
      },
    );

    testWidgets(
      'changes made on a screen pushed over Home refresh it once on return',
      (tester) async {
        phone(tester, 390);
        await tester.pumpWidget(probes());
        await tester.pumpAndSettle();
        final base = overview.loads;
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Active workout')),
              ),
            );
        await tester.pumpAndSettle();
        for (var i = 0; i < 4; i++) {
          overview.changes.add(null);
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(overview.loads, base);

        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(overview.loads, base + 1);
      },
    );

    testWidgets(
      'a different signed-in user gets fresh tabs; nothing of the previous '
      "user's tabs survives",
      (tester) async {
        phone(tester, 390);
        await tester.pumpWidget(probes(userId: 'user-a'));
        await tester.pumpAndSettle();
        await go(tester, 1);
        await tester.tap(find.byKey(const ValueKey('programs-tap')));
        await tester.pump();
        expect(find.text('programs taps 1'), findsOneWidget);
        await go(tester, 2);
        await go(tester, 3);
        final loads = overview.loads;
        final refreshes = programs.refreshes;

        await tester.pumpWidget(probes(userId: 'user-b'));
        await tester.pumpAndSettle();

        expect(_probeDisposes, {'programs': 1, 'progress': 1, 'more': 1});
        expect(find.byType(_TabProbe, skipOffstage: false), findsNothing);
        expect(find.byKey(const ValueKey('home-programs')), findsOneWidget);
        // Home's data is replaced for the new user, once.
        expect(overview.loads, loads + 1);
        expect(programs.refreshes, refreshes + 1);

        await go(tester, 1);
        expect(find.text('programs taps 0'), findsOneWidget);
        expect(_probeInits['programs'], 2);
      },
    );

    testWidgets('leaving Home (logout) disposes every tab', (tester) async {
      phone(tester, 390);
      await tester.pumpWidget(probes());
      await tester.pumpAndSettle();
      for (final index in [1, 2, 3]) {
        await go(tester, index);
      }
      await tester.pumpWidget(const MaterialApp(home: Text('Login')));
      expect(_probeDisposes, {'programs': 1, 'progress': 1, 'more': 1});
    });

    testWidgets('the fade + slide still plays when returning to a kept-alive '
        'tab', (tester) async {
      phone(tester, 390);
      await tester.pumpWidget(probes());
      await tester.pumpAndSettle();
      await go(tester, 1);
      await go(tester, 2);

      await tester.tap(find.byKey(const ValueKey('home-nav-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('programs taps 0'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      final slide = tester.widget<SlideTransition>(
        find
            .ancestor(
              of: find.text('programs taps 0'),
              matching: find.byType(SlideTransition),
            )
            .first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      expect(slide.position.value.dx, lessThan(-0.01));
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
      expect(_probeInits['programs'], 1);
    });
  });

  group('tab transition animation', () {
    FadeTransition fadeOf(WidgetTester tester, String text) =>
        tester.widget<FadeTransition>(
          find
              .ancestor(
                of: find.text(text),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
    SlideTransition slideOf(WidgetTester tester, String text) =>
        tester.widget<SlideTransition>(
          find
              .ancestor(
                of: find.text(text),
                matching: find.byType(SlideTransition),
              )
              .first,
        );

    testWidgets(
      'a tab change runs a visible ~300ms easeInOutCubic fade + slide',
      (tester) async {
        phone(tester, 390);
        await tester.pumpWidget(app(tabs: true));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('home-nav-2')));
        await tester.pump(); // tab change frame: animation restarts at 0
        await tester.pump(const Duration(milliseconds: 150));
        final midOpacity = fadeOf(tester, 'Progress tab fixture').opacity.value;
        final midOffset = slideOf(
          tester,
          'Progress tab fixture',
        ).position.value;
        // Halfway through easeInOutCubic is exactly 0.5.
        expect(midOpacity, closeTo(Curves.easeInOutCubic.transform(0.5), 0.02));
        // Moving to a tab on the right slides in from that side, visibly.
        expect(midOffset.dx, greaterThan(0.01));

        await tester.pump(const Duration(milliseconds: 150));
        expect(fadeOf(tester, 'Progress tab fixture').opacity.value, 1);
        expect(
          slideOf(tester, 'Progress tab fixture').position.value,
          Offset.zero,
        );
      },
    );

    testWidgets('going back to a tab on the left slides the other way, and '
        'RTL mirrors the slide', (tester) async {
      phone(tester, 390);
      await tester.pumpWidget(app(tabs: true, language: 'ar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-3')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-nav-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final slide = slideOf(tester, 'Programs tab fixture');
      expect(slide.position.value.dx, lessThan(-0.01));
      expect(slide.textDirection, TextDirection.rtl);
    });

    testWidgets('reduced motion switches tabs instantly', (tester) async {
      phone(tester, 390);
      await tester.pumpWidget(app(tabs: true, reduceMotion: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-nav-1')));
      await tester.pump();
      expect(fadeOf(tester, 'Programs tab fixture').opacity.value, 1);
      expect(
        slideOf(tester, 'Programs tab fixture').position.value,
        Offset.zero,
      );
    });

    testWidgets('rapid repeated tab switching settles on the last tab only', (
      tester,
    ) async {
      phone(tester, 390);
      await tester.pumpWidget(app(tabs: true));
      await tester.pumpAndSettle();

      for (final index in [1, 2, 3, 2, 1, 3, 1]) {
        await tester.tap(find.byKey(ValueKey('home-nav-$index')));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(find.text('Programs tab fixture'), findsOneWidget);
      expect(find.text('Progress tab fixture'), findsNothing);
      expect(find.text('More tab fixture'), findsNothing);
      expect(fadeOf(tester, 'Programs tab fixture').opacity.value, 1);
      expect(find.byKey(const ValueKey('home-nav-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tab keeps its scroll position across tab switches', (
      tester,
    ) async {
      phone(tester, 390);
      await tester.pumpWidget(
        app(
          tabs: true,
          progressTab: (_) => ListView.builder(
            itemCount: 80,
            itemBuilder: (_, i) =>
                SizedBox(height: 56, child: Text('Progress row $i')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-2')));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Progress row 2'), const Offset(0, -900));
      await tester.pumpAndSettle();
      double offset() => tester
          .state<ScrollableState>(
            find
                .ancestor(
                  of: find.textContaining('Progress row').first,
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      final scrolled = offset();
      expect(scrolled, greaterThan(500));

      await tester.tap(find.byKey(const ValueKey('home-nav-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-2')));
      await tester.pumpAndSettle();

      expect(offset(), scrolled);
      expect(find.text('Progress row 0'), findsNothing);
    });
  });

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
