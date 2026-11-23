import 'package:ae_coaching/features/workout/domain/activity_plans.dart';

enum CardioCategory { machines, bodyweight, outdoor }

/// Optional details a cardio activity's settings offer (only those that
/// make sense for it: speed and incline on a treadmill, resistance on
/// machines, distance outdoors).
enum CardioDetail { speed, incline, resistance, distance }

/// One activity of the built-in cardio library. Most come from the bundled
/// RepDB catalog (its id, both names and its picture); the few it lacks are
/// app-defined (`cardio:` ids, names from the app's translations).
class CardioLibraryEntry {
  const CardioLibraryEntry(
    this.exerciseId,
    this.category, {
    this.searchTerms = const [],
  });

  final String exerciseId;
  final CardioCategory category;

  /// Other names the activity is found by (never shown).
  final List<String> searchTerms;

  bool get isAppDefined => exerciseId.startsWith(CardioLibrary.appIdPrefix);
}

/// The curated cardio library (no network: everything is bundled).
abstract final class CardioLibrary {
  static const appIdPrefix = 'cardio:';

  /// Added with this plan for now (Stage 3); it becomes configurable with
  /// the cardio settings screen (Stage 4). Nothing runs a timer yet.
  static const defaultPlan = CardioPlan(
    mode: CardioMode.countdown,
    durationSeconds: 20 * 60,
  );

  static const shadowBoxing = 'cardio:shadow-boxing';
  static const hiking = 'cardio:hiking';
  static const swimming = 'cardio:swimming';

  /// The fan bike: one activity, found by both of its usual names.
  static const airBike = 'repdb:air-bike';

  static const _treadmills = {
    'repdb:treadmill-running',
    'repdb:incline-treadmill-walk',
  };
  static const _resistanceMachines = {
    'repdb:stationary-bike',
    'repdb:elliptical-trainer',
    'repdb:stair-climber',
    'repdb:rowing-machine',
    'repdb:ski-erg',
    airBike,
  };
  static const _distanceActivities = {
    'repdb:walking',
    'repdb:running',
    'repdb:cycling',
    hiking,
    swimming,
  };

  /// The details offered for [exerciseId]. The user's own cardio
  /// (not in the library) gets distance; bodyweight work gets none.
  static Set<CardioDetail> detailsFor(String exerciseId) {
    if (_treadmills.contains(exerciseId)) {
      return const {
        CardioDetail.speed,
        CardioDetail.incline,
        CardioDetail.distance,
      };
    }
    if (_resistanceMachines.contains(exerciseId)) {
      return const {CardioDetail.resistance, CardioDetail.distance};
    }
    if (_distanceActivities.contains(exerciseId)) {
      return const {CardioDetail.distance};
    }
    final curated = entries.any((entry) => entry.exerciseId == exerciseId);
    return curated ? const {} : const {CardioDetail.distance};
  }

  static const entries = <CardioLibraryEntry>[
    // Machines and equipment.
    CardioLibraryEntry(
      'repdb:treadmill-running',
      CardioCategory.machines,
      searchTerms: ['treadmill', 'مشاية', 'سير'],
    ),
    CardioLibraryEntry(
      'repdb:incline-treadmill-walk',
      CardioCategory.machines,
      searchTerms: ['treadmill', 'incline', 'مشاية', 'ميل'],
    ),
    CardioLibraryEntry(
      'repdb:stationary-bike',
      CardioCategory.machines,
      searchTerms: ['bike', 'cycle', 'عجلة', 'دراجة'],
    ),
    CardioLibraryEntry(
      'repdb:elliptical-trainer',
      CardioCategory.machines,
      searchTerms: ['elliptical', 'cross trainer', 'اوربتراك', 'إليبتيكال'],
    ),
    CardioLibraryEntry(
      'repdb:stair-climber',
      CardioCategory.machines,
      searchTerms: ['stairs', 'stairmaster', 'درج', 'سلالم'],
    ),
    CardioLibraryEntry(
      'repdb:rowing-machine',
      CardioCategory.machines,
      searchTerms: ['rower', 'row', 'تجديف'],
    ),
    CardioLibraryEntry(
      'repdb:ski-erg',
      CardioCategory.machines,
      searchTerms: ['ski', 'skierg', 'تزلج'],
    ),
    CardioLibraryEntry(
      airBike,
      CardioCategory.machines,
      searchTerms: ['Assault Bike', 'assault', 'fan bike', 'أسولت', 'اسولت'],
    ),
    CardioLibraryEntry(
      'repdb:battle-ropes',
      CardioCategory.machines,
      searchTerms: ['rope', 'ropes', 'حبال'],
    ),
    CardioLibraryEntry(
      'repdb:battle-rope-double-slam',
      CardioCategory.machines,
      searchTerms: ['rope', 'ropes', 'slam', 'حبال'],
    ),
    // Bodyweight.
    CardioLibraryEntry(
      'repdb:jump-rope',
      CardioCategory.bodyweight,
      searchTerms: ['skipping', 'rope', 'نط الحبل', 'حبل'],
    ),
    CardioLibraryEntry('repdb:jumping-jacks', CardioCategory.bodyweight),
    CardioLibraryEntry('repdb:high-knees', CardioCategory.bodyweight),
    CardioLibraryEntry('repdb:mountain-climbers', CardioCategory.bodyweight),
    CardioLibraryEntry('repdb:burpees', CardioCategory.bodyweight),
    CardioLibraryEntry('repdb:heel-flicks', CardioCategory.bodyweight),
    CardioLibraryEntry(
      'repdb:step-ups',
      CardioCategory.bodyweight,
      searchTerms: ['step', 'step up'],
    ),
    CardioLibraryEntry(
      shadowBoxing,
      CardioCategory.bodyweight,
      searchTerms: ['boxing', 'box', 'ملاكمة'],
    ),
    // Outdoor.
    CardioLibraryEntry(
      'repdb:walking',
      CardioCategory.outdoor,
      searchTerms: ['walk', 'مشي'],
    ),
    CardioLibraryEntry(
      'repdb:running',
      CardioCategory.outdoor,
      searchTerms: ['run', 'jog', 'jogging', 'جري', 'هرولة'],
    ),
    CardioLibraryEntry(
      'repdb:cycling',
      CardioCategory.outdoor,
      searchTerms: ['bike', 'cycle', 'دراجة'],
    ),
    CardioLibraryEntry(
      hiking,
      CardioCategory.outdoor,
      searchTerms: ['hike', 'trek', 'جبل'],
    ),
    CardioLibraryEntry(
      swimming,
      CardioCategory.outdoor,
      searchTerms: ['swim', 'pool', 'سباحة'],
    ),
  ];
}
