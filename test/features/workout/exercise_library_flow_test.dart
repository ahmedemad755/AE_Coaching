import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/custom_exercise.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_catalog_item.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template_exercise_assignment.dart';
import 'package:ae_coaching/features/workout/data/repositories/custom_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/exercise_library_catalog.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/session_exercise_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/widgets/template_exercise_manager.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _TemplateRemote implements WorkoutTemplateRemoteDataSource {
  @override
  Future<void> syncTemplate(String id, WorkoutTemplate template) async {}

  @override
  Future<void> deleteTemplate(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteTemplates() async => [];
}

class _MemoryTemplateRepository extends WorkoutTemplateRepository {
  WorkoutTemplate template;
  var _nextId = 0;
  String? lastTemplateId;
  bool failRemovals = false;

  _MemoryTemplateRepository({
    required this.template,
    required UserStorageManager storage,
  }) : super(
         remoteDataSource: _TemplateRemote(),
         storageManager: storage,
         uidOverride: () => 'flow-user',
       );

  @override
  Future<WorkoutTemplate> addExerciseAssignments({
    required String templateId,
    required List<ExerciseLibraryItem> exercises,
    required String languageCode,
  }) async {
    lastTemplateId = templateId;
    final additions = exercises.map((exercise) {
      return WorkoutTemplateExerciseAssignment(
        assignmentId: 'assignment-${_nextId++}',
        exerciseId: exercise.id,
        exerciseNameSnapshot: exercise.nameForLanguage(languageCode),
        referenceType: exercise.source == ExerciseLibraryItemSource.builtIn
            ? WorkoutExerciseReferenceType.builtIn.name
            : WorkoutExerciseReferenceType.custom.name,
      );
    });
    template = template.copyWith(
      exerciseAssignments: [...template.exerciseAssignments, ...additions],
    );
    return template;
  }

  @override
  Future<WorkoutTemplate> removeExerciseAssignment({
    required String templateId,
    required String assignmentId,
  }) async {
    if (failRemovals) throw StateError('temporary write failure');
    template = template.copyWith(
      exerciseAssignments: template.exerciseAssignments
          .where((item) => item.assignmentId != assignmentId)
          .toList(),
    );
    return template;
  }

  @override
  Future<WorkoutTemplate> reorderExerciseAssignments({
    required String templateId,
    required List<String> orderedAssignmentIds,
  }) async {
    final byId = {
      for (final item in template.exerciseAssignments) item.assignmentId: item,
    };
    template = template.copyWith(
      exerciseAssignments: orderedAssignmentIds.map((id) => byId[id]!).toList(),
    );
    return template;
  }

  @override
  Future<WorkoutTemplate> replaceExerciseAssignment({
    required String templateId,
    required String assignmentId,
    required ExerciseLibraryItem exercise,
    required String languageCode,
  }) async {
    final assignments = List<WorkoutTemplateExerciseAssignment>.of(
      template.exerciseAssignments,
    );
    final index = assignments.indexWhere(
      (item) => item.assignmentId == assignmentId,
    );
    final existing = assignments[index];
    assignments[index] = WorkoutTemplateExerciseAssignment(
      assignmentId: existing.assignmentId,
      exerciseId: exercise.id,
      exerciseNameSnapshot: exercise.nameForLanguage(languageCode),
      referenceType: exercise.source.name,
    );
    template = template.copyWith(exerciseAssignments: assignments);
    return template;
  }
}

class _SessionRemote implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSessions() async => [];
}

class _SetsRemote implements WorkoutRemoteDataSource {
  @override
  Future<void> syncSet(String key, ExerciseSet set) async {}

  @override
  Future<void> deleteSet(String key) async {}

  @override
  Future<void> deleteMultipleSets(List<String> keys) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSets() async => [];
}

class _CustomRepository extends CustomExerciseRepository {
  _CustomRepository(UserStorageManager manager)
    : super(storageManager: manager, uidOverride: () => 'flow-user');

  @override
  Future<List<CustomExercise>> getAllExercises() async => [];
}

class _OfflineCatalog implements ExerciseLibraryCatalog {
  static const items = [
    ExerciseCatalogItem(
      id: 'bench',
      nameEn: 'Bench Press',
      nameAr: 'بنش صدر',
      muscleGroup: 'chest',
      equipment: 'barbell',
    ),
    ExerciseCatalogItem(
      id: 'row',
      nameEn: 'Cable Row',
      nameAr: 'سحب كيبل',
      muscleGroup: 'back',
      equipment: 'cable',
    ),
    ExerciseCatalogItem(
      id: 'pushup',
      nameEn: 'Push Up',
      nameAr: 'ضغط',
      muscleGroup: 'chest',
      equipment: 'bodyweight',
    ),
  ];

