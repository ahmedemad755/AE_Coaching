import 'dart:math' as math;

/// "05:07", or "1:05:07" from an hour. Never negative (a clock moved back
/// shows 00:00, not "-1:-5").
String formatTimerClock(int seconds) {
  final safe = math.max(0, seconds);
  final hours = safe ~/ 3600;
  final mm = (safe ~/ 60 % 60).toString().padLeft(2, '0');
  final ss = (safe % 60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}
