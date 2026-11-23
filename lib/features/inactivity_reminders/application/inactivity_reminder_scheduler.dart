import 'dart:async';

import 'package:ae_coaching/core/notifications/local_notifications.dart';
import 'package:ae_coaching/features/inactivity_reminders/data/workout_activity_reader.dart';
import 'package:ae_coaching/features/inactivity_reminders/domain/inactivity_reminder_plan.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences.dart';
import 'package:ae_coaching/features/notification_settings/domain/notification_preferences_repository.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;

/// Schedules the inactivity reminders of the signed-in account as LOCAL
/// notifications (Firebase Spark plan: server delivery stays disabled).
///
/// Always "cancel everything, then schedule the plan" over one fixed id
/// range, serialized, so reminders are never duplicated and a previous
/// account's reminders never survive an account change. Recomputed on:
/// session start ([activate]), workout activity changes (sets/sessions
/// added, edited or deleted), the reminder toggle, the app language, app
/// resume (time-zone and permission changes) and app start.
class InactivityReminderScheduler with WidgetsBindingObserver {
  InactivityReminderScheduler({
    required LocalNotificationsGateway notifications,
    required WorkoutActivityReader activity,
    required NotificationPreferencesRepository preferences,
    required Future<bool> Function() notificationsAllowed,
    required Future<tz.Location> Function() location,
    required String Function() languageCode,
    required bool Function(String uid) deletionPending,
    required Box authBox,
    DateTime Function()? clock,
    bool observeLifecycle = true,
  }) : _notifications = notifications,
       _activity = activity,
       _preferences = preferences,
       _notificationsAllowed = notificationsAllowed,
       _location = location,
       _languageCode = languageCode,
       _deletionPending = deletionPending,
       _authBox = authBox,
       _clock = clock ?? DateTime.now,
       _observeLifecycle = observeLifecycle;

  /// Ids [firstId, firstId + maxScheduled): reserved for these reminders
  /// (the retired reminder used 7301).
  static const firstId = 7401;
  static const payload = 'inactivity_reminder';

  /// Which account the scheduled reminders belong to (survives restarts).
  static const ownerKey = 'localInactivityReminderOwner';

  final LocalNotificationsGateway _notifications;
  final WorkoutActivityReader _activity;
  final NotificationPreferencesRepository _preferences;
  final Future<bool> Function() _notificationsAllowed;
  final Future<tz.Location> Function() _location;
  final String Function() _languageCode;
  final bool Function(String uid) _deletionPending;
  final Box _authBox;
  final DateTime Function() _clock;
  final bool _observeLifecycle;

  String? _uid;
  bool _enabled = NotificationPreferences.defaults.inactivityRemindersEnabled;
  StreamSubscription<void>? _activitySubscription;
  StreamSubscription<StoredNotificationPreferences>? _preferencesSubscription;
  bool _observing = false;
  Future<void> _queue = Future<void>.value();

  String? get activeUid => _uid;

  /// Starts scheduling for [uid] (session start or account switch).
  Future<void> activate(String uid) async {
    if (_uid == uid) return refresh();
    await deactivate();
    _uid = uid;
    _enabled = NotificationPreferences.defaults.inactivityRemindersEnabled;
    _preferencesSubscription = _preferences.watch(uid).listen(
      (stored) {
        _enabled = stored.preferences.inactivityRemindersEnabled;
        unawaited(refresh());
      },
      // Unreadable preference (offline first run, rules not deployed): keep
      // the default; the toggle takes effect once it can be read.
      onError: (Object error) => debugPrint('Reminder preference unavailable: $error'),
    );
    _activitySubscription = _activity.changes(uid).listen(
      (_) => unawaited(refresh()),
      onError: (Object error) => debugPrint('Workout activity watch failed: $error'),
    );
    if (_observeLifecycle && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    await refresh();
  }

  /// Recomputes the plan for the active account. Never throws.
  Future<void> refresh() => _serialized(_reschedule);

  /// Stops and cancels everything (logout, account deletion). Never throws.
  Future<void> deactivate() async {
    _uid = null;
    final activity = _activitySubscription;
    final preferences = _preferencesSubscription;
    _activitySubscription = null;
    _preferencesSubscription = null;
    await activity?.cancel();
    await preferences?.cancel();
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    await _serialized(() async {
      await _cancelAll();
      await _authBox.delete(ownerKey);
    });
  }

  /// App start: reminders scheduled for an account that is no longer the
  /// signed-in one (e.g. the app was killed during logout) are cancelled.
  Future<void> reconcileAtStartup(String? signedInUid) => _serialized(() async {
    final owner = _authBox.get(ownerKey);
    if (owner is String && owner != signedInUid) {
      await _cancelAll();
      await _authBox.delete(ownerKey);
    }
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> _reschedule() async {
    final uid = _uid;
    if (uid == null) return;
    await _cancelAll();
    if (!_enabled || _deletionPending(uid) || !await _notificationsAllowed()) {
      await _authBox.delete(ownerKey);
      return;
    }
    final lastActivity = await _activity.latestActivity(uid);
    if (lastActivity == null || _uid != uid) return; // no workout history: nothing to remind
    final plan = planInactivityReminders(
      lastActivity: lastActivity,
      now: _clock(),
      location: await _location(),
    );
    final l10n = lookupAppLocalizations(Locale(_languageCode() == 'en' ? 'en' : 'ar'));
    final messages = _messages(l10n);
    for (var i = 0; i < plan.length; i += 1) {
      final message = messages[(plan[i].sequence - 1) % messages.length];
      await _notifications.schedule(
        id: firstId + i,
        title: message.$1,
        body: message.$2,
        at: plan[i].at,
        channel: AppNotificationChannels.inactivityReminders,
        payload: payload,
      );
    }
    await _authBox.put(ownerKey, uid);
  }

  Future<void> _cancelAll() async {
    for (var i = 0; i < InactivityReminderPolicy.maxScheduled; i += 1) {
      await _notifications.cancel(firstId + i);
    }
  }

  Future<void> _serialized(Future<void> Function() action) {
    final run = _queue.then((_) => action());
    _queue = run.catchError((Object error) => debugPrint('Inactivity reminder scheduling failed: $error'));
    return _queue;
  }

  static List<(String, String)> _messages(AppLocalizations l10n) => [
    (l10n.inactivityReminderTitle1, l10n.inactivityReminderBody1),
    (l10n.inactivityReminderTitle2, l10n.inactivityReminderBody2),
    (l10n.inactivityReminderTitle3, l10n.inactivityReminderBody3),
    (l10n.inactivityReminderTitle4, l10n.inactivityReminderBody4),
    (l10n.inactivityReminderTitle5, l10n.inactivityReminderBody5),
    (l10n.inactivityReminderTitle6, l10n.inactivityReminderBody6),
  ];
}
