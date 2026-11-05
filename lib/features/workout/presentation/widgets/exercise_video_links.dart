import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public pages individually reviewed on 2026-11-01. Never derive a URL from
/// an exercise name or inherit a link for a different grip/equipment variant.
class ExerciseVideoLinks {
  const ExerciseVideoLinks._();

  static const verifiedOn = '2026-11-01';
  static const Map<String, String> verifiedByExerciseId = {
    'ex_barbell_bench_press':
        'https://musclewiki.com/exercise/barbell-bench-press',
    'ex_incline_barbell_bench_press':
        'https://musclewiki.com/exercise/barbell-incline-bench-press',
    'ex_dumbbell_bench_press':
        'https://musclewiki.com/exercise/dumbbell-bench-press',
    'ex_incline_dumbbell_press':
        'https://musclewiki.com/exercise/dumbbell-incline-bench-press',
    'ex_decline_dumbbell_press':
        'https://musclewiki.com/exercise/dumbbell-decline-bench-press',
    'ex_dumbbell_fly': 'https://musclewiki.com/exercise/dumbbell-chest-fly',
    'ex_machine_chest_press':
        'https://musclewiki.com/exercise/machine-chest-press',
    'ex_incline_chest_press_machine':
        'https://musclewiki.com/exercise/machine-plate-loaded-incline-chest-press',
    'ex_decline_chest_press_machine':
        'https://musclewiki.com/exercise/machine-plate-loaded-decline-chest-press',
    'ex_pec_deck_fly': 'https://musclewiki.com/exercise/machine-pec-fly',
    'ex_cable_chest_fly': 'https://musclewiki.com/exercise/cable-pec-fly',
    'ex_smith_machine_bench_press':
        'https://musclewiki.com/exercise/smith-machine-bench-press',
    'ex_smith_machine_incline_press':
        'https://musclewiki.com/exercise/smith-machine-incline-bench-press',
    'ex_push_up': 'https://musclewiki.com/exercise/push-up',
    'ex_diamond_push_up': 'https://musclewiki.com/exercise/diamond-push-ups',
    'ex_pull_up': 'https://musclewiki.com/exercise/pull-ups',
    'ex_chin_up': 'https://musclewiki.com/exercise/chin-ups',
    'ex_assisted_pull_up':
        'https://musclewiki.com/exercise/machine-assisted-pull-up',
    'ex_lat_pulldown': 'https://musclewiki.com/exercise/machine-pulldown',
    'ex_close_grip_lat_pulldown':
        'https://musclewiki.com/exercise/narrow-pulldown',
    'ex_underhand_barbell_row':
        'https://musclewiki.com/fr-fr/exercise/barbell-bent-over-row',
    'ex_pendlay_row':
        'https://musclewiki.com/exercise/barbell-pronated-pendlay-row',
    'ex_one_arm_dumbbell_row':
        'https://musclewiki.com/exercise/dumbbell-row-unilateral',
    'ex_t_bar_row':
        'https://musclewiki.com/exercise/machine-chest-supported-t-bar-row',
    'ex_dumbbell_pullover': 'https://musclewiki.com/exercise/dumbbell-pullover',
    'ex_inverted_row': 'https://musclewiki.com/exercise/inverted-row',
    'ex_back_extension':
        'https://musclewiki.com/exercise/machine-45-degree-back-extension',
    'ex_cable_pullover': 'https://musclewiki.com/exercise/cable-rope-pullover',
    'ex_machine_shoulder_press':
        'https://musclewiki.com/exercise/machine-overhand-overhead-press',
    'ex_dumbbell_shoulder_press':
        'https://musclewiki.com/de-de/exercise/dumbbell-seated-overhead-press',
    'ex_dumbbell_lateral_raise':
        'https://musclewiki.com/exercise/dumbbell-lateral-raise',
    'ex_seated_dumbbell_lateral_raise':
        'https://musclewiki.com/exercise/seated-lateral-raise',
    'ex_cable_lateral_raise':
        'https://musclewiki.com/exercise/cable-low-single-arm-lateral-raise',
    'ex_dumbbell_front_raise':
        'https://musclewiki.com/exercise/dumbbell-front-raise',
    'ex_plate_front_raise': 'https://musclewiki.com/exercise/plate-front-raise',
    'ex_dumbbell_shrug': 'https://musclewiki.com/exercise/dumbbell-shrug',
    'ex_barbell_shrug': 'https://musclewiki.com/exercise/barbell-shrug',
    'ex_barbell_curl': 'https://musclewiki.com/exercise/barbell-curl',
    'ex_hammer_curl':
        'https://musclewiki.com/exercise/dumbbell-single-arm-hammer-curl',
    'ex_rope_hammer_curl':
        'https://musclewiki.com/exercise/cable-rope-hammer-curl',
    'ex_bayesian_cable_curl':
        'https://musclewiki.com/exercise/cable-single-arm-bayesian-curl',
    'ex_rope_triceps_pushdown':
        'https://musclewiki.com/exercise/cable-rope-pushdown',
    'ex_cable_triceps_pushdown':
        'https://musclewiki.com/fr-fr/exercise/cable-bar-pushdown',
    'ex_overhead_cable_triceps_extension':
        'https://musclewiki.com/exercise/cable-rope-overhead-tricep-extension',
    'ex_single_arm_overhead_dumbbell_extension':
        'https://musclewiki.com/exercise/dumbbell-single-arm-overhead-tricep-extension',
    'ex_dumbbell_skull_crusher':
        'https://musclewiki.com/exercise/dumbbell-skullcrusher',
    'ex_close_grip_bench_press':
        'https://musclewiki.com/exercise/barbell-close-grip-bench-press',
    'ex_bench_dip': 'https://musclewiki.com/exercise/bench-dips',
    'ex_dumbbell_triceps_kickback':
        'https://musclewiki.com/exercise/dumbbell-tricep-kickback',
    'ex_barbell_back_squat': 'https://musclewiki.com/exercise/barbell-squat',
    'ex_barbell_front_squat':
        'https://musclewiki.com/exercise/barbell-front-squat-bodybuilding',
    'ex_smith_machine_squat':
        'https://musclewiki.com/exercise/smith-machine-squat',
    'ex_goblet_squat': 'https://musclewiki.com/exercise/dumbbell-goblet-squat',
    'ex_hack_squat': 'https://musclewiki.com/exercise/machine-hack-squat',
    'ex_horizontal_leg_press':
        'https://musclewiki.com/exercise/machine-horizontal-leg-press',
    'ex_leg_extension': 'https://musclewiki.com/exercise/machine-leg-extension',
    'ex_dumbbell_romanian_deadlift':
        'https://musclewiki.com/exercise/dumbbell-romanian-deadlift',
    'ex_seated_leg_curl':
        'https://musclewiki.com/exercise/machine-seated-leg-curl',
    'ex_nordic_hamstring_curl':
        'https://musclewiki.com/de-de/exercise/nordic-hamstring-curl',
    'ex_glute_ham_raise': 'https://musclewiki.com/exercise/glute-ham-raise',
    'ex_barbell_hip_thrust':
        'https://musclewiki.com/exercise/barbell-hip-thrust',
    'ex_dumbbell_hip_thrust':
        'https://musclewiki.com/exercise/dumbbell-hip-thrust',
    'ex_cable_glute_kickback':
        'https://musclewiki.com/exercise/cable-standing-glute-kickback',
    'ex_glute_kickback_machine':
        'https://musclewiki.com/exercise/machine-glute-kickback',
    'ex_hip_abduction_machine':
        'https://musclewiki.com/exercise/machine-hip-abduction',
    'ex_cable_pull_through':
        'https://musclewiki.com/pt-br/exercise/cable-pull-through',
    'ex_reverse_hyperextension':
        'https://musclewiki.com/exercise/machine-reverse-hyperextension',
    'ex_standing_calf_raise_machine':
        'https://musclewiki.com/exercise/machine-standing-calf-raises',
    'ex_seated_calf_raise_machine':
        'https://musclewiki.com/exercise/machine-seated-calf-raises',
    'ex_smith_machine_calf_raise':
        'https://musclewiki.com/exercise/smith-machine-calf-raise',
    'ex_dumbbell_standing_calf_raise':
        'https://musclewiki.com/exercise/dumbbell-calf-raise',
    'ex_single_leg_calf_raise':
        'https://musclewiki.com/exercise/bodyweight-single-leg-calf-raise',
    'ex_donkey_calf_raise':
        'https://musclewiki.com/exercise/machine-donkey-calf-raise',
    'ex_machine_ab_crunch': 'https://musclewiki.com/exercise/machine-crunch',
    'ex_lying_leg_raise': 'https://musclewiki.com/exercise/laying-leg-raises',
    'ex_hanging_knee_raise':
        'https://musclewiki.com/exercise/hanging-knee-raises',
    'ex_side_plank': 'https://musclewiki.com/exercise/elbow-side-plank',
    'ex_dead_bug': 'https://musclewiki.com/fr-fr/exercise/dead-bug',
    'ex_bird_dog': 'https://musclewiki.com/exercise/bird-dog',
    'ex_russian_twist':
        'https://musclewiki.com/exercise/bodyweight-russian-twist',
    'ex_mountain_climber': 'https://musclewiki.com/exercise/mountain-climber',
    'ex_pallof_press': 'https://musclewiki.com/exercise/cable-pallof-press',
    'ex_hollow_body_hold': 'https://musclewiki.com/exercise/hollow-hold',
    'ex_kettlebell_swing': 'https://musclewiki.com/exercise/kettlebell-swing',
    'ex_burpee': 'https://musclewiki.com/exercise/burpee',
    'ex_alternating_dumbbell_curl':
        'https://musclewiki.com/ar-sa/exercise/dumbbell-curl',
    'ex_seated_cable_row':
        'https://musclewiki.com/ar-sa/exercise/machine-seated-cable-row',
    'ex_smith_machine_hip_thrust':
        'https://musclewiki.com/ar-sa/exercise/smith-machine-hip-thrust',
    'ex_machine_preacher_curl':
        'https://musclewiki.com/exercise/machine-seated-plate-loaded-preacher-curl',
    'ex_barbell_clean_and_press':
        'https://musclewiki.com/es-es/exercise/barbell-clean-and-press',
    'ex_barbell_overhead_press':
        'https://musclewiki.com/tr-tr/exercise/barbell-overhead-press',
    'ex_barbell_upright_row':
        'https://musclewiki.com/fr-fr/exercise/barbell-upright-row',
    'ex_single_leg_press':
        'https://musclewiki.com/fr-fr/exercise/machine-single-leg-leg-press',
    'ex_machine_pullover':
        'https://musclewiki.com/de-de/exercise/machine-pullover',
    'ex_glute_bridge': 'https://musclewiki.com/exercise/glute-bridge',
    'ex_bicycle_crunch': 'https://musclewiki.com/exercise/bicycle-crunch',
    'ex_ez_bar_curl': 'https://musclewiki.com/es-es/exercise/ez-bar-curl',
    'ex_reverse_pec_deck':
        'https://musclewiki.com/fr-fr/exercise/machine-reverse-fly',
    'ex_romanian_deadlift':
        'https://musclewiki.com/exercise/barbell-romanian-deadlift',
    'ex_stiff_leg_deadlift':
        'https://musclewiki.com/exercise/barbell-stiff-leg-deadlifts',
    'ex_conventional_deadlift':
        'https://musclewiki.com/exercise/barbell-deadlift',
    'ex_single_leg_glute_bridge':
        'https://musclewiki.com/ar-sa/exercise/single-leg-glute-bridge',
    'ex_forward_lunge': 'https://musclewiki.com/pt-br/exercise/forward-lunge',
    'ex_concentration_curl':
        'https://musclewiki.com/es-es/exercise/dumbbell-concentration-curl',
    'ex_plank': 'https://musclewiki.com/exercise/forearm-plank',
    'ex_straight_arm_cable_pulldown':
        'https://musclewiki.com/exercise/cable-rope-pullover',
  };

  static Uri? forExercise(ExerciseLibraryItem exercise) {
    if (exercise.source != ExerciseLibraryItemSource.builtIn) return null;
    final url = verifiedByExerciseId[exercise.id];
    return url == null ? null : Uri.parse(url);
  }
}

typedef ExternalUrlOpener = Future<bool> Function(Uri uri);

/// No WebView, API, content download, or fallback to an embedded player.
Future<bool> openExerciseExternalUrl(Uri uri) async {
  if (uri.scheme != 'https' || uri.host.isEmpty) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
