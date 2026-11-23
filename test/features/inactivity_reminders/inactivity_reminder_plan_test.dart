import 'package:ae_coaching/features/inactivity_reminders/domain/inactivity_reminder_plan.dart';
import 'package:ae_coaching/features/notification_settings/data/device_time_zone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location cairo;
  late tz.Location newYork;

  setUpAll(() {
    DeviceTimeZone.ensureDatabaseLoaded();
    cairo = tz.getLocation('Africa/Cairo');
    newYork = tz.getLocation('America/New_York');
  });

  /// Saturday 2026-11-07 18:00 in Cairo (UTC+2).
  final saturday18 = DateTime.utc(2026, 11, 7, 16);
  String weekdayHour(tz.TZDateTime at) => '${const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][at.weekday]} ${at.hour}:${at.minute.toString().padLeft(2, '0')}';

  test('48 h, then four 72 h follow-ups, then weekly (the approved example)', () {
    final plan = planInactivityReminders(lastActivity: saturday18, now: saturday18, location: cairo);
    expect(plan.map((r) => r.sequence), [1, 2, 3, 4, 5, 6]);
    expect(plan.map((r) => weekdayHour(r.at)), ['Mon 18:00', 'Thu 18:00', 'Sun 18:00', 'Wed 18:00', 'Sat 18:00', 'Sat 18:00']);
    expect(plan[0].at.difference(saturday18), const Duration(hours: 48));
    for (var i = 1; i < 5; i += 1) {
      expect(plan[i].at.difference(plan[i - 1].at), const Duration(hours: 72));
    }
    expect(plan[5].at.difference(plan[4].at), const Duration(days: 7));
  });

  test('quiet hours: nothing before 10:00 or from 21:00; moved to the next 10:00', () {
    final late = DateTime.utc(2026, 11, 7, 20, 30); // Sat 22:30 Cairo
    final plan = planInactivityReminders(lastActivity: late, now: late, location: cairo);
    expect(weekdayHour(plan[0].at), 'Tue 10:00'); // Mon 22:30 → Tue 10:00
    expect(weekdayHour(plan[1].at), 'Fri 10:00'); // 72 h after the actual reminder
    for (final reminder in plan) {
      expect(reminder.at.hour, inInclusiveRange(10, 20));
    }
    expect(firstDeliverableAt(DateTime.utc(2026, 11, 9, 7, 59), cairo).hour, 10); // 09:59 → 10:00
    expect(weekdayHour(firstDeliverableAt(DateTime.utc(2026, 11, 9, 18, 59), cairo)), 'Mon 20:59');
    expect(weekdayHour(firstDeliverableAt(DateTime.utc(2026, 11, 9, 19), cairo)), 'Tue 10:00'); // 21:00
  });

  test('time zones and DST: 48 h are absolute; the window follows local time', () {
    final fridayEst = DateTime.utc(2026, 3, 6, 23); // Fri 18:00 EST, DST starts Sun 02:00
    final plan = planInactivityReminders(lastActivity: fridayEst, now: fridayEst, location: newYork);
    expect(weekdayHour(plan[0].at), 'Sun 19:00'); // 18:00 EST + 48 h = 19:00 EDT
    expect(plan[0].at.timeZoneOffset, const Duration(hours: -4));
    // The same instant is quiet hours in one zone and deliverable in another.
    final instant = DateTime.utc(2026, 11, 9, 5); // 07:00 Cairo, 00:00 New York
    expect(firstDeliverableAt(instant, cairo).hour, 10);
    expect(firstDeliverableAt(instant, tz.getLocation('Asia/Tokyo')).hour, 14);
  });

  test('missed reminders are not delivered late; the sequence continues', () {
    final now = saturday18.add(const Duration(days: 6)); // after reminders 1 and 2
    final plan = planInactivityReminders(lastActivity: saturday18, now: now, location: cairo);
    expect(plan.first.sequence, 3);
    expect(plan.every((r) => r.at.isAfter(now)), isTrue);
  });

  test('bounded: at most 6 reminders and none beyond the horizon', () {
    final longAgo = saturday18.subtract(const Duration(days: 365));
    final plan = planInactivityReminders(lastActivity: longAgo, now: saturday18, location: cairo);
    expect(plan, hasLength(InactivityReminderPolicy.maxScheduled));
    expect(plan.every((r) => r.sequence > 5), isTrue); // weekly by now
    expect(plan.last.at.isBefore(saturday18.add(InactivityReminderPolicy.horizon)), isTrue);
    final short = planInactivityReminders(lastActivity: saturday18, now: saturday18, location: cairo, horizon: const Duration(days: 6));
    expect(short.map((r) => r.sequence), [1, 2]);
  });

  test('new workout activity restarts the sequence from it', () {
    final first = planInactivityReminders(lastActivity: saturday18, now: saturday18, location: cairo);
    final workoutAt = saturday18.add(const Duration(hours: 47));
    final after = planInactivityReminders(lastActivity: workoutAt, now: workoutAt, location: cairo);
    expect(after.first.sequence, 1);
    expect(after.first.at.difference(workoutAt), const Duration(hours: 48));
    expect(after.first.at.isAfter(first.first.at), isTrue);
  });

  test('delays by sequence', () {
    expect(InactivityReminderPolicy.delayBefore(1), const Duration(hours: 48));
    for (final n in [2, 3, 4, 5]) {
      expect(InactivityReminderPolicy.delayBefore(n), const Duration(hours: 72));
    }
    expect(InactivityReminderPolicy.delayBefore(6), const Duration(days: 7));
    expect(() => InactivityReminderPolicy.delayBefore(0), throwsRangeError);
  });
}
