import 'dart:io';

import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_session_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/datasources/workout_template_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/exercise_set.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_template_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_analytics_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/program_consistency_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_history_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/program_analytics_screen.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_template_history_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeSetRemoteSource implements WorkoutRemoteDataSource {
  @override
  Future<void> syncSet(String key, ExerciseSet set) async {}

  @override
  Future<void> deleteSet(String key) async {}

  @override
  Future<void> deleteMultipleSets(List<String> keys) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSets() async => const [];
}

class _FakeSessionRemoteSource implements WorkoutSessionRemoteDataSource {
  @override
  Future<void> syncSession(String id, WorkoutSession session) async {}

  @override
  Future<void> deleteSession(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteSessions() async => const [];
}

class _FakeTemplateRemoteSource implements WorkoutTemplateRemoteDataSource {
  @override
  Future<void> syncTemplate(String id, WorkoutTemplate template) async {}

  @override
  Future<void> deleteTemplate(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  fetchAllRemoteTemplates() async => const [];
}

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Program Analytics history and charts render in $brightness', (
      tester,
    ) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('program-analytics-theme-'),
      ))!;
      Hive.init(directory.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ExerciseSetAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(WorkoutTemplateAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(WorkoutSessionAdapter());
      }

      final storage = UserStorageManager();
      final templateRepository = WorkoutTemplateRepository(
        remoteDataSource: _FakeTemplateRemoteSource(),
        storageManager: storage,
        uidOverride: () => 'theme-test-user',
      );
      final sessionRepository = WorkoutSessionRepository(
        remoteDataSource: _FakeSessionRemoteSource(),
        storageManager: storage,
        uidOverride: () => 'theme-test-user',
      );
      final setRepository = SessionExerciseRepository(
        remoteDataSource: _FakeSetRemoteSource(),
        storageManager: storage,
        uidOverride: () => 'theme-test-user',
      );
      late final WorkoutTemplate template;
      await tester.runAsync(() async {
        template = await templateRepository.createTemplate(
          programId: 'theme-test-program',
          name: 'Push A',
        );
        for (final weight in [20.0, 25.0]) {
          final session = await sessionRepository.startWorkoutSession(
            programId: 'theme-test-program',
            workoutTemplateId: template.id,
            workoutNameSnapshot: 'Push A',
          );
          await setRepository.addSet(
            programId: 'theme-test-program',
            workoutTemplateId: template.id,
            workoutSessionId: session.id,
            exerciseName: 'Squat',
            weight: weight,
            reps: 8,
            notes: weight == 25 ? 'Back felt strong' : null,
          );
          await sessionRepository.completeWorkoutSession(
            sessionId: session.id,
            totalVolume: weight * 8,
          );
        }
      });

      final analyticsCubit = ProgramAnalyticsCubit(
        templateRepository: templateRepository,
        sessionRepository: sessionRepository,
        setRepository: setRepository,
      );
      final consistencyCubit = ProgramConsistencyCubit(
        sessionRepository: sessionRepository,
      );
      final historyCubit = WorkoutHistoryCubit(
        sessionRepository: sessionRepository,
        setRepository: setRepository,
      );
      addTearDown(() async {
        await analyticsCubit.close();
        await consistencyCubit.close();
        await historyCubit.close();
        await tester.runAsync(() async {
          await Hive.deleteFromDisk();
          await directory.delete(recursive: true);
        });
      });

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: analyticsCubit),
            BlocProvider.value(value: consistencyCubit),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: ProgramAnalyticsScreen(
              program: WorkoutProgram(
                id: 'theme-test-program',
                name: 'برنامج الاختبار',
                createdAt: DateTime(2026),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProgramAnalyticsScreen));
      expect(Theme.of(context).brightness, brightness);
      expect(Directionality.of(context), TextDirection.rtl);
      final l10n = AppLocalizations.of(context)!;
      expect(find.text(l10n.analyticsWeightTitle), findsOneWidget);
      expect(find.text(l10n.analyticsRepsTitle), findsOneWidget);
      expect(find.text(l10n.analyticsVolumeTitle), findsOneWidget);
      expect(find.text('Push A'), findsWidgets);
      expect(find.text('Squat'), findsWidgets);
      expect(find.byType(CustomPaint), findsWidgets);

      final cards = tester.widgetList<Card>(find.byType(Card));
      expect(cards, isNotEmpty);
      expect(
        cards.every(
          (card) => card.color == Theme.of(context).colorScheme.surface,
        ),
        isTrue,
      );

      await tester.pumpWidget(
        BlocProvider.value(
          value: historyCubit,
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: WorkoutTemplateHistoryScreen(template: template),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          AppLocalizations.of(
            tester.element(find.byType(WorkoutTemplateHistoryScreen)),
          )!.workoutHistoryTitle('Push A'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('200'), findsOneWidget);
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Back felt strong'), findsOneWidget);
      expect(find.text('25كجم × 8'), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.byType(WorkoutTemplateHistoryScreen)),
        ).brightness,
        brightness,
      );
    });
  }
}
