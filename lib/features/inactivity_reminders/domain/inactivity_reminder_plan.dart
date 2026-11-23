import 'package:timezone/timezone.dart' as tz;

/// The approved inactivity cadence, scheduled on the device (Spark plan: no
/// server delivery). Same rules as the server policy
/// (functions/src/inactivity/domain/reminderPolicy.ts):
/// reminder 1 at 48 h after the latest workout activity, reminders 2–5
/// every 72 h after the previous one, then weekly; only between 10:00 and
/// 21:00 in the device's time zone (otherwise moved to the next 10:00).
abstract final class InactivityReminderPolicy {
  static const firstDelay = Duration(hours: 48);
  static const followUpDelay = Duration(hours: 72);
  static const followUps = 4;
  static const weeklyDelay = Duration(days: 7);
  static const windowStartHour = 10;
  static const windowEndHour = 21;

  /// Pending local notifications are limited (iOS keeps at most 64 per
  /// app), and the plan is recomputed whenever the app starts or resumes,
  /// so only the next few are scheduled: 6 cover the 48 h + 4 × 72 h
  /// sequence and the first weekly one.
  static const maxScheduled = 6;

  /// Never schedule further ahead than this (a stale plan is replaced at the
  /// next app start anyway).
  static const horizon = Duration(days: 45);

  static Duration delayBefore(int sequence) {
    if (sequence < 1) throw RangeError.value(sequence, 'sequence');
    if (sequence == 1) return firstDelay;
    if (sequence <= 1 + followUps) return followUpDelay;
    return weeklyDelay;
  }
}

class PlannedReminder {
  const PlannedReminder({required this.sequence, required this.at});

  /// 1-based position in the inactivity sequence since the last activity.
  final int sequence;
  final tz.TZDateTime at;

  @override
  bool operator ==(Object other) => other is PlannedReminder && other.sequence == sequence && other.at == at;

  @override
  int get hashCode => Object.hash(sequence, at);

  @override
  String toString() => 'PlannedReminder(#$sequence at $at)';
}

/// The first allowed moment at or after [instant], in [location].
tz.TZDateTime firstDeliverableAt(DateTime instant, tz.Location location) {
  final local = tz.TZDateTime.from(instant, location);
  if (local.hour < InactivityReminderPolicy.windowStartHour) {
    return tz.TZDateTime(location, local.year, local.month, local.day, InactivityReminderPolicy.windowStartHour);
  }
  if (local.hour >= InactivityReminderPolicy.windowEndHour) {
    return tz.TZDateTime(location, local.year, local.month, local.day + 1, InactivityReminderPolicy.windowStartHour);
  }
  return local;
}

/// The upcoming reminders after [lastActivity], as seen at [now]: each one
/// [InactivityReminderPolicy.delayBefore] after the previous one (the first
/// after the activity), moved out of quiet hours. Reminders whose time has
/// already passed are not delivered late; the sequence simply continues.
/// At most [maxScheduled], none beyond [horizon].
List<PlannedReminder> planInactivityReminders({
  required DateTime lastActivity,
  required DateTime now,
  required tz.Location location,
  int maxScheduled = InactivityReminderPolicy.maxScheduled,
  Duration horizon = InactivityReminderPolicy.horizon,
}) {
  final limit = now.add(horizon);
  final plan = <PlannedReminder>[];
  DateTime previous = lastActivity;
  for (var sequence = 1; plan.length < maxScheduled && sequence < 10000; sequence += 1) {
    final at = firstDeliverableAt(previous.add(InactivityReminderPolicy.delayBefore(sequence)), location);
    if (at.isAfter(limit)) break;
    if (at.isAfter(now)) plan.add(PlannedReminder(sequence: sequence, at: at));
    previous = at;
  }
  return plan;
}
