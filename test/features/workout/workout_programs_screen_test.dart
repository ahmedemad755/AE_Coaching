import 'dart:io';

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

Widget _wrap(WorkoutProgramCubit cubit, WorkoutSessionCubit sessionCubit) {
  return MaterialApp(
    locale: const Locale('en'),
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
}
