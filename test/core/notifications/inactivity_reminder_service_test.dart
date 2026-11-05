import 'dart:async';
import 'dart:io';

import 'package:ae_coaching/core/notifications/inactivity_reminder_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeLocalNotificationScheduler implements LocalNotificationScheduler {
  final Map<int, DateTime> pending = {};
  final List<({int id, String title, String body, DateTime scheduledAt})>
  scheduled = [];
  VoidCallback? onReminderTapped;
  bool failNextSchedule = false;

  @override
  Future<void> initialize({required VoidCallback onReminderTapped}) async {
    this.onReminderTapped = onReminderTapped;
  }

  @override
  Future<bool> hasPendingNotification(int id) async => pending.containsKey(id);

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    if (failNextSchedule) {
      failNextSchedule = false;
      throw StateError('temporary scheduler failure');
    }
    pending[id] = scheduledAt;
    scheduled.add((id: id, title: title, body: body, scheduledAt: scheduledAt));
  }

  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box box;
  late _FakeLocalNotificationScheduler scheduler;
  late DateTime now;
  late String? currentUid;
  late InactivityReminderService service;

  Future<InactivityReminderService> createService() async {
    final instance = InactivityReminderService(
      currentUid: () => currentUid,
      localBox: box,
      scheduler: scheduler,
      clock: () => now,
      authChanges: const Stream<String?>.empty(),
    );
    await instance.initialize();
    return instance;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('local_reminder_test_');
    Hive.init(tempDir.path);
    box = await Hive.openBox('authBox');
    scheduler = _FakeLocalNotificationScheduler();
    now = DateTime.utc(2026, 10, 18, 8);
    currentUid = 'user-a';
    service = await createService();
  });

  tearDown(() async {
    await service.dispose();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'successful workout schedules once for exactly three full days later',
    () async {
      final completedAt = DateTime.utc(2026, 10, 17, 12, 30);
      await service.onWorkoutCompleted(
        uid: 'user-a',
        sessionId: 'session-1',
        completedAt: completedAt,
      );

      expect(scheduler.scheduled, hasLength(1));
      expect(
        scheduler.scheduled.single.scheduledAt,
        completedAt.add(InactivityReminderService.reminderDelay),
      );
      expect(scheduler.scheduled.single.title, 'وقت الرجوع للتمرين 💪');
      expect(
        scheduler.scheduled.single.body,
        'بقالك 3 أيام من غير تمرين. يلا نرجع تاني.',
      );
      expect(
        box.get(InactivityReminderService.enabledKeyForUid('user-a')),
        isNull,
      );
      expect(
        box.get(InactivityReminderService.cycleIdKeyForUid('user-a')),
        'session-1',
      );
    },
  );

  test('same completed session is idempotent', () async {
    final completedAt = DateTime.utc(2026, 10, 17);
    await service.onWorkoutCompleted(
      uid: 'user-a',
      sessionId: 'session-1',
      completedAt: completedAt,
    );
    await service.onWorkoutCompleted(
      uid: 'user-a',
      sessionId: 'session-1',
      completedAt: completedAt,
    );

    expect(scheduler.scheduled, hasLength(1));
  });

  test('an open preference stream follows account changes and logout', () async {
    final changes = StreamController<String?>.broadcast();
    final watchedService = InactivityReminderService(
      currentUid: () => currentUid,
      localBox: box,
      scheduler: scheduler,
      authChanges: changes.stream,
    );
    await box.put(InactivityReminderService.enabledKeyForUid('user-b'), false);
    final values = <bool>[];
    final subscription = watchedService.watch().listen(values.add);
    addTearDown(() async {
      await subscription.cancel();
      await watchedService.dispose();
      await changes.close();
    });
    await Future<void>.delayed(Duration.zero);
    expect(values, [true]);

    currentUid = 'user-b';
    changes.add(currentUid);
    await Future<void>.delayed(Duration.zero);
    expect(values.last, isFalse);

    final beforeOutgoingWrite = values.length;
    await box.put(InactivityReminderService.enabledKeyForUid('user-a'), false);
    await Future<void>.delayed(Duration.zero);
    expect(values.length, beforeOutgoingWrite);
    await box.put(InactivityReminderService.enabledKeyForUid('user-b'), true);
    await Future<void>.delayed(Duration.zero);
    expect(values.last, isTrue);

    currentUid = null;
    changes.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(values.last, isTrue);
    currentUid = 'user-b';
    changes.add(currentUid);
    await Future<void>.delayed(Duration.zero);
    await box.put(InactivityReminderService.enabledKeyForUid('user-b'), false);
    await Future<void>.delayed(Duration.zero);
    expect(values.last, isFalse);
  });

  test('English content follows the saved app language', () async {
    await service.syncLanguage('en');
    await service.onWorkoutCompleted(
      uid: 'user-a',
      sessionId: 'session-english',
      completedAt: now,
    );

    expect(scheduler.scheduled.single.title, 'Time to get back 💪');
    expect(
      scheduler.scheduled.single.body,
      "You haven't trained in 3 days. Let's get back on track.",
    );
  });

  test('new completion replaces the previous cycle reminder', () async {
    await service.onWorkoutCompleted(
      uid: 'user-a',
      sessionId: 'session-1',
      completedAt: DateTime.utc(2026, 10, 17),
    );
    final newCompletedAt = DateTime.utc(2026, 10, 18, 7);
    await service.onWorkoutCompleted(
      uid: 'user-a',
      sessionId: 'session-2',
      completedAt: newCompletedAt,
    );

    expect(scheduler.scheduled, hasLength(2));
    expect(
      scheduler.pending[InactivityReminderService.notificationId],
      newCompletedAt.add(InactivityReminderService.reminderDelay),
    );
  });

  test(
    'preference is per user, defaults on, and disabling cancels reminder',
    () async {
      expect(service.isEnabledFor('user-a'), isTrue);
      expect(service.isEnabledFor('user-b'), isTrue);
      await service.setEnabled(false);
      expect(service.isEnabledFor('user-a'), isFalse);
      expect(service.isEnabledFor('user-b'), isTrue);

      await service.onWorkoutCompleted(
        uid: 'user-a',
        sessionId: 'session-1',
        completedAt: DateTime.utc(2026, 10, 17),
      );
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.pending, isEmpty);
    },
  );

  test(
    're-enabling after a cancelled reminder keeps the original cycle',
    () async {
      final completedAt = now;
      await service.onWorkoutCompleted(
        uid: 'user-a',
        sessionId: 'session-1',
        completedAt: completedAt,
      );
      await service.setEnabled(false);

      expect(scheduler.pending, isEmpty);
      expect(
        box.get(InactivityReminderService.scheduledCycleIdKeyForUid('user-a')),
        isNull,
      );

      now = completedAt.add(const Duration(days: 4));
      await service.setEnabled(true);

      expect(
        box.get(InactivityReminderService.completedAtKeyForUid('user-a')),
        completedAt.millisecondsSinceEpoch,
      );
      expect(
        scheduler.pending[InactivityReminderService.notificationId],
        now.add(const Duration(minutes: 1)),
      );
    },
  );

  test('re-enabling does not resend a reminder already delivered', () async {
    final completedAt = now.subtract(const Duration(days: 4));
    await service.onWorkoutCompleted(
      uid: 'user-a',
      sessionId: 'session-1',
      completedAt: completedAt,
    );
    scheduler.pending.remove(InactivityReminderService.notificationId);

    await service.setEnabled(false);
    await service.setEnabled(true);

    expect(scheduler.scheduled, hasLength(1));
    expect(scheduler.pending, isEmpty);
  });

  test(
    're-enabling without a completed workout does not invent a cycle',
    () async {
      await service.setEnabled(false);
      await service.setEnabled(true);

      expect(scheduler.scheduled, isEmpty);
      expect(
        box.get(InactivityReminderService.completedAtKeyForUid('user-a')),
        isNull,
      );
    },
  );

  test('a failed schedule leaves the workout cycle retryable', () async {
    scheduler.failNextSchedule = true;
    await expectLater(
      service.onWorkoutCompleted(
        uid: 'user-a',
        sessionId: 'session-1',
        completedAt: DateTime.utc(2026, 10, 17),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      box.get(InactivityReminderService.scheduledCycleIdKeyForUid('user-a')),
      isNull,
    );

    await service.reconcile();
    expect(scheduler.scheduled, hasLength(1));
  });

  test('reopening the service keeps the existing pending reminder', () async {
    await service.onWorkoutCompleted(
      uid: 'user-a',
      sessionId: 'session-1',
      completedAt: DateTime.utc(2026, 10, 17),
    );

    await service.dispose();
    await box.close();
    box = await Hive.openBox('authBox');
    service = await createService();
    await service.reconcile();

    expect(scheduler.scheduled, hasLength(1));
  });

  test('local preference survives closing and reopening Hive', () async {
    await service.setEnabled(false);
    await service.dispose();
    await box.close();
    box = await Hive.openBox('authBox');
    service = await createService();

    expect(service.isEnabledFor('user-a'), isFalse);
    expect(service.isEnabledFor('user-b'), isTrue);
  });

  test(
    'account change does not mutate another user\'s reminder state',
    () async {
      await service.onWorkoutCompleted(
        uid: 'user-a',
        sessionId: 'session-a',
        completedAt: DateTime.utc(2026, 10, 17),
      );
      currentUid = 'user-b';
      await service.onWorkoutCompleted(
        uid: 'user-b',
        sessionId: 'session-b',
        completedAt: DateTime.utc(2026, 10, 18),
      );

      expect(
        box.get(InactivityReminderService.cycleIdKeyForUid('user-a')),
        'session-a',
      );
      expect(
        box.get(InactivityReminderService.cycleIdKeyForUid('user-b')),
        'session-b',
      );
      expect(
        scheduler.pending[InactivityReminderService.notificationId],
        DateTime.utc(2026, 10, 18).add(InactivityReminderService.reminderDelay),
      );
    },
  );

  test('expired unseen cycle schedules one near-immediate reminder', () async {
    await service.onWorkoutCompleted(
      uid: 'user-a',
      sessionId: 'session-old',
      completedAt: DateTime.utc(2026, 10, 10),
    );

    expect(
      scheduler.pending[InactivityReminderService.notificationId],
      now.add(const Duration(minutes: 1)),
    );
    await service.reconcile();
    expect(scheduler.scheduled, hasLength(1));
  });
}
