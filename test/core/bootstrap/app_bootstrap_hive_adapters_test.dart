import 'dart:io';

import 'package:ae_coaching/core/bootstrap/app_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// REAL (non-source-regression) test for
/// `AppBootstrap.registerHiveAdapters()` — Firebase-independent, so
/// unlike the rest of `AppBootstrap.initialize()` this piece can be
/// exercised for real rather than only proven by reading source text.
///
/// Isolation: mirrors the exact pattern already used by
/// `workout_program_repository_test.dart` — a unique
/// `Directory.systemTemp.createTemp(...)` per test, `Hive.init` (not
/// `initFlutter`, which needs platform channels unavailable here)
/// against that directory, and `Hive.deleteFromDisk()` + an explicit
/// directory delete in `tearDown`. Adapter *registration* itself is
/// process/isolate-global Hive state (not per-directory) and Hive has
/// no "unregister" API, so this file deliberately never asserts a
/// typeId is NOT registered — only that registering (repeatedly) never
/// throws and every typeId ends up registered. `flutter test` runs each
/// test file in its own isolate, so this file's adapter registrations
/// cannot leak into any other test file's isolate.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'app_bootstrap_hive_adapters_test_',
    );
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('registers all 6 typeIds (0–5) with no exception', () {
    expect(AppBootstrap.registerHiveAdapters, returnsNormally);

    for (final typeId in [0, 1, 2, 3, 4, 5]) {
      expect(
        Hive.isAdapterRegistered(typeId),
        isTrue,
        reason: 'typeId $typeId should be registered',
      );
    }
  });

  test('calling registerHiveAdapters a second time is a harmless no-op '
      '— no "already registered" exception, and every typeId is still '
      'registered afterward', () {
    AppBootstrap.registerHiveAdapters();

    expect(AppBootstrap.registerHiveAdapters, returnsNormally);

    for (final typeId in [0, 1, 2, 3, 4, 5]) {
      expect(
        Hive.isAdapterRegistered(typeId),
        isTrue,
        reason:
            'typeId $typeId should still be registered after a '
            'second call',
      );
    }
  });

  test('calling it 3 times in a row (simulating repeated hot-restarts) '
      'never throws', () {
    AppBootstrap.registerHiveAdapters();
    AppBootstrap.registerHiveAdapters();
    expect(AppBootstrap.registerHiveAdapters, returnsNormally);
  });
}
