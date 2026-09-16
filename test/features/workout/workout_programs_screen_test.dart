import 'dart:io';

import 'package:ae_coaching/features/workout/data/datasources/workout_program_remote_data_source.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_program_repository.dart';
import 'package:ae_coaching/features/workout/presentation/cubit/workout_program_cubit.dart';
import 'package:ae_coaching/features/workout/presentation/screens/workout_programs_screen.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeWorkoutProgramRemoteDataSource implements WorkoutProgramRemoteDataSource {
  @override
  Future<void> syncProgram(String id, WorkoutProgram program) async {}

  @override
  Future<void> deleteProgram(String id) async {}

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchAllRemotePrograms() async {
    return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  }
}

Widget _wrap(WorkoutProgramCubit cubit) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider.value(value: cubit, child: const WorkoutProgramsScreen()),
  );
}

/// Deliberately NOT pumpAndSettle(): the screen's Loading state briefly
/// shows an indeterminate CircularProgressIndicator, whose animation
/// controller never stops scheduling frames — pumpAndSettle would spin
/// toward its 10-minute internal timeout instead of ever settling. A
/// few bounded pumps are enough to drain the (fake, synchronous) load
/// + sync Futures and land on the Loaded state deterministically.
Future<void> _pumpUntilLoaded(WidgetTester tester, WorkoutProgramCubit cubit) async {
  await tester.pumpWidget(_wrap(cubit));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late Directory tempDir;
  late WorkoutProgramCubit cubit;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('workout_programs_screen_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WorkoutProgramAdapter());
    }

    cubit = WorkoutProgramCubit(
      repository: WorkoutProgramRepository(
        remoteDataSource: _FakeWorkoutProgramRemoteDataSource(),
        uidOverride: () => 'test-uid',
      ),
    );
  });

  tearDown(() async {
    await cubit.close();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('shows the empty state when there are no programs', (tester) async {
    await _pumpUntilLoaded(tester, cubit);

    expect(find.text('No programs yet.'), findsOneWidget);
  });

  testWidgets('shows the active program section once a program is created active', (tester) async {
    await cubit.createProgram(name: 'Push Pull Legs V1', makeActive: true);

    await _pumpUntilLoaded(tester, cubit);

    // Appears twice: the section label and the small badge on the card.
    expect(find.text('Active Program'), findsWidgets);
    expect(find.text('Push Pull Legs V1'), findsOneWidget);
  });

  testWidgets('shows the previous programs section for inactive programs', (tester) async {
    await cubit.createProgram(name: 'Program A', makeActive: true);
    await cubit.createProgram(name: 'Program B', makeActive: true); // deactivates A

    await _pumpUntilLoaded(tester, cubit);

    expect(find.text('Previous Programs'), findsOneWidget);
    expect(find.text('Program A'), findsOneWidget);
    expect(find.text('Program B'), findsOneWidget);
  });
}
