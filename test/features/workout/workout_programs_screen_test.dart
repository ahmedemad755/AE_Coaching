import 'dart:io';

import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_program_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_cascade_deletion_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_session_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_programs_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_program_details_screen.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/home_workout_plans_section.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/workout_template_layout.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeWorkoutProgramRemoteDataSource
    implements WorkoutProgramRemoteDataSource {
  @override
  Future<void> syncProgram(String id, WorkoutProgram program) async {}

  @override
  Future<void> deleteProgram(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemotePrograms() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

// Stage 9: this screen test never exercises cascade deletion — these
// three fakes exist only so WorkoutCascadeDeletionService's (Stage 3)
// required repositories can be constructed without touching real
// Firebase, exactly like _FakeWorkoutProgramRemoteDataSource above.
// Previously these repositories fell back to their real
// XxxRemoteDataSourceImpl() (each defaults to FirebaseFirestore.instance/
// FirebaseAuth.instance when no remoteDataSource is injected), which
// requires Firebase.initializeApp() — unavailable in this test
// environment, and the root cause of this file's 3 known failures.
class _FakeWorkoutTemplateRemoteDataSource
    implements WorkoutTemplateRemoteDataSource {
  @override
  Future<void> syncTemplate(String id, WorkoutTemplate template) async {}

  @override
  Future<void> deleteTemplate(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteTemplates() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

class _FakeWorkoutSessionRemoteDataSource
    implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSessions() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

class _FakeWorkoutRemoteDataSource implements WorkoutRemoteDataSource {
  @override
  Future<void> syncSet(String key, ExerciseSet set) async {}

  @override
  Future<void> deleteSet(String key) async {}

  @override
  Future<void> deleteMultipleSets(List<String> keys) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSets() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

Widget _wrap(
  WorkoutProgramCubit cubit,
  WorkoutSessionCubit sessionCubit, {
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cubit),
        BlocProvider.value(value: sessionCubit),
      ],
      child: const WorkoutProgramsScreen(),
    ),
  );
}

Widget _wrapHomePlans(
  WorkoutProgramCubit cubit, {
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: {
      AppNavigator.initial: (_) => BlocProvider.value(
        value: cubit,
        child: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: HomeWorkoutPlansSection(),
          ),
        ),
      ),
    },
    onGenerateRoute: (settings) {
      if (settings.name == AppNavigator.workoutPrograms) {
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('programs-route')),
        );
      }
      if (settings.name == AppNavigator.workoutProgramDetails) {
        final args = settings.arguments! as WorkoutProgramDetailsArgs;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('details:${args.program.name}')),
        );
      }
      return null;
    },
  );
}

