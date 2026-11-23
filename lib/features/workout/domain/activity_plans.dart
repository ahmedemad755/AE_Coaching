/// What kind of activity a workout-day entry is.
enum ActivityType {
  /// Sets × reps (with weight): every entry created before activities.
  strength,

  /// Duration / intervals (treadmill, bike, jump rope…).
  cardio,

  /// Sets of a held duration (plank, wall sit…).
  timed;

  static ActivityType parse(Object? value) => switch (value) {
    'cardio' => cardio,
    'timed' => timed,
    _ => strength,
  };
}

enum CardioMode {
  countdown,
  stopwatch,
  intervals;

  static CardioMode? parse(Object? value) =>
      values.where((mode) => mode.name == value).firstOrNull;
}

enum CardioIntensity {
  light,
  moderate,
  high;

  static CardioIntensity? parse(Object? value) =>
      values.where((intensity) => intensity.name == value).firstOrNull;
}

/// How a cardio activity is planned. Only the fields relevant to its mode
/// and machine are set. Stored as a plain map (Hive and Firestore).
class CardioPlan {
  const CardioPlan({
    required this.mode,
    this.durationSeconds,
    this.intensity,
    this.workSeconds,
    this.intervalRestSeconds,
    this.rounds,
    this.warmupSeconds,
    this.cooldownSeconds,
    this.speedKmh,
    this.inclinePercent,
    this.resistanceLevel,
    this.distanceMeters,
  });

  /// The keys [toMap] can write (anything else in a stored plan came from
  /// another app version and is kept untouched).
  static const fieldNames = {
    'mode',
    'durationSeconds',
    'intensity',
    'workSeconds',
    'intervalRestSeconds',
    'rounds',
    'warmupSeconds',
    'cooldownSeconds',
    'speedKmh',
    'inclinePercent',
    'resistanceLevel',
    'distanceMeters',
  };

  final CardioMode mode;

  /// Countdown: required. Stopwatch: optional target.
  final int? durationSeconds;
  final CardioIntensity? intensity;

  /// Intervals.
  final int? workSeconds;
  final int? intervalRestSeconds;
  final int? rounds;
  final int? warmupSeconds;
  final int? cooldownSeconds;

  /// Machine / outdoor details (all optional).
  final double? speedKmh;
  final double? inclinePercent;
  final int? resistanceLevel;
  final int? distanceMeters;

  /// Planned seconds, when calculable (for the day's estimated duration).
  int? get plannedSeconds => switch (mode) {
    CardioMode.intervals =>
      workSeconds == null || rounds == null
          ? null
          : (warmupSeconds ?? 0) +
                rounds! * workSeconds! +
                (rounds! - 1) * (intervalRestSeconds ?? 0) +
                (cooldownSeconds ?? 0),
    _ => durationSeconds,
  };

  /// Throws [ArgumentError] when the plan cannot be executed as described.
  void validate() {
    void check(bool ok, String field) {
      if (!ok) throw ArgumentError('Invalid cardio $field.');
    }

    bool within(num? value, num min, num max) =>
        value == null || (value >= min && value <= max);
    switch (mode) {
      case CardioMode.countdown:
        check(durationSeconds != null, 'duration');
      case CardioMode.stopwatch:
        break;
      case CardioMode.intervals:
        check(workSeconds != null && rounds != null, 'intervals');
    }
    check(within(durationSeconds, 10, 6 * 3600), 'duration');
    check(within(workSeconds, 5, 3600), 'work interval');
    check(within(intervalRestSeconds, 0, 3600), 'rest interval');
    check(within(rounds, 1, 100), 'rounds');
    check(within(warmupSeconds, 0, 3600), 'warm-up');
    check(within(cooldownSeconds, 0, 3600), 'cool-down');
    check(within(speedKmh, 0.5, 40), 'speed');
    check(within(inclinePercent, -5, 40), 'incline');
    check(within(resistanceLevel, 1, 50), 'resistance');
    check(within(distanceMeters, 10, 1000000), 'distance');
  }

  Map<String, dynamic> toMap() => {
    'mode': mode.name,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (intensity != null) 'intensity': intensity!.name,
    if (workSeconds != null) 'workSeconds': workSeconds,
    if (intervalRestSeconds != null) 'intervalRestSeconds': intervalRestSeconds,
    if (rounds != null) 'rounds': rounds,
    if (warmupSeconds != null) 'warmupSeconds': warmupSeconds,
    if (cooldownSeconds != null) 'cooldownSeconds': cooldownSeconds,
    if (speedKmh != null) 'speedKmh': speedKmh,
    if (inclinePercent != null) 'inclinePercent': inclinePercent,
    if (resistanceLevel != null) 'resistanceLevel': resistanceLevel,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
  };

  /// Null when [map] has no recognizable mode. Never throws: a value of the
  /// wrong type (malformed data from the cloud) reads as missing, so a day
  /// is always shown; the stored map itself is kept as it is.
  static CardioPlan? fromMap(Map<dynamic, dynamic>? map) {
    final mode = CardioMode.parse(map?['mode']);
    if (map == null || mode == null) return null;
    int? integer(String key) => _finite(map[key])?.toInt();
    double? decimal(String key) => _finite(map[key])?.toDouble();
    return CardioPlan(
      mode: mode,
      durationSeconds: integer('durationSeconds'),
      intensity: CardioIntensity.parse(map['intensity']),
      workSeconds: integer('workSeconds'),
      intervalRestSeconds: integer('intervalRestSeconds'),
      rounds: integer('rounds'),
      warmupSeconds: integer('warmupSeconds'),
      cooldownSeconds: integer('cooldownSeconds'),
      speedKmh: decimal('speedKmh'),
      inclinePercent: decimal('inclinePercent'),
      resistanceLevel: integer('resistanceLevel'),
      distanceMeters: integer('distanceMeters'),
    );
  }
}

/// Sets of a held duration (plank: 3 × 45 s, 60 s rest).
class TimedPlan {
  const TimedPlan({
    required this.sets,
    required this.durationSeconds,
    this.restSeconds,
  });

  final int sets;
  final int durationSeconds;
  final int? restSeconds;

  int get plannedSeconds =>
      sets * durationSeconds + (sets - 1) * (restSeconds ?? 0);

  void validate() {
    if (sets < 1 || sets > 20) throw ArgumentError('Invalid timed sets.');
    if (durationSeconds < 5 || durationSeconds > 3600) {
      throw ArgumentError('Invalid timed duration.');
    }
    final rest = restSeconds;
    if (rest != null && (rest < 0 || rest > 600)) {
      throw ArgumentError('Invalid timed rest.');
    }
  }

  Map<String, dynamic> toMap() => {
    'sets': sets,
    'durationSeconds': durationSeconds,
    if (restSeconds != null) 'restSeconds': restSeconds,
  };

  /// Never throws (see [CardioPlan.fromMap]).
  static TimedPlan? fromMap(Map<dynamic, dynamic>? map) {
    final sets = _finite(map?['sets'])?.toInt();
    final duration = _finite(map?['durationSeconds'])?.toInt();
    if (sets == null || duration == null) return null;
    return TimedPlan(
      sets: sets,
      durationSeconds: duration,
      restSeconds: _finite(map!['restSeconds'])?.toInt(),
    );
  }
}

/// A finite number, or null for anything else (missing, text, NaN…).
num? _finite(Object? value) => value is num && value.isFinite ? value : null;
