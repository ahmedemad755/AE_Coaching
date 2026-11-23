import 'package:ae_coaching/features/workout/data/models/exercise_library_item.dart';

/// Presentation-only registry. Never match media by name, muscle or list index.
/// Each future entry must be visually verified against its exact catalog ID
/// and carry the source and license of the bundled asset.
class ExerciseIllustration {
  const ExerciseIllustration({
    required this.assetPath,
    required this.author,
    required this.sourceUrl,
    required this.license,
    this.changes = '',
  });

  final String assetPath;
  final String author;
  final String sourceUrl;
  final String license;
  final String changes;
}

class ExerciseIllustrations {
  const ExerciseIllustrations._();

  static const licenseAsset = 'lib/assets/exercise_illustrations/LICENSE.md';
  static const changes =
      'Resized and converted from PNG to WebP; no movement changes.';
  // Generated from explicitly reviewed, hashed sources. Never match by name.
  static const Map<String, ExerciseIllustration> verifiedByExerciseId = {
    'ex_barbell_bench_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_barbell_bench_press.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/bench-press-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_incline_barbell_bench_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_incline_barbell_bench_press.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/incline-bench-press-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_decline_barbell_bench_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_decline_barbell_bench_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/decline-bench-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_bench_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_dumbbell_bench_press.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/bench-press-dumbbell-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_incline_dumbbell_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_incline_dumbbell_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/incline-dumbbell-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_decline_dumbbell_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_decline_dumbbell_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/decline-dumbbell-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_fly': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_dumbbell_fly.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/dumbbell-fly.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_incline_dumbbell_fly': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_incline_dumbbell_fly.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/incline-dumbbell-fly.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_machine_chest_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_machine_chest_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/machine-chest-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_incline_chest_press_machine': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_incline_chest_press_machine.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/incline-chest-press-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_decline_chest_press_machine': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_decline_chest_press_machine.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/decline-chest-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_pec_deck_fly': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_pec_deck_fly.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/pec-deck.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cable_chest_fly': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_cable_chest_fly.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/cable-fly.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_smith_machine_bench_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_smith_machine_bench_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/smith-machine-bench-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_smith_machine_incline_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_smith_machine_incline_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/smith-machine-incline-bench-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_push_up': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_push_up.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/push-up.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_wide_grip_push_up': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_wide_grip_push_up.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/wide-push-up.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_diamond_push_up': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_diamond_push_up.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/diamond-push-up.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_chest_dip': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_chest_dip.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/chest-dip.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_pull_up': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_pull_up.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/pull-up.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_chin_up': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_chin_up.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/chin-up.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_wide_grip_pull_up': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_wide_grip_pull_up.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/pull-ups-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_assisted_pull_up': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_assisted_pull_up.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/assisted-pull-up.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_lat_pulldown': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_lat_pulldown.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/wide-grip-lat-pull-down-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_close_grip_lat_pulldown': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_close_grip_lat_pulldown.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/close-grip-lat-pulldown.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_reverse_grip_lat_pulldown': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_reverse_grip_lat_pulldown.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/underhand-pull-down-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_neutral_grip_lat_pulldown': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_neutral_grip_lat_pulldown.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/v-bar-pull-down-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_seated_cable_row': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_seated_cable_row.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/seated-cable-row.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_close_grip_seated_cable_row': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_seated_cable_row.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/seated-cable-row.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_barbell_bent_over_row': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_barbell_bent_over_row.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/barbell-row.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_underhand_barbell_row': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_underhand_barbell_row.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/reverse-grips-bent-over-barbell-rows-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_one_arm_dumbbell_row': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_one_arm_dumbbell_row.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/dumbbell-row.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_chest_supported_dumbbell_row': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_chest_supported_dumbbell_row.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/chest-supported-row.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_t_bar_row': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_t_bar_row.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/t-bar-row.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_chest_supported_machine_row': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_chest_supported_machine_row.webp',
      author: 'Bryl Lim / Workout Guide',
      sourceUrl:
          'https://github.com/bryllim/workout-guide/blob/aac599224bb9780305239607ef98540b7e0ce389/packages/workout-guide/assets/chest-supported-row/frame-2.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_straight_arm_cable_pulldown': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_straight_arm_cable_pulldown.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/straight-arm-pulldown.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_pullover': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_dumbbell_pullover.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/dumbbell-pullover.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_inverted_row': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_inverted_row.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/inverted-row.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_back_extension': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_back_extension.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/back-extension.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_barbell_overhead_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_barbell_overhead_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/overhead-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_seated_barbell_shoulder_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_seated_barbell_shoulder_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/seated-military-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_shoulder_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_dumbbell_shoulder_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/dumbbell-shoulder-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_arnold_press': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_arnold_press.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/arnold-press-1.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Resized and converted from PNG to WebP; no movement changes. Two complete source frames arranged side by side.',
    ),
    'ex_machine_shoulder_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_machine_shoulder_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/machine-shoulder-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_smith_machine_shoulder_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_smith_machine_shoulder_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/smith-machine-overhead-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_lateral_raise': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_dumbbell_lateral_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/lateral-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cable_lateral_raise': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_cable_lateral_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/cable-lateral-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_machine_lateral_raise': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_machine_lateral_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/machine-lateral-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_front_raise': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_dumbbell_front_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/front-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cable_front_raise': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_cable_front_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/cable-front-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_plate_front_raise': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_plate_front_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/plate-front-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_reverse_pec_deck': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_reverse_pec_deck.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/reverse-pec-deck.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_bent_over_dumbbell_reverse_fly': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_bent_over_dumbbell_reverse_fly.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/bent-over-rear-delt-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cable_rear_delt_fly': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_cable_rear_delt_fly.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/cable-rear-delt-fly.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_face_pull': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_face_pull.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/face-pull.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_barbell_upright_row': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_barbell_upright_row.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/barbell-upright-row.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_shrug': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_dumbbell_shrug.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/dumbbell-shrug.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_barbell_shrug': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_barbell_shrug.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/barbell-shrug.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_barbell_curl': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_barbell_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/barbell-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_ez_bar_curl': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_ez_bar_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/ez-bar-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_curl': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_dumbbell_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/bicep-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_alternating_dumbbell_curl': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_alternating_dumbbell_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/alternating-dumbbell-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_hammer_curl': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_hammer_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/hammer-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cross_body_hammer_curl': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_cross_body_hammer_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/hammer-curl-across-body.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_incline_dumbbell_curl': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_incline_dumbbell_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/incline-dumbbell-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_preacher_curl': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_preacher_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/preacher-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_machine_preacher_curl': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_machine_preacher_curl.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/preacher-curl-with-machine-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_concentration_curl': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_concentration_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/concentration-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cable_biceps_curl': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_cable_biceps_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/cable-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_rope_hammer_curl': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_rope_hammer_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/rope-hammer-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cable_triceps_pushdown': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_cable_triceps_pushdown.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/triceps-pushdown.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_rope_triceps_pushdown': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_rope_triceps_pushdown.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/rope-triceps-pushdown.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_reverse_grip_triceps_pushdown': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_reverse_grip_triceps_pushdown.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/reverse-grip-triceps-pushdown.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_overhead_cable_triceps_extension': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_overhead_cable_triceps_extension.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/overhead-cable-extension.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_single_arm_cable_triceps_extension': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_single_arm_cable_triceps_extension.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/one-arm-cable-triceps-extension.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_overhead_triceps_extension': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_dumbbell_overhead_triceps_extension.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/dumbbell-overhead-triceps-extension.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_single_arm_overhead_dumbbell_extension': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_single_arm_overhead_dumbbell_extension.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/one-arm-dumbbell-triceps-extension.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_lying_ez_bar_triceps_extension': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_lying_ez_bar_triceps_extension.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/skull-crusher.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_skull_crusher': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_dumbbell_skull_crusher.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/two-dumbbell-skullcrusher.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_close_grip_bench_press': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_close_grip_bench_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/close-grip-bench-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_parallel_bar_triceps_dip': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_parallel_bar_triceps_dip.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/tricep-dips-using-body-weight-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_bench_dip': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_bench_dip.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/bench-dip.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_triceps_extension_machine': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_triceps_extension_machine.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/machine-triceps-extension.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_triceps_kickback': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_dumbbell_triceps_kickback.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/triceps-kickback.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_barbell_back_squat': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_barbell_back_squat.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/barbell-squat-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_barbell_front_squat': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_barbell_front_squat.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/front-squat.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_smith_machine_squat': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_smith_machine_squat.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/smith-machine-squat.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_goblet_squat': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_goblet_squat.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/goblet-squat.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_hack_squat': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_hack_squat.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/hack-squat.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_leg_press_45': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_leg_press_45.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/leg-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_leg_extension': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_leg_extension.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/leg-extension.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_bulgarian_split_squat': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_bulgarian_split_squat.webp',
      author: 'Bryl Lim / Workout Guide',
      sourceUrl:
          'https://github.com/bryllim/workout-guide/blob/aac599224bb9780305239607ef98540b7e0ce389/packages/workout-guide/assets/bulgarian-split-squat/frame-1.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_walking_lunge': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_dumbbell_walking_lunge.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/walking-lunge.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_forward_lunge': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_forward_lunge.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/forward-lunge.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_sissy_squat': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_sissy_squat.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/sissy-squat.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_belt_squat': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_belt_squat.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/belt-squat.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_romanian_deadlift': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_romanian_deadlift.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/romanian-deadlift.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_romanian_deadlift': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_dumbbell_romanian_deadlift.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/dumbbell-romanian-deadlift.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_seated_leg_curl': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_seated_leg_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/seated-leg-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_lying_leg_curl': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_lying_leg_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/lying-leg-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_standing_single_leg_curl': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_standing_single_leg_curl.webp',
      author: 'Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/src/images-web/standing-leg-curls-2.png',
      license: 'CC BY-SA 4.0',
      changes: 'Resized and converted from PNG to WebP; no movement changes.',
    ),
    'ex_nordic_hamstring_curl': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_nordic_hamstring_curl.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/nordic-curl.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_barbell_hip_thrust': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_barbell_hip_thrust.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/hip-thrust.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_smith_machine_hip_thrust': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_smith_machine_hip_thrust.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/smith-machine-hip-thrust.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dumbbell_hip_thrust': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_dumbbell_hip_thrust.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/dumbbell-hip-thrust.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_glute_bridge': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_glute_bridge.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/glute-bridge.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_single_leg_glute_bridge': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_single_leg_glute_bridge.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/single-leg-glute-bridge.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cable_glute_kickback': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_cable_glute_kickback.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/cable-kickback.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_hip_abduction_machine': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_hip_abduction_machine.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/hip-abduction.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_hip_adduction_machine': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_hip_adduction_machine.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/hip-adduction.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cable_hip_abduction': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_cable_hip_abduction.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/cable-standing-hip-abduction.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cable_pull_through': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_cable_pull_through.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/cable-pull-through.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_sumo_squat': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_sumo_squat.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/dumbbell-sumo-squat.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_frog_pump': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_frog_pump.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/frog-pump.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_standing_calf_raise_machine': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_standing_calf_raise_machine.webp',
      author: 'Bryl Lim / Workout Guide; Everkinetic / Greg Priday',
      sourceUrl:
          'https://github.com/bryllim/workout-guide/blob/aac599224bb9780305239607ef98540b7e0ce389/packages/workout-guide/assets/standing-calf-raise/frame-1.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_seated_calf_raise_machine': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_seated_calf_raise_machine.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/seated-calf-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_leg_press_calf_raise': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_leg_press_calf_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/leg-press-calf-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_single_leg_calf_raise': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_single_leg_calf_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/single-leg-calf-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_tibialis_raise': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_tibialis_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/tib-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_crunch': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_crunch.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/crunch.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cable_crunch': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_cable_crunch.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/cable-crunch.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_reverse_crunch': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_reverse_crunch.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/reverse-crunch.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_lying_leg_raise': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_lying_leg_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/lying-leg-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_hanging_knee_raise': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_hanging_knee_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/hanging-knee-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_hanging_leg_raise': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_hanging_leg_raise.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/hanging-leg-raise.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_plank': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_plank.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/plank.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_side_plank': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_side_plank.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/side-plank.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_dead_bug': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_dead_bug.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/dead-bug.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_bird_dog': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_bird_dog.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/bird-dog.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_russian_twist': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_russian_twist.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/russian-twist.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_bicycle_crunch': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_bicycle_crunch.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/bicycle-crunch.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_mountain_climber': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_mountain_climber.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/mountain-climber.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_ab_wheel_rollout': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_ab_wheel_rollout.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/ab-wheel-rollout.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_pallof_press': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_pallof_press.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/pallof-press.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_cable_woodchopper': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_cable_woodchopper.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/woodchop.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_flutter_kicks': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_flutter_kicks.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/flutter-kick.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_hollow_body_hold': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_hollow_body_hold.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/hollow-hold.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_conventional_deadlift': ExerciseIllustration(
      assetPath:
          'lib/assets/exercise_illustrations/ex_conventional_deadlift.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/deadlift.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_sumo_deadlift': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_sumo_deadlift.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/sumo-deadlift.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_trap_bar_deadlift': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_trap_bar_deadlift.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/trap-bar-deadlift.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_kettlebell_swing': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_kettlebell_swing.webp',
      author: 'Open Exercise Art / Alex Mollard',
      sourceUrl:
          'https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/png/kettlebell-swing.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
    'ex_burpee': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_burpee.webp',
      author: 'Bryl Lim / Workout Guide',
      sourceUrl:
          'https://github.com/bryllim/workout-guide/blob/aac599224bb9780305239607ef98540b7e0ce389/packages/workout-guide/assets/burpee/frame-1.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes. Two complete source frames arranged side by side.',
    ),
    'ex_push_press': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_push_press.webp',
      author: 'Bryl Lim / Workout Guide',
      sourceUrl:
          'https://github.com/bryllim/workout-guide/blob/aac599224bb9780305239607ef98540b7e0ce389/packages/workout-guide/assets/push-press/frame-3.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes. Two complete source frames arranged side by side.',
    ),
    'ex_farmer_s_carry': ExerciseIllustration(
      assetPath: 'lib/assets/exercise_illustrations/ex_farmer_s_carry.webp',
      author: 'Bryl Lim / Workout Guide',
      sourceUrl:
          'https://github.com/bryllim/workout-guide/blob/aac599224bb9780305239607ef98540b7e0ce389/packages/workout-guide/assets/farmer-carry/frame-2.png',
      license: 'CC BY-SA 4.0',
      changes:
          'Transparency composited on charcoal, resized and converted to WebP; no pose changes.',
    ),
  };

  static ExerciseIllustration? forExercise(ExerciseLibraryItem exercise) =>
      exercise.source == ExerciseLibraryItemSource.builtIn
      ? verifiedByExerciseId[exercise.id]
      : null;
}