/// Deliberately NOT pumpAndSettle(): the screen's Loading state briefly
/// shows an indeterminate CircularProgressIndicator, whose animation
/// controller never stops scheduling frames — pumpAndSettle would spin
/// toward its 10-minute internal timeout instead of ever settling. A
/// few bounded pumps are enough to drain the (fake, synchronous) load
/// + sync Futures and land on the Loaded state deterministically.
///
/// WorkoutProgramsScreen.initState() also reads WorkoutSessionCubit via
/// context.read() (to check for an active session) and consumes it via
/// a BlocBuilder further down the tree, so it must be provided
/// alongside WorkoutProgramCubit.
///
/// Root cause found while diagnosing this file's original flakiness,
/// confirmed by instrumenting `cubit.state` directly:
/// `WorkoutProgramCubit.loadPrograms()`/`WorkoutSessionCubit.checkActiveSession()`
/// each await a REAL `Hive.openBox` (this test uses a real temp
/// directory, never mocked Hive) the FIRST time their box is opened.
/// `AutomatedTestWidgetsFlutterBinding`'s `pump()` only advances a FAKE
/// clock and flushes the microtask queue — it never services genuine,
/// real-event-loop disk I/O, and `tester.runAsync()` cannot retroactively
/// rescue a Future that was already created inside `initState()`'s fake
/// zone (confirmed: the Cubit was still `WorkoutProgramLoading` after 2
/// full simulated seconds of pumping AND after a 5-real-second
/// `runAsync` wait). The fix lives in `setUp()`: both boxes are opened
/// for real there — `setUp`/`tearDown` run in a plain zone, so genuine
/// I/O completes normally — before the widget is ever pumped, so
/// `UserStorageManager`'s already-open-box fast path (no real I/O, a
/// resolved value through one microtask hop) is what `initState()`
/// actually hits, and ordinary bounded `pump()` calls are sufficient.
/// The same rule applies to the tests' own seeding: `createProgram`
/// performs real Hive writes, so awaiting it directly inside a
/// `testWidgets` body (fake zone) never completes — it hung the run
/// indefinitely. Seeding goes through `tester.runAsync`, where the
/// Future is created in the real zone.
Future<void> _pumpUntilLoaded(
  WidgetTester tester,
  WorkoutProgramCubit cubit,
  WorkoutSessionCubit sessionCubit,
) async {
  await tester.pumpWidget(_wrap(cubit, sessionCubit));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late Directory tempDir;
  late WorkoutProgramCubit cubit;
  late WorkoutSessionCubit sessionCubit;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'workout_programs_screen_test_',
    );
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WorkoutProgramAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(WorkoutSessionAdapter());
    }

    final storageManager = UserStorageManager();
    final programRepository = WorkoutProgramRepository(
      remoteDataSource: _FakeWorkoutProgramRemoteDataSource(),
      storageManager: storageManager,
      uidOverride: () => 'test-uid',
    );

    // WorkoutProgramsScreen.initState() reads WorkoutSessionCubit
    // directly — matches app_router.dart's real provider tree for this
    // screen, which provides both Cubits side by side.
    sessionCubit = WorkoutSessionCubit(
      repository: WorkoutSessionRepository(
        remoteDataSource: _FakeWorkoutSessionRemoteDataSource(),
        storageManager: storageManager,
        uidOverride: () => 'test-uid',
      ),
    );

    cubit = WorkoutProgramCubit(
      repository: programRepository,
      // WorkoutCascadeDeletionService is now a required dependency
      // (Stage 3) — this screen test never exercises cascade delete,
      // but the Cubit still needs a valid instance to construct.
      deletionService: WorkoutCascadeDeletionService(
        programRepository: programRepository,
        templateRepository: WorkoutTemplateRepository(
          remoteDataSource: _FakeWorkoutTemplateRemoteDataSource(),
          storageManager: storageManager,
          uidOverride: () => 'test-uid',
        ),
        sessionRepository: WorkoutSessionRepository(
          remoteDataSource: _FakeWorkoutSessionRemoteDataSource(),
          storageManager: storageManager,
          uidOverride: () => 'test-uid',
        ),
        setRepository: SessionExerciseRepository(
          remoteDataSource: _FakeWorkoutRemoteDataSource(),
          storageManager: storageManager,
          uidOverride: () => 'test-uid',
        ),
      ),
    );

    // Pre-warm both boxes for real, here in setUp() (a plain zone,
    // where genuine Hive disk I/O completes normally) — see
    // _pumpUntilLoaded's doc comment for why this must happen before
    // the widget (and its initState()) is ever pumped.
    await programRepository.getUserBox();
    await sessionCubit.repository.getUserBox();
  });

  tearDown(() async {
    await cubit.close();
    await sessionCubit.close();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('shows the empty state when there are no programs', (
    tester,
  ) async {
    await _pumpUntilLoaded(tester, cubit, sessionCubit);

    expect(find.text('No programs yet.'), findsOneWidget);
  });

  testWidgets(
    'shows the active program section once a program is created active',
    (tester) async {
      await tester.runAsync(
        () => cubit.createProgram(name: 'Push Pull Legs V1', makeActive: true),
      );

      await _pumpUntilLoaded(tester, cubit, sessionCubit);

      // Appears twice: the section label and the small badge on the card.
      expect(find.text('Active Program'), findsWidgets);
      expect(find.text('Push Pull Legs V1'), findsOneWidget);
    },
  );

  testWidgets('shows the previous programs section for inactive programs', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await cubit.createProgram(name: 'Program A', makeActive: true);
      await cubit.createProgram(
        name: 'Program B',
        makeActive: true,
      ); // deactivates A
    });

    await _pumpUntilLoaded(tester, cubit, sessionCubit);

    expect(find.text('Previous Programs'), findsOneWidget);
    expect(find.text('Program A'), findsOneWidget);
    expect(find.text('Program B'), findsOneWidget);
  });

  testWidgets('program screen uses the dark semantic canvas and surfaces', (
    tester,
  ) async {
    await tester.runAsync(
      () => cubit.createProgram(name: 'Dark mode program', makeActive: true),
    );
    await tester.pumpWidget(
      _wrap(cubit, sessionCubit, themeMode: ThemeMode.dark),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppSemanticColors.dark.canvas);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, AppSemanticColors.dark.canvas);
    expect(find.text('Dark mode program'), findsOneWidget);
  });

  for (final language in ['en', 'ar']) {
    testWidgets('$language narrow program cards wrap names and actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final longName = language == 'ar'
          ? 'برنامج القوة وبناء العضلات لأيام التدريب الأسبوعية'
          : 'Weekly strength and muscle building training program';
      late List<WorkoutProgram> programs;
      await tester.runAsync(() async {
        await cubit.createProgram(name: longName);
        await cubit.createProgram(name: 'Second plan');
        programs = cubit.repository.getPrograms(
          await cubit.repository.getUserBox(),
        );
      });
      await tester.pumpWidget(
        _wrap(
          cubit,
          sessionCubit,
          locale: Locale(language),
          themeMode: language == 'ar' ? ThemeMode.dark : ThemeMode.light,
        ),
      );
      await tester.pumpAndSettle();
      final cards =
          [
            for (final program in programs)
              find.byKey(ValueKey('program-card-${program.id}')),
          ]..sort(
            (a, b) =>
                tester.getTopLeft(a).dy.compareTo(tester.getTopLeft(b).dy),
          );
      expect(tester.getTopLeft(cards.first).dx, WorkoutTemplateSpacing.screen);
      expect(
        tester.getTopLeft(cards.last).dy - tester.getBottomLeft(cards.first).dy,
        closeTo(WorkoutTemplateSpacing.programCard, 0.01),
      );
      final title = find.text(longName);
      expect(
        Directionality.of(tester.element(title)),
        language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      for (final card in cards) {
        final actions = find.descendant(
          of: card,
          matching: find.byWidgetPredicate(
            (widget) => widget is OutlinedButton,
          ),
        );
        expect(actions, findsNWidgets(5));
        for (final action in actions.evaluate()) {
          expect(
            tester.getSize(find.byWidget(action.widget)).height,
            greaterThanOrEqualTo(WorkoutTemplateSpacing.tapTarget),
          );
        }
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Home plans empty state opens the programs hub', (tester) async {
    await tester.runAsync(() => cubit.loadPrograms());
    await tester.pumpWidget(_wrapHomePlans(cubit));
    await tester.pump();

    expect(find.text('My Workout Plans'), findsOneWidget);
    expect(
      find.text(
        'Create your first workout plan to organize your training days.',
      ),
      findsOneWidget,
    );
    expect(find.text('View all'), findsOneWidget);
    await tester.tap(find.text('Create a workout plan'));
    await tester.pumpAndSettle();
    expect(find.text('programs-route'), findsOneWidget);
  });

  testWidgets(
    'Home shows active and inactive plans distinctly and opens details',
    (tester) async {
      late String activeId;
      late String inactiveId;
      await tester.runAsync(() async {
        await cubit.createProgram(name: 'Push A', makeActive: true);
        await cubit.createProgram(name: 'Push B');
        final programs = cubit.repository.getPrograms(
          await cubit.repository.getUserBox(),
        );
        activeId = programs.singleWhere((p) => p.name == 'Push A').id;
        inactiveId = programs.singleWhere((p) => p.name == 'Push B').id;
        await cubit.loadPrograms();
      });
      await tester.pumpWidget(_wrapHomePlans(cubit));
      await tester.pump();

      expect(find.text('Active Program'), findsOneWidget);
      expect(find.text('No Active Program'), findsNothing);
      final planTitle = find.text('My Workout Plans');
      expect(Directionality.of(tester.element(planTitle)), TextDirection.ltr);
      expect(Theme.of(tester.element(planTitle)).brightness, Brightness.light);
      final activeCard = tester.widget<Material>(
        find.byKey(ValueKey('home-workout-plan-surface-$activeId')),
      );
      final inactiveCard = tester.widget<Material>(
        find.byKey(ValueKey('home-workout-plan-surface-$inactiveId')),
      );
      final activeShape = activeCard.shape! as RoundedRectangleBorder;
      final inactiveShape = inactiveCard.shape! as RoundedRectangleBorder;
      expect(activeShape.side.color, AppTheme.light.colorScheme.primary);
      expect(inactiveShape.side.color, AppSemanticColors.light.border);

      await tester.tap(find.text('Push A'));
      await tester.pumpAndSettle();
      expect(find.text('details:Push A'), findsOneWidget);
      expect(
        cubit.repository
            .getActiveProgram(await cubit.repository.getUserBox())
            ?.id,
        activeId,
      );
    },
  );

  testWidgets(
    'Home shows no-active state when plans exist without a selection',
    (tester) async {
      await tester.runAsync(() async {
        await cubit.createProgram(name: 'Unselected plan');
        await cubit.loadPrograms();
      });
      await tester.pumpWidget(_wrapHomePlans(cubit));
      await tester.pump();

      expect(find.text('No Active Program'), findsOneWidget);
      expect(find.text('Make Active'), findsOneWidget);
      expect(find.text('Active Program'), findsNothing);
    },
  );

  testWidgets('Home can explicitly activate a plan and persist that choice', (
    tester,
  ) async {
    late String targetId;
    await tester.runAsync(() async {
      await cubit.createProgram(name: 'Current plan', makeActive: true);
      await cubit.createProgram(name: 'Next plan');
      targetId = cubit.repository
          .getPrograms(await cubit.repository.getUserBox())
          .singleWhere((p) => p.name == 'Next plan')
          .id;
      await cubit.loadPrograms();
    });
    await tester.pumpWidget(_wrapHomePlans(cubit));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey('home-workout-plan-$targetId')),
          matching: find.text('Make Active'),
        ),
      );
    });
    await tester.pump();
    expect(find.text('Make Active?'), findsOneWidget);
    await tester.runAsync(() async {
      final activated = cubit.stream.firstWhere(
        (state) => state is WorkoutProgramLoaded,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Make Active'));
      await activated.timeout(const Duration(seconds: 5));
    });
    await tester.pump();

    final active = await tester.runAsync(
      () async => cubit.repository.getActiveProgram(
        await cubit.repository.getUserBox(),
      ),
    );
    expect(active?.id, targetId);
    expect(
      find.descendant(
        of: find.byKey(ValueKey('home-workout-plan-$targetId')),
        matching: find.text('Active Program'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Home plans support Arabic RTL and dark theme', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await cubit.createProgram(
        name: 'خطة تدريب طويلة للاختبار على شاشة هاتف صغيرة',
        makeActive: true,
      );
      await cubit.loadPrograms();
    });
    await tester.pumpWidget(
      _wrapHomePlans(
        cubit,
        locale: const Locale('ar'),
        themeMode: ThemeMode.dark,
      ),
    );
    await tester.pump();

    expect(find.text('خطط التمرين'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('خطط التمرين'))),
      TextDirection.rtl,
    );
    expect(
      Theme.of(tester.element(find.text('خطط التمرين'))).brightness,
      Brightness.dark,
    );
    expect(find.text('البرنامج النشط'), findsOneWidget);
  });

  testWidgets('Home keeps the plan list compact and View all opens the hub', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (var i = 1; i <= 4; i++) {
        await cubit.createProgram(name: 'Plan $i');
      }
      await cubit.loadPrograms();
    });
    await tester.pumpWidget(_wrapHomePlans(cubit));
    await tester.pump();

    final planCards = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('home-workout-plan-') &&
          !key.value.startsWith('home-workout-plan-surface-');
    });
    expect(planCards, findsNWidgets(3));
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(find.text('programs-route'), findsOneWidget);
  });
}
