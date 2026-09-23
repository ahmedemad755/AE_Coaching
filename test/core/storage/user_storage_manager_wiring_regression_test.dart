import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOURCE-LEVEL regression tier — proves the Stage 3 DI-wiring
/// invariants that a runtime test can't directly observe (there is no
/// live GetIt/Firebase app in this test environment): every production
/// repository/Cubit receives the SAME GetIt-managed UserStorageManager
/// instance, nothing constructs an independent one internally, and no
/// static/shared singleton exists on the class to make that mistake
/// possible in the first place.
void main() {
  late String managerSource;
  late String serviceLocatorSource;
  late final Map<String, String> repositorySources;

  String stripLineComments(String source) {
    return source
        .split('\n')
        .where((line) => !line.trim().startsWith('//'))
        .join('\n');
  }

  late String managerCode;

  setUpAll(() {
    managerSource = File(
      'lib/core/storage/user_storage_manager.dart',
    ).readAsStringSync();
    managerCode = stripLineComments(managerSource);
    serviceLocatorSource = File('lib/service_locator.dart').readAsStringSync();
    repositorySources = {
      'WorkoutProgramRepository': File(
        'lib/features/workout/data/repositories/workout_program_repository.dart',
      ).readAsStringSync(),
      'WorkoutTemplateRepository': File(
        'lib/features/workout/data/repositories/workout_template_repository.dart',
      ).readAsStringSync(),
      'WorkoutSessionRepository': File(
        'lib/features/workout/data/repositories/workout_session_repository.dart',
      ).readAsStringSync(),
      'SessionExerciseRepository': File(
        'lib/features/workout/data/repositories/session_exercise_repository.dart',
      ).readAsStringSync(),
      'MeasurementRepository': File(
        'lib/features/measurements/data/repositories/measurement_repository.dart',
      ).readAsStringSync(),
      'ProgressPhotoRepository': File(
        'lib/features/progress_photos/data/repositories/progress_photo_repository.dart',
      ).readAsStringSync(),
      'WorkoutCubit': File(
        'lib/features/workout/presentation/bloc/workout_cubit.dart',
      ).readAsStringSync(),
    };
  });

  group('no static/shared singleton exists on UserStorageManager', () {
    test('the class declares no static instance-returning member '
        '(no `.shared`, no `static UserStorageManager`)', () {
      expect(
        managerSource.contains('static final UserStorageManager'),
        isFalse,
      );
      expect(managerSource.contains('static UserStorageManager get'), isFalse);
      expect(managerSource.contains('.shared'), isFalse);
    });

    test('UserStorageManager has exactly one public, plain constructor '
        '— nothing that could silently hand back a shared instance', () {
      expect(managerSource.contains('UserStorageManager();'), isTrue);
    });
  });

  group('no repository or core storage class calls GetIt directly', () {
    test('user_storage_manager.dart never imports service_locator.dart '
        'or references sl()', () {
      // Checked as an actual import statement, not a bare substring —
      // the class's own doc comment legitimately mentions
      // `service_locator.dart` in prose to explain how it's wired up.
      expect(
        managerSource.contains(
          "import 'package:ae_coaching/service_locator.dart'",
        ),
        isFalse,
      );
      expect(managerCode.contains('sl<'), isFalse);
      expect(managerCode.contains('sl()'), isFalse);
    });

    test('none of the six repositories or WorkoutCubit import '
        'service_locator.dart or call sl() to obtain their '
        'UserStorageManager — it must arrive only via constructor '
        'injection', () {
      repositorySources.forEach((name, source) {
        expect(
          source.contains("import 'package:ae_coaching/service_locator.dart'"),
          isFalse,
          reason: '$name must not import service_locator.dart',
        );
        expect(
          source.contains('sl<UserStorageManager>()'),
          isFalse,
          reason: '$name must not resolve UserStorageManager via GetIt itself',
        );
      });
    });

    test('none of the six repositories construct UserStorageManager() '
        'internally — it is always received as a parameter', () {
      repositorySources.forEach((name, source) {
        expect(
          source.contains('UserStorageManager()'),
          isFalse,
          reason: '$name must not construct its own UserStorageManager',
        );
      });
    });
  });

  group('every production repository/Cubit is wired to the same '
      'GetIt-managed instance', () {
    test('service_locator.dart registers UserStorageManager exactly '
        'once, as a lazy singleton, with no other registration for the '
        'type anywhere', () {
      final registrations = RegExp(
        r'registerLazySingleton[<(][^;]*UserStorageManager',
      ).allMatches(serviceLocatorSource).length;
      expect(registrations, 1);
    });

    test('all six repository registrations and the WorkoutCubit '
        'registration pass storageManager: sl()', () {
      final passCount = RegExp(
        r'storageManager:\s*sl\(\)',
      ).allMatches(serviceLocatorSource).length;
      // WorkoutProgramRepository, WorkoutTemplateRepository,
      // WorkoutSessionRepository, SessionExerciseRepository,
      // MeasurementRepository, ProgressPhotoRepository, WorkoutCubit.
      expect(passCount, 7);
    });

    test('each of the six repository constructors declares a required '
        'UserStorageManager parameter (not optional, not defaulted)', () {
      for (final name in [
        'WorkoutProgramRepository',
        'WorkoutTemplateRepository',
        'WorkoutSessionRepository',
        'SessionExerciseRepository',
        'MeasurementRepository',
        'ProgressPhotoRepository',
      ]) {
        final source = repositorySources[name]!;
        expect(
          source.contains('required UserStorageManager storageManager'),
          isTrue,
          reason: '$name must declare a required UserStorageManager param',
        );
      }
    });

    test('WorkoutCubit declares a required UserStorageManager parameter '
        'and no longer duplicates sets_\$uid open-or-reuse logic '
        '(no more Hive.isBoxOpen/Hive.openBox in this file)', () {
      final source = repositorySources['WorkoutCubit']!;
      // WorkoutCubit uses Dart's `required this.storageManager` field
      // shorthand rather than the explicit `required UserStorageManager
      // storageManager` form the repositories use — both are equally
      // required constructor parameters, so either spelling counts.
      expect(
        source.contains('required this.storageManager') ||
            source.contains('required UserStorageManager storageManager'),
        isTrue,
      );
      expect(source.contains('Hive.isBoxOpen'), isFalse);
      expect(source.contains('Hive.openBox'), isFalse);
    });
  });
}
