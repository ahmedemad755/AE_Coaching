import 'dart:io';

import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/auth/data/models/body_measurement.dart';
import 'package:ae_coaching/core/storage/user_storage_manager.dart';
import 'package:ae_coaching/features/progress_photos/data/models/progress_photo.dart';
import 'package:ae_coaching/features/workout/data/models/workout_program.dart';
import 'package:ae_coaching/features/workout/data/models/workout_session.dart';
import 'package:ae_coaching/features/workout/data/models/workout_template.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// UNIT TIER — real, disposable Hive instances (`Hive.init(tempDir)`,
/// never `initFlutter`), mirroring the exact pattern already used by
/// `workout_program_repository_test.dart` and friends. Never touches a
/// production Hive directory, never deletes real user data.
void main() {
  late Directory tempDir;
  late UserStorageManager manager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'user_storage_manager_test_',
    );
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ExerciseSetAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WorkoutProgramAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(BodyMeasurementAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ProgressPhotoAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(WorkoutTemplateAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(WorkoutSessionAdapter());
    }
    manager = UserStorageManager();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('validation happens before Hive is ever touched', () {
    test('unknown prefix is rejected deterministically, before any Hive '
        'access', () async {
      expect(
        () => manager.getUserBox<WorkoutProgram>('not_a_real_prefix', 'uid-1'),
        throwsArgumentError,
      );
      // No box for this made-up name was ever created.
      expect(Hive.isBoxOpen('not_a_real_prefix_uid-1'), isFalse);
    });

    test('a known prefix requested with the wrong T is rejected '
        'deterministically, before any Hive access', () async {
      expect(
        // 'workout_programs' expects WorkoutProgram, not ExerciseSet.
        () => manager.getUserBox<ExerciseSet>('workout_programs', 'uid-1'),
        throwsArgumentError,
      );
      expect(Hive.isBoxOpen('workout_programs_uid-1'), isFalse);
    });

    test('empty uid is rejected deterministically, before any Hive '
        'access', () async {
      expect(
        () => manager.getUserBox<WorkoutProgram>('workout_programs', ''),
        throwsArgumentError,
      );
      expect(Hive.isBoxOpen('workout_programs_'), isFalse);
    });

    test('all six production prefix/type mappings are accepted', () async {
      final sets = await manager.getUserBox<ExerciseSet>('sets', 'uid-a');
      final programs = await manager.getUserBox<WorkoutProgram>(
        'workout_programs',
        'uid-a',
      );
      final templates = await manager.getUserBox<WorkoutTemplate>(
        'workout_templates',
        'uid-a',
      );
      final sessions = await manager.getUserBox<WorkoutSession>(
        'workout_sessions',
        'uid-a',
      );
      final measurements = await manager.getUserBox<BodyMeasurement>(
        'measurements',
        'uid-a',
      );
      final photos = await manager.getUserBox<ProgressPhoto>(
        'progress_photos',
        'uid-a',
      );

      expect(sets.isOpen, isTrue);
      expect(programs.isOpen, isTrue);
      expect(templates.isOpen, isTrue);
      expect(sessions.isOpen, isTrue);
      expect(measurements.isOpen, isTrue);
      expect(photos.isOpen, isTrue);
    });
  });

  group('existing box-name formulas remain byte-identical', () {
    test('boxNameFor matches every real production prefix exactly', () {
      expect(UserStorageManager.boxNameFor('sets', 'u1'), 'sets_u1');
      expect(
        UserStorageManager.boxNameFor('workout_programs', 'u1'),
        'workout_programs_u1',
      );
      expect(
        UserStorageManager.boxNameFor('workout_templates', 'u1'),
        'workout_templates_u1',
      );
      expect(
        UserStorageManager.boxNameFor('workout_sessions', 'u1'),
        'workout_sessions_u1',
      );
      expect(
        UserStorageManager.boxNameFor('measurements', 'u1'),
        'measurements_u1',
      );
      expect(
        UserStorageManager.boxNameFor('progress_photos', 'u1'),
        'progress_photos_u1',
      );
    });
  });

  group('concurrent open deduplication', () {
    test('two concurrent getUserBox calls for the same uid/prefix/type '
        'share one in-flight open and resolve to the same instance', () async {
      final results = await Future.wait([
        manager.getUserBox<WorkoutProgram>('workout_programs', 'uid-b'),
        manager.getUserBox<WorkoutProgram>('workout_programs', 'uid-b'),
      ]);
      expect(identical(results[0], results[1]), isTrue);
    });
  });

  group('isolation', () {
    test('different uids never share a box — writing to one is '
        'invisible in the other', () async {
      final boxA = await manager.getUserBox<WorkoutProgram>(
        'workout_programs',
        'uid-A',
      );
      final boxB = await manager.getUserBox<WorkoutProgram>(
        'workout_programs',
        'uid-B',
      );
      expect(identical(boxA, boxB), isFalse);

      await boxA.put(
        'p1',
        WorkoutProgram(
          id: 'p1',
          name: 'Push',
          isActive: false,
          createdAt: DateTime(2024),
        ),
      );
      expect(boxA.containsKey('p1'), isTrue);
      expect(boxB.containsKey('p1'), isFalse);
    });

    test('different prefixes for the same uid never share a box', () async {
      final programs = await manager.getUserBox<WorkoutProgram>(
        'workout_programs',
        'uid-C',
      );
      final templates = await manager.getUserBox<WorkoutTemplate>(
        'workout_templates',
        'uid-C',
      );
      expect(programs.name, isNot(templates.name));
    });
  });

  group('closeForUser', () {
    test('closes all and only the boxes belonging to uid A — uid B\'s '
        'boxes are untouched', () async {
      // Open all 6 prefixes for A and B.
      Future<void> openAllFor(String uid) async {
        await manager.getUserBox<ExerciseSet>('sets', uid);
        await manager.getUserBox<WorkoutProgram>('workout_programs', uid);
        await manager.getUserBox<WorkoutTemplate>('workout_templates', uid);
        await manager.getUserBox<WorkoutSession>('workout_sessions', uid);
        await manager.getUserBox<BodyMeasurement>('measurements', uid);
        await manager.getUserBox<ProgressPhoto>('progress_photos', uid);
      }

      await openAllFor('uid-close-A');
      await openAllFor('uid-close-B');

      await manager.closeForUser('uid-close-A');

      for (final prefix in UserStorageManager.supportedBoxes.keys) {
        expect(
          Hive.isBoxOpen(UserStorageManager.boxNameFor(prefix, 'uid-close-A')),
          isFalse,
          reason: '$prefix for A should be closed',
        );
        expect(
          Hive.isBoxOpen(UserStorageManager.boxNameFor(prefix, 'uid-close-B')),
          isTrue,
          reason: '$prefix for B should remain open',
        );
      }
    });

    test('authBox and other global boxes are never touched by '
        'closeForUser', () async {
      // Simulate the real global authBox by opening a box with that
      // exact name directly (outside the manager, as AppBootstrap
      // does).
      final authBox = await Hive.openBox('authBox');
      await manager.getUserBox<WorkoutProgram>('workout_programs', 'uid-D');

      await manager.closeForUser('uid-D');

      expect(authBox.isOpen, isTrue);
      expect(Hive.isBoxOpen('authBox'), isTrue);
    });

    test('reopening a previously closed user box retains its stored '
        'data — closing never deletes', () async {
      final box = await manager.getUserBox<WorkoutProgram>(
        'workout_programs',
        'uid-E',
      );
      await box.put(
        'p1',
        WorkoutProgram(
          id: 'p1',
          name: 'Pull',
          isActive: true,
          createdAt: DateTime(2024),
        ),
      );

      await manager.closeForUser('uid-E');

      final reopened = await manager.getUserBox<WorkoutProgram>(
        'workout_programs',
        'uid-E',
      );
      expect(reopened.get('p1')?.name, 'Pull');
    });

    test('closeForUser is idempotent — calling it again after success '
        'is a harmless no-op', () async {
      await manager.getUserBox<WorkoutProgram>('workout_programs', 'uid-F');
      await manager.closeForUser('uid-F');
      await manager.closeForUser('uid-F'); // must not throw
    });
  });

  group('in-flight open vs closeForUser race', () {
    test('an open started just before closeForUser is awaited by the '
        'close, and the box ends up closed — not left open', () async {
      final openFuture = manager.getUserBox<WorkoutProgram>(
        'workout_programs',
        'uid-G',
      );
      final closeFuture = manager.closeForUser('uid-G');

      await openFuture;
      await closeFuture;

      expect(Hive.isBoxOpen('workout_programs_uid-G'), isFalse);
    });

    test('a new open request for a uid whose close is already in '
        'flight is rejected outright (not queued)', () async {
      await manager.getUserBox<WorkoutProgram>('workout_programs', 'uid-H');
      final closeFuture = manager.closeForUser('uid-H');

      expect(
        () => manager.getUserBox<WorkoutProgram>('workout_programs', 'uid-H'),
        throwsStateError,
      );

      await closeFuture;
    });
  });

  group('mutable uid source switching (A -> B)', () {
    test('a caller whose uid source changes between calls resolves a '
        'different box the next time', () async {
      String currentUid = 'uid-I';
      final box1 = UserBox<WorkoutProgram>(
        manager: manager,
        prefix: 'workout_programs',
        uidOverride: () => currentUid,
      );

      final first = await box1.getUserBox();
      currentUid = 'uid-J';
      final second = await box1.getUserBox();

      expect(identical(first, second), isFalse);
    });
  });

  group('no stale manager entries after repeated user switching', () {
    test('opening and closing a sequence of uids leaves no residual '
        'tracked state', () async {
      for (final uid in ['uid-K1', 'uid-K2', 'uid-K3']) {
        await manager.getUserBox<WorkoutProgram>('workout_programs', uid);
        await manager.closeForUser(uid);
      }

      expect(manager.ownedBoxNamesForTesting, isEmpty);
      expect(manager.inFlightOpenCountForTesting, 0);
    });
  });

  group('close continues past one box in an unusual state', () {
    // Honest note: Hive's public Box API does not offer a reliable,
    // documented way to force box.close() itself to throw (close() on
    // an already-closed box is a defined no-op, guarded by the
    // manager's own `box.isOpen` check before calling close()). This
    // test instead exercises the real, reachable "unusual state" case —
    // a box the manager still thinks it owns was already closed by
    // something outside its knowledge — and proves that does NOT abort
    // the rest of the closeForUser loop for the other boxes. The
    // aggregated-exception/retry-tracking code path for a genuine
    // thrown close() error is covered by direct code review (see
    // UserStorageManager._closeForUser's try/catch), not by a test that
    // could only fake the failure rather than provoke a real one — the
    // Stage 3 report states this limitation explicitly rather than
    // claiming coverage that doesn't exist.
    test('an already-externally-closed box does not stop the remaining '
        'boxes for that uid from being closed', () async {
      const uid = 'uid-L';

      final programsBox = await manager.getUserBox<WorkoutProgram>(
        'workout_programs',
        uid,
      );
      await manager.getUserBox<WorkoutTemplate>('workout_templates', uid);

      // Closed out from under the manager — Hive now disagrees with
      // the manager's own ownership record for this one box.
      await programsBox.close();

      await manager.closeForUser(uid);

      expect(Hive.isBoxOpen('workout_templates_$uid'), isFalse);
    });

    test('closeForUser is safe to call again after a previous run — '
        'idempotent, completes cleanly, no stale ownership entries '
        'remain', () async {
      const uid = 'uid-M';
      await manager.getUserBox<WorkoutProgram>('workout_programs', uid);
      await manager.getUserBox<WorkoutTemplate>('workout_templates', uid);

      await manager.closeForUser(uid);
      await manager.closeForUser(uid); // retry after success

      expect(Hive.isBoxOpen('workout_programs_$uid'), isFalse);
      expect(Hive.isBoxOpen('workout_templates_$uid'), isFalse);
      expect(manager.ownedBoxNamesForTesting, isEmpty);
    });
  });

  group('failed opens do not poison future retries', () {
    test('after a rejected open (unknown prefix), a valid open for the '
        'same uid still succeeds normally', () async {
      expect(
        () => manager.getUserBox<WorkoutProgram>('nope', 'uid-N'),
        throwsArgumentError,
      );

      final box = await manager.getUserBox<WorkoutProgram>(
        'workout_programs',
        'uid-N',
      );
      expect(box.isOpen, isTrue);
      expect(manager.inFlightOpenCountForTesting, 0);
    });
  });
}
