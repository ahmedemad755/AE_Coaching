import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SOURCE-LEVEL regression tier: `AppBootstrap.initialize()` cannot be
/// exercised for real in this test environment because
/// `Firebase.initializeApp` has no platform channel to talk to here (the
/// same, already-documented limitation behind every other
/// Firebase-touching test in this suite). The Hive-adapter piece IS
/// tested for real — see `app_bootstrap_hive_adapters_test.dart`.
///
/// This proves the ordering: `main.dart` awaits
/// `AppBootstrap.initialize()` before `runApp`, and `initialize()`
/// itself calls `WidgetsFlutterBinding.ensureInitialized()` first, then
/// Firebase → App Check, then the 16 DI registrations, then Hive
/// init/adapters/authBox — preserving the exact sequence that was
/// previously inlined in `main()`.
void main() {
  late String bootstrapSource;
  late String mainSource;

  setUpAll(() {
    bootstrapSource = File(
      'lib/core/bootstrap/app_bootstrap.dart',
    ).readAsStringSync();
    mainSource = File('lib/main.dart').readAsStringSync();
  });

  group('main.dart is a minimal entry point', () {
    test('main() awaits AppBootstrap.initialize() before runApp', () {
      final initIndex = mainSource.indexOf('await AppBootstrap.initialize();');
      final runAppIndex = mainSource.indexOf('runApp(', initIndex);
      expect(initIndex, greaterThan(-1));
      expect(runAppIndex, greaterThan(initIndex));
    });

    test('main.dart no longer contains any Firebase/Hive/DI '
        'initialization calls directly — they all moved into '
        'AppBootstrap', () {
      expect(mainSource.contains('Firebase.initializeApp'), isFalse);
      expect(mainSource.contains('FirebaseAppCheck'), isFalse);
      expect(mainSource.contains('Hive.initFlutter'), isFalse);
      expect(mainSource.contains('Hive.registerAdapter'), isFalse);
      expect(mainSource.contains('Hive.openBox'), isFalse);
      expect(mainSource.contains('initAuth()'), isFalse);
    });
  });

  group('AppBootstrap.initialize() preserves the exact original order', () {
    test('WidgetsFlutterBinding.ensureInitialized() is the first '
        'statement in initialize(), before any await', () {
      final initializeStart = bootstrapSource.indexOf(
        'static Future<void> initialize()',
      );
      final bindingIndex = bootstrapSource.indexOf(
        'WidgetsFlutterBinding.ensureInitialized()',
        initializeStart,
      );
      final firstAwaitIndex = bootstrapSource.indexOf(
        'await ',
        initializeStart,
      );
      expect(initializeStart, greaterThan(-1));
      expect(bindingIndex, greaterThan(initializeStart));
      expect(bindingIndex, lessThan(firstAwaitIndex));
    });

    test('initialize() calls _initializeFirebase, then '
        '_initializeDependencies, then _initializeStorage, in that '
        'order', () {
      final initializeStart = bootstrapSource.indexOf(
        'static Future<void> initialize()',
      );
      final initializeEnd = bootstrapSource.indexOf(
        'static Future<void> _initializeFirebase',
      );
      final body = bootstrapSource.substring(initializeStart, initializeEnd);

      final firebaseCallIndex = body.indexOf('_initializeFirebase()');
      final dependenciesCallIndex = body.indexOf('_initializeDependencies()');
      final storageCallIndex = body.indexOf('_initializeStorage()');

      expect(firebaseCallIndex, greaterThan(-1));
      expect(dependenciesCallIndex, greaterThan(firebaseCallIndex));
      expect(storageCallIndex, greaterThan(dependenciesCallIndex));
    });

    test('_initializeFirebase calls Firebase.initializeApp before '
        'FirebaseAppCheck.instance.activate', () {
      final start = bootstrapSource.indexOf(
        'static Future<void> _initializeFirebase()',
      );
      final end = bootstrapSource.indexOf(
        'static void _initializeDependencies()',
      );
      final body = bootstrapSource.substring(start, end);

      final firebaseInitIndex = body.indexOf('Firebase.initializeApp(');
      final appCheckIndex = body.indexOf('FirebaseAppCheck.instance.activate(');
      expect(firebaseInitIndex, greaterThan(-1));
      expect(appCheckIndex, greaterThan(firebaseInitIndex));
    });

    test('_initializeDependencies calls exactly the same 16 init '
        'functions, in the same order, as before this stage — nothing '
        'added, nothing removed, nothing reordered', () {
      final start = bootstrapSource.indexOf(
        'static void _initializeDependencies()',
      );
      final end = bootstrapSource.indexOf(
        'static Future<void> _initializeStorage()',
      );
      final body = bootstrapSource.substring(start, end);

      const expectedOrder = [
        'initCore()',
        'initAuth()',
        'initWorkout()',
        'initMeasurements()',
        'initProgressPhotos()',
        'initWorkoutPrograms()',
        'initWorkoutTemplates()',
        'initWorkoutCascadeDeletion()',
        'initWorkoutSessions()',
        'initSessionExercises()',
        'initWorkoutHistory()',
        'initProgramAnalytics()',
        'initProgramOverview()',
        'initRestTimer()',
        'initProgramConsistency()',
        'initHomeWorkoutOverview()',
      ];

      // Exactly 16 calls, confirmed by an exact-count assertion — not
      // just "at least these" — so a silently added/removed call fails
      // this test.
      final totalCallCount = RegExp(
        r'init[A-Za-z]+\(\);',
      ).allMatches(body).length;
      expect(totalCallCount, expectedOrder.length);

      var searchFrom = 0;
      for (final call in expectedOrder) {
        final index = body.indexOf(call, searchFrom);
        expect(
          index,
          greaterThanOrEqualTo(searchFrom),
          reason: '$call missing or out of order',
        );
        searchFrom = index + call.length;
      }
    });

    test('_initializeStorage calls Hive.initFlutter, then '
        'registerHiveAdapters, then Hive.openBox(\'authBox\'), in that '
        'order', () {
      final start = bootstrapSource.indexOf(
        'static Future<void> _initializeStorage()',
      );
      final end = bootstrapSource.indexOf('@visibleForTesting');
      final body = bootstrapSource.substring(start, end);

      final initFlutterIndex = body.indexOf('Hive.initFlutter()');
      final registerAdaptersIndex = body.indexOf('registerHiveAdapters()');
      final openBoxIndex = body.indexOf("Hive.openBox('authBox')");

      expect(initFlutterIndex, greaterThan(-1));
      expect(registerAdaptersIndex, greaterThan(initFlutterIndex));
      expect(openBoxIndex, greaterThan(registerAdaptersIndex));
    });

    test('registerHiveAdapters preserves all 6 typeIds (0–5) and their '
        'guards exactly, mapped to the same adapter classes as before', () {
      final start = bootstrapSource.indexOf(
        'static void registerHiveAdapters()',
      );
      final body = bootstrapSource.substring(start);

      const expected = {
        0: 'ExerciseSetAdapter',
        1: 'WorkoutProgramAdapter',
        2: 'BodyMeasurementAdapter',
        3: 'ProgressPhotoAdapter',
        4: 'WorkoutTemplateAdapter',
        5: 'WorkoutSessionAdapter',
      };

      expected.forEach((typeId, adapterClass) {
        expect(
          RegExp(
            'if \\(!Hive\\.isAdapterRegistered\\($typeId\\)\\) \\{\\s*'
            'Hive\\.registerAdapter\\($adapterClass\\(\\)\\);',
          ).hasMatch(body),
          isTrue,
          reason: 'typeId $typeId ($adapterClass) guard missing/changed',
        );
      });
    });
  });

  group('registerHiveAdapters is the only intentionally-exposed '
      'bootstrap internal', () {
    test('exactly one @visibleForTesting annotation exists in '
        'AppBootstrap, immediately above registerHiveAdapters', () {
      final annotationCount = RegExp(
        '@visibleForTesting',
      ).allMatches(bootstrapSource).length;
      expect(annotationCount, 1);

      final annotationIndex = bootstrapSource.indexOf('@visibleForTesting');
      final nextLineIndex = bootstrapSource.indexOf('\n', annotationIndex) + 1;
      final nextDeclaration = bootstrapSource.substring(
        nextLineIndex,
        bootstrapSource.indexOf('\n', nextLineIndex),
      );
      expect(nextDeclaration.contains('registerHiveAdapters'), isTrue);
    });

    test('no broad try/catch was added around initialization — errors '
        'are never silently swallowed', () {
      expect(bootstrapSource.contains('try {'), isFalse);
      expect(bootstrapSource.contains('catch'), isFalse);
    });
  });
}
