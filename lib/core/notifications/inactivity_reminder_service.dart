import 'dart:async';

import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract interface class InactivityReminderRecorder {
  Future<void> onWorkoutCompleted({
    required String uid,
    required String sessionId,
    required DateTime completedAt,
  });
}

abstract interface class LocalNotificationScheduler {
  Future<void> initialize({required VoidCallback onReminderTapped});
  Future<bool> hasPendingNotification(int id);
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  });
  Future<void> cancel(int id);
}

class FlutterLocalNotificationScheduler implements LocalNotificationScheduler {
  FlutterLocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _payload = 'inactivity_reminder';

  @override
  Future<void> initialize({required VoidCallback onReminderTapped}) async {
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _payload) onReminderTapped();
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse?.payload == _payload) {
      onReminderTapped();
    }
  }

  @override
  Future<bool> hasPendingNotification(int id) async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((request) => request.id == id);
  }

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'inactivity_reminders',
          'Inactivity reminders',
          channelDescription: 'Reminders to return to your workout routine.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: _payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);
}

class InactivityReminderService
    with WidgetsBindingObserver
    implements InactivityReminderRecorder {
  InactivityReminderService({
    FirebaseAuth? auth,
    String? Function()? currentUid,
    Box? localBox,
    LocalNotificationScheduler? scheduler,
    DateTime Function()? clock,
    @visibleForTesting Stream<String?>? authChanges,
  }) : _auth = auth,
       _uidProvider = currentUid,
       _box = localBox,
       _scheduler = scheduler ?? FlutterLocalNotificationScheduler(),
       _clock = clock ?? DateTime.now,
       _authChanges = authChanges;

  static const reminderDelay = Duration(days: 3);
  static const notificationId = 7301;
  static const _activeNotificationOwnerKey = 'localInactivityNotificationUid';

  final FirebaseAuth? _auth;
  final String? Function()? _uidProvider;
  final Box? _box;
  final LocalNotificationScheduler _scheduler;
  final DateTime Function() _clock;
  final Stream<String?>? _authChanges;
  StreamSubscription<String?>? _authSubscription;
  Future<void> _queue = Future<void>.value();
  bool _initialized = false;
  String? _activeUid;
  bool _authResolved = false;

  Box get _localBox => _box ?? Hive.box('authBox');
  String? get _currentUid {
    if (_uidProvider != null) return _uidProvider();
    try {
      return (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  Stream<String?> get _userChanges {
    if (_authChanges != null) return _authChanges;
    try {
      return (_auth ?? FirebaseAuth.instance).authStateChanges().map(
        (user) => user?.uid,
      );
    } catch (_) {
      return const Stream<String?>.empty();
    }
  }

  static String enabledKeyForUid(String uid) =>
      'inactivityRemindersEnabled:$uid';
  static String languageKeyForUid(String uid) => 'inactivityLanguage:$uid';
  static String completedAtKeyForUid(String uid) =>
      'inactivityLastCompletedAt:$uid';
  static String cycleIdKeyForUid(String uid) => 'inactivityCycleId:$uid';
  static String scheduledCycleIdKeyForUid(String uid) =>
      'inactivityScheduledCycleId:$uid';

  bool isEnabledFor(String uid) =>
      _localBox.get(enabledKeyForUid(uid), defaultValue: true) as bool;

  bool get isEnabled {
    final uid = _currentUid;
    return uid == null || uid.isEmpty ? true : isEnabledFor(uid);
  }

  Stream<bool> watch() => Stream<bool>.multi((controller) {
    var uid = _currentUid;
    void emitPreference() {
      final owner = uid;
      controller.add(
        owner == null || owner.isEmpty ? true : isEnabledFor(owner),
      );
    }

    final preferences = _localBox.watch().listen((event) {
      if (uid != null &&
          uid == _currentUid &&
          event.key == enabledKeyForUid(uid!)) {
        emitPreference();
      }
    }, onError: controller.addError);
    final accounts = _userChanges.listen((nextUid) {
      uid = nextUid;
      emitPreference();
    }, onError: controller.addError);
    emitPreference();
    controller.onCancel = () async {
      await accounts.cancel();
      await preferences.cancel();
    };
  });

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    try {
      await _scheduler.initialize(
        onReminderTapped: AppRouter.openHomeFromNotification,
      );
      WidgetsBinding.instance.addObserver(this);
      _authSubscription = _userChanges.listen(
        (uid) => _enqueue(() => _handleAuthChange(uid)),
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Local inactivity reminder auth listener failed: $error');
        },
      );
      await _enqueue(() => _handleAuthChange(_currentUid));
    } catch (error, stackTrace) {
      _initialized = false;
      debugPrint(
        'Local inactivity reminder initialization failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) throw StateError('No authenticated user.');
    await _enqueue(() async {
      _requireCurrentOwner(uid);
      await _localBox.put(enabledKeyForUid(uid), enabled);
      if (enabled) {
        await _scheduleFromStoredState(uid);
      } else {
        await _cancelOwnedNotification(uid);
      }
    });
  }

  Future<void> reconcile() =>
      _enqueue(() => _scheduleFromStoredState(_currentUid));

  Future<void> syncLanguage(String languageCode) async {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) return;
    final language = languageCode.toLowerCase().split('-').first;
    if (language != 'ar' && language != 'en') return;
    await _enqueue(() async {
      if (_currentUid != uid) return;
      await _localBox.put(languageKeyForUid(uid), language);
      await _scheduleFromStoredState(uid, refreshPending: true);
    });
  }

  @override
  Future<void> onWorkoutCompleted({
    required String uid,
    required String sessionId,
    required DateTime completedAt,
  }) async {
    if (uid.isEmpty || sessionId.isEmpty || _currentUid != uid) return;
    await _enqueue(() async {
      if (_currentUid != uid) return;
      final cycleKey = cycleIdKeyForUid(uid);
      final lastCycleId = _localBox.get(cycleKey) as String?;
      final previousMillis = _localBox.get(completedAtKeyForUid(uid)) as int?;
      if (lastCycleId == sessionId &&
          previousMillis == completedAt.millisecondsSinceEpoch) {
        await _scheduleFromStoredState(uid);
        return;
      }

      final notificationOwner =
          _localBox.get(_activeNotificationOwnerKey) as String?;
      if (notificationOwner == null) {
        await _scheduler.cancel(notificationId);
      } else {
        await _cancelOwnedNotification(notificationOwner);
      }
      await _localBox.put(
        completedAtKeyForUid(uid),
        completedAt.millisecondsSinceEpoch,
      );
      await _localBox.put(cycleKey, sessionId);
      await _localBox.delete(scheduledCycleIdKeyForUid(uid));
      await _localBox.put(_activeNotificationOwnerKey, uid);
      _activeUid = uid;
      _authResolved = true;
      await _scheduleFromStoredState(uid);
    });
  }

  Future<void> cancelForLogout({required String expectedUid}) async {
    if (expectedUid.isEmpty || _currentUid != expectedUid) {
      throw StateError('Refusing to cancel another user\'s reminder.');
    }
    await _enqueue(() async {
      _requireCurrentOwner(expectedUid);
      await _cancelOwnedNotification(expectedUid);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      reconcile();
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _authSubscription?.cancel();
  }

  Future<void> _handleAuthChange(String? uid) async {
    final owner = _localBox.get(_activeNotificationOwnerKey) as String?;
    if (uid == null || uid.isEmpty) {
      if (owner != null) await _cancelOwnedNotification(owner);
      _activeUid = null;
      _authResolved = true;
      return;
    }

    if (_authResolved && _activeUid == uid) {
      await _scheduleFromStoredState(uid);
      return;
    }
    if (owner != null && owner != uid) {
      await _cancelOwnedNotification(owner);
    }
    _activeUid = uid;
    _authResolved = true;
    await _scheduleFromStoredState(uid);
  }

  Future<void> _scheduleFromStoredState(
    String? uid, {
    bool refreshPending = false,
  }) async {
    if (uid == null || uid.isEmpty || _currentUid != uid) return;
    final owner = _localBox.get(_activeNotificationOwnerKey) as String?;
    if (owner != null && owner != uid) {
      await _cancelOwnedNotification(owner);
    }

    if (!isEnabledFor(uid)) {
      await _cancelOwnedNotification(uid);
      return;
    }

    final completedAtMillis = _localBox.get(completedAtKeyForUid(uid)) as int?;
    final cycleId = _localBox.get(cycleIdKeyForUid(uid)) as String?;
    if (completedAtMillis == null || cycleId == null || cycleId.isEmpty) {
      await _cancelOwnedNotification(uid);
      return;
    }

    final previousScheduledCycle =
        _localBox.get(scheduledCycleIdKeyForUid(uid)) as String?;
    var hasPending = await _scheduler.hasPendingNotification(notificationId);
    var refreshedPending = false;
    if (hasPending && previousScheduledCycle == cycleId && refreshPending) {
      await _scheduler.cancel(notificationId);
      hasPending = false;
      refreshedPending = true;
    }
    if (hasPending && previousScheduledCycle == cycleId) {
      await _localBox.put(_activeNotificationOwnerKey, uid);
      return;
    }

    final dueAt = DateTime.fromMillisecondsSinceEpoch(
      completedAtMillis,
      isUtc: true,
    ).add(reminderDelay);
    final now = _clock().toUtc();
    if (previousScheduledCycle == cycleId &&
        !dueAt.isAfter(now) &&
        !refreshedPending) {
      return;
    }
    final scheduledAt = dueAt.isAfter(now)
        ? dueAt
        : now.add(const Duration(minutes: 1));
    final language =
        _localBox.get(languageKeyForUid(uid), defaultValue: 'ar') as String;
    final content = _contentForLanguage(language);
    await _scheduler.schedule(
      id: notificationId,
      title: content.$1,
      body: content.$2,
      scheduledAt: scheduledAt,
    );
    await _localBox.put(scheduledCycleIdKeyForUid(uid), cycleId);
    await _localBox.put(_activeNotificationOwnerKey, uid);
  }

  Future<void> _cancelOwnedNotification(String uid) async {
    if (_localBox.get(_activeNotificationOwnerKey) == uid) {
      final wasPending = await _scheduler.hasPendingNotification(
        notificationId,
      );
      await _scheduler.cancel(notificationId);
      if (wasPending) {
        await _localBox.delete(scheduledCycleIdKeyForUid(uid));
      }
      await _localBox.delete(_activeNotificationOwnerKey);
    }
  }

  void _requireCurrentOwner(String uid) {
    if (_currentUid != uid) {
      throw StateError('The authenticated user changed during this operation.');
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static (String, String) _contentForLanguage(String language) =>
      language == 'en'
      ? (
          'Time to get back 💪',
          "You haven't trained in 3 days. Let's get back on track.",
        )
      : ('وقت الرجوع للتمرين 💪', 'بقالك 3 أيام من غير تمرين. يلا نرجع تاني.');
}
