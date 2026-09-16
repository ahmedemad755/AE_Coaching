/// Monday 00:00 of the week containing [now]. `DateTime.weekday` is 1
/// (Monday) through 7 (Sunday), so subtracting `weekday - 1` days from
/// the date-only value always lands on that week's Monday.
///
/// Shared by every weekly/consistency analytics service in this
/// feature ([ProgramWeeklyOverviewService], [ProgramConsistencyService])
/// so "what week is this session in" is answered exactly once, the
/// same way everywhere.
DateTime startOfWeek(DateTime now) {
  final dateOnly = DateTime(now.year, now.month, now.day);
  return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
}
