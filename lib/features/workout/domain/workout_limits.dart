/// Technical limits of workout data, defined once.
///
/// [maxActivitiesPerDay] is also enforced by `firestore.rules`
/// (`activities.size() <= N` and the session snapshot); a test reads the
/// rules file and fails if the two ever disagree, so change both together.
abstract final class WorkoutLimits {
  /// Activities (strength, cardio, timed) in one workout day. Keeps a day
  /// document far below Firestore's 1 MiB limit (~0.4 KB per activity).
  static const int maxActivitiesPerDay = 40;
}