  @override
  Future<List<ExerciseLibraryItem>> search({
    String query = '',
    Set<String> muscleGroups = const {},
    Set<String> equipment = const {},
  }) async => items
      .where(
        (item) =>
            (query.isEmpty ||
                item.nameEn.toLowerCase().contains(query.toLowerCase()) ||
                item.nameAr.contains(query)) &&
            (muscleGroups.isEmpty || muscleGroups.contains(item.muscleGroup)) &&
            (equipment.isEmpty || equipment.contains(item.equipment)),
      )
      .map(ExerciseLibraryItem.fromBuiltIn)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late UserStorageManager storage;
  late _MemoryTemplateRepository templateRepository;
  late WorkoutSessionRepository sessionRepository;
  late SessionExerciseRepository setRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exercise_library_flow_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ExerciseSetAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(WorkoutTemplateAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(WorkoutSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(WorkoutTemplateExerciseAssignmentAdapter());
    }
    storage = UserStorageManager();
    sessionRepository = WorkoutSessionRepository(
      remoteDataSource: _SessionRemote(),
      storageManager: storage,
      uidOverride: () => 'flow-user',
    );
    setRepository = SessionExerciseRepository(
      remoteDataSource: _SetsRemote(),
      storageManager: storage,
      uidOverride: () => 'flow-user',
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  testWidgets('inline template management persists through repeat sessions', (
    tester,
  ) async {
    final template = WorkoutTemplate(
      id: 'push-a',
      programId: 'program',
      name: 'Push A',
      createdAt: DateTime.now(),
    );
    templateRepository = _MemoryTemplateRepository(
      template: template,
      storage: storage,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TemplateExerciseManager(
          template: template,
          repository: templateRepository,
          catalog: _OfflineCatalog(),
          customExercises: _CustomRepository(storage),
          languageCode: 'en',
        ),
      ),
    );
    expect(find.text('Exercises · 0'), findsOneWidget);
    expect(find.textContaining('Add exercises here'), findsOneWidget);
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press'));
    await tester.tap(find.text('Cable Row'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add selected (2)'));
    await tester.pumpAndSettle();

    final saved = templateRepository.template;
    expect(templateRepository.lastTemplateId, 'push-a');
    expect(saved.exerciseAssignments.map((item) => item.exerciseId), [
      'bench',
      'row',
    ]);
    expect(find.text('Exercises · 2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Cable Row'), findsOneWidget);

    late WorkoutSession first;
    await tester.runAsync(() async {
      first = await sessionRepository.startWorkoutSession(
        programId: 'program',
        workoutTemplateId: template.id,
        workoutNameSnapshot: template.name,
        templateExerciseAssignments: saved.exerciseAssignments,
      );
    });
    final firstCubit = SessionExerciseCubit(
      repository: setRepository,
      sessionRepository: sessionRepository,
    );
    await tester.runAsync(() => firstCubit.loadForSession(first));
    var state = firstCubit.state as SessionExerciseLoaded;
    expect(state.rows.map((row) => row.exerciseName), [
      'Bench Press',
      'Cable Row',
    ]);
    expect(state.rows.every((row) => row.sets.isEmpty), isTrue);
    expect(await firstCubit.getValidSetsForSession(first), isEmpty);

    await tester.runAsync(() async {
      await firstCubit.logSet(
        session: first,
        exerciseName: 'Bench Press',
        weight: 60,
        reps: 8,
      );
      await sessionRepository.completeWorkoutSession(
        sessionId: first.id,
        totalVolume: 480,
      );
    });
    await firstCubit.close();

    late WorkoutSession second;
    await tester.runAsync(() async {
      second = await sessionRepository.startWorkoutSession(
        programId: 'program',
        workoutTemplateId: template.id,
        workoutNameSnapshot: template.name,
        templateExerciseAssignments: saved.exerciseAssignments,
      );
    });
    final secondCubit = SessionExerciseCubit(
      repository: setRepository,
      sessionRepository: sessionRepository,
    );
    await tester.runAsync(() => secondCubit.loadForSession(second));
    state = secondCubit.state as SessionExerciseLoaded;
    expect(state.rows.map((row) => row.exerciseName), [
      'Bench Press',
      'Cable Row',
    ]);
    expect(state.rows.every((row) => row.sets.isEmpty), isTrue);
    expect(await secondCubit.getValidSetsForSession(second), isEmpty);
    expect(state.rows.first.previousSets.single.weight, 60);
    await secondCubit.close();

    final firstAssignmentId = saved.exerciseAssignments.first.assignmentId;
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace exercise'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Push Up'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Push Up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add selected (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Push Up'), findsOneWidget);
    expect(
      templateRepository.template.exerciseAssignments.first.assignmentId,
      firstAssignmentId,
    );
    expect(
      templateRepository.template.exerciseAssignments.map(
        (item) => item.exerciseId,
      ),
      ['pushup', 'row'],
    );
  });

  testWidgets(
    'inline removal updates immediately and recovers on write error',
    (tester) async {
      final template = WorkoutTemplate(
        id: 'inline-day',
        programId: 'program',
        name: 'Push A',
        createdAt: DateTime.now(),
      );
      templateRepository = _MemoryTemplateRepository(
        template: template,
        storage: storage,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TemplateExerciseManager(
              template: template,
              repository: templateRepository,
              catalog: _OfflineCatalog(),
              customExercises: _CustomRepository(storage),
              languageCode: 'en',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add exercise'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bench Press'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add selected (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Bench Press'), findsOneWidget);

      templateRepository.failRemovals = true;
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Bench Press'), findsOneWidget);
      expect(templateRepository.template.exerciseAssignments, hasLength(1));

      templateRepository.failRemovals = false;
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Bench Press'), findsNothing);
      expect(templateRepository.template.exerciseAssignments, isEmpty);
    },
  );

  testWidgets('inline exercise manager follows Arabic RTL direction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final template = WorkoutTemplate(
      id: 'arabic-day',
      programId: 'program',
      name: 'يوم الدفع',
      createdAt: DateTime.now(),
    );
    templateRepository = _MemoryTemplateRepository(
      template: template,
      storage: storage,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TemplateExerciseManager(
            template: template,
            repository: templateRepository,
            catalog: _OfflineCatalog(),
            customExercises: _CustomRepository(storage),
            languageCode: 'ar',
          ),
        ),
      ),
    );
    expect(
      Directionality.of(tester.element(find.byType(TemplateExerciseManager))),
      TextDirection.rtl,
    );
    expect(find.text('التمارين · 0'), findsOneWidget);
    expect(find.text('إضافة تمرين'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
