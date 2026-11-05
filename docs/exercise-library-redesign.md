# Exercise library visual redesign

Reference: user-provided “Bilingual Dark-Themed Exercise Selector.png”.

Historical layout-stage report: current image/video coverage and licensing are in [exercise-media-audit.md](exercise-media-audit.md). Zero-image figures below describe the initial placeholder stage.

## Implementation

The existing picker dialog and its callers remain in place. Cards now use dark navy or light surfaces, blue selected borders, separate thumbnail/preview targets, both saved exercise names, and bilingual muscle/equipment badges. RTL mirrors the thumbnail and checkbox positions without reflecting the artwork itself. Search, normalized Arabic matching, combined filters, custom creation, exclusions, single/multiple selection, insertion order, save callbacks, and save-error retry behavior remain in their existing owners.

The All control clears search and muscle/equipment filters without clearing exercise selection. Favorites was not added. Filters display localized metadata while passing the original catalog keys to the repositories; unknown custom labels are displayed unchanged. No exercise IDs, assignments, storage schemas, analytics, or synchronization policies changed.

## Illustration coverage

**0 of 180 built-in exercises have verified illustrations. All 180 use an explicit “No illustration yet” placeholder.** Custom exercises also use placeholders. Existing body-measurement images are not exercise illustrations and were not reused. The reference was used as a visual guide, not extracted as individual exercise artwork.

`ExerciseIllustrations.verifiedByExerciseId` is the presentation-only registry for future approved assets. It is currently empty. Media must be matched to the exact existing exercise ID, not a translated name, muscle, equipment, or position in the list. Each entry records a local path, author, source URL, and license. Custom IDs do not inherit built-in artwork. Missing files fall back gracefully.

Rendering uses local `AssetImage` providers, normal Flutter caching, bounded thumbnail/preview decode sizes, and lazy list construction. There are no image network requests. Image preview shows only existing exercise metadata and any verified artwork/credit; no instructions or animations are fabricated.

## Source options requiring approval

1. **Curated Everkinetic pilot:** evaluate individually matched illustrations from [Everkinetic](https://github.com/everkinetic/data). Its [repository license](https://github.com/everkinetic/data/blob/main/LICENSE.md) is CC BY-SA 4.0. Before adoption, verify each asset's provenance, actual movement/equipment, attribution and adaptation requirements. Suggested pilot IDs: `ex_barbell_bench_press`, `ex_incline_dumbbell_press`, `ex_barbell_back_squat`, `ex_lat_pulldown`. No matching coverage is claimed yet and nothing has been acquired.
2. **Original commissioned or user-supplied artwork:** approve a small anatomical illustration style sample, confirm rights, then review the same four exercises before considering expansion to all 180. No generation or purchase has been initiated.

The free-exercise-db repository was not treated as a verified image source: its maintainer's [image licensing discussion](https://github.com/yuhonas/free-exercise-db/issues/2) explicitly records uncertainty about the provenance of the photos. A dataset license alone was not used as evidence that every image could be bundled.

## Changed files

- `lib/features/workout/presentation/widgets/exercise_picker_dialog.dart`
- `lib/features/workout/presentation/widgets/exercise_library_card.dart` (new)
- `lib/features/workout/presentation/widgets/exercise_illustrations.dart` (new)
- `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` and three generated localization Dart files
- `test/features/workout/exercise_library_card_test.dart` (new)
- `test/features/workout/exercise_picker_dialog_test.dart`
- `test/features/workout/exercise_picker_bundled_catalog_test.dart`
- `test/features/workout/exercise_library_flow_test.dart`
- This document and generated verification/preview artifacts under `build/`.

## Verification

The focused command passes these paths together to `flutter test --no-pub --reporter expanded`:

```text
test/features/workout/exercise_library_card_test.dart
test/features/workout/exercise_picker_dialog_test.dart
test/features/workout/exercise_picker_bundled_catalog_test.dart
test/features/workout/exercise_library_flow_test.dart
test/features/workout/exercise_catalog_repository_test.dart
test/features/workout/custom_exercise_repository_test.dart
test/features/workout/template_exercise_session_persistence_test.dart
test/features/workout/workout_template_repository_test.dart
test/features/workout/workout_session_repository_test.dart
```

Coverage includes bilingual data/badges, ID registry constraints, custom/unknown ID fallback, missing asset fallback, selection/deselection, disabled assignments, preview independence, Arabic normalization/search, composed filters, filter reset retaining selection, custom creation, small LTR/RTL cards in both themes, enlarged text with keyboard inset, and existing persistence flows.

Preview artifacts: `build/exercise-picker-previews/picker-en.png` (dark/LTR), `picker-ar.png` (light/RTL), and `dark.png` / `light.png` card samples. These are offscreen Flutter renders, not emulator screenshots. Optional Windows fonts are loaded only by preview tests; no system fonts are bundled into the app.

Final verification on November 1, 2026:

| Check | Result | Evidence |
| --- | --- | --- |
| Focused tests listed above | 86 passed, 0 failed | `build/exercise-picker-focused.log` |
| `flutter test --no-pub --reporter expanded` | 534 passed, 0 failed (56 seconds) | `build/exercise-picker-full-tests.log` |
| `flutter analyze --no-pub` | No issues found (15.5 seconds) | `build/exercise-picker-analyze.log` |
| `flutter build apk --debug --no-pub` | Passed, Gradle 9.0 seconds | `build/exercise-picker-apk.log` |

APK: `build/app/outputs/flutter-apk/app-debug.apk`. The final full suite includes the exact aspect-ratio-preserving, bounded `ResizeImagePolicy.fit` decoder. The focused result precedes that small decoder change; all focused tests are included in the final full run.

Initial focused runs caught and resolved thumbnail-placeholder overflow at narrow widths/enlarged text, test interactions needing to scroll to taller lazy cards, and one overly broad metadata assertion. The preview test briefly had misplaced imports, corrected before final verification. No tests were skipped or weakened to suppress an application failure.

No emulator acceptance check was performed in this task. Previews were rendered offscreen with Flutter and visually inspected; the earlier emulator disk-space blocker was not worked around by deleting data. No app data was cleared, no cloud data or infrastructure was changed, and no commit/push was performed.

## Exercises currently using placeholders

The following inventory is generated from the unchanged bundled catalog.

| Exercise ID | English name | Illustration |
| --- | --- | --- |
| ex_barbell_bench_press | Barbell Bench Press | Placeholder |
| ex_incline_barbell_bench_press | Incline Barbell Bench Press | Placeholder |
| ex_decline_barbell_bench_press | Decline Barbell Bench Press | Placeholder |
| ex_dumbbell_bench_press | Dumbbell Bench Press | Placeholder |
| ex_incline_dumbbell_press | Incline Dumbbell Press | Placeholder |
| ex_decline_dumbbell_press | Decline Dumbbell Press | Placeholder |
| ex_dumbbell_fly | Dumbbell Fly | Placeholder |
| ex_incline_dumbbell_fly | Incline Dumbbell Fly | Placeholder |
| ex_machine_chest_press | Machine Chest Press | Placeholder |
| ex_incline_chest_press_machine | Incline Chest Press Machine | Placeholder |
| ex_decline_chest_press_machine | Decline Chest Press Machine | Placeholder |
| ex_pec_deck_fly | Pec Deck Fly | Placeholder |
| ex_cable_chest_fly | Cable Chest Fly | Placeholder |
| ex_high_to_low_cable_fly | High-to-Low Cable Fly | Placeholder |
| ex_low_to_high_cable_fly | Low-to-High Cable Fly | Placeholder |
| ex_smith_machine_bench_press | Smith Machine Bench Press | Placeholder |
| ex_smith_machine_incline_press | Smith Machine Incline Press | Placeholder |
| ex_push_up | Push-Up | Placeholder |
| ex_wide_grip_push_up | Wide-Grip Push-Up | Placeholder |
| ex_diamond_push_up | Diamond Push-Up | Placeholder |
| ex_chest_dip | Chest Dip | Placeholder |
| ex_single_arm_cable_chest_fly | Single-Arm Cable Chest Fly | Placeholder |
| ex_pull_up | Pull-Up | Placeholder |
| ex_chin_up | Chin-Up | Placeholder |
| ex_wide_grip_pull_up | Wide-Grip Pull-Up | Placeholder |
| ex_assisted_pull_up | Assisted Pull-Up | Placeholder |
| ex_lat_pulldown | Lat Pulldown | Placeholder |
| ex_close_grip_lat_pulldown | Close-Grip Lat Pulldown | Placeholder |
| ex_reverse_grip_lat_pulldown | Reverse-Grip Lat Pulldown | Placeholder |
| ex_neutral_grip_lat_pulldown | Neutral-Grip Lat Pulldown | Placeholder |
| ex_single_arm_lat_pulldown | Single-Arm Lat Pulldown | Placeholder |
| ex_seated_cable_row | Seated Cable Row | Placeholder |
| ex_close_grip_seated_cable_row | Close-Grip Seated Cable Row | Placeholder |
| ex_wide_grip_seated_cable_row | Wide-Grip Seated Cable Row | Placeholder |
| ex_barbell_bent_over_row | Barbell Bent-Over Row | Placeholder |
| ex_underhand_barbell_row | Underhand Barbell Row | Placeholder |
| ex_pendlay_row | Pendlay Row | Placeholder |
| ex_one_arm_dumbbell_row | One-Arm Dumbbell Row | Placeholder |
| ex_chest_supported_dumbbell_row | Chest-Supported Dumbbell Row | Placeholder |
| ex_t_bar_row | T-Bar Row | Placeholder |
| ex_chest_supported_machine_row | Chest-Supported Machine Row | Placeholder |
| ex_single_arm_machine_row | Single-Arm Machine Row | Placeholder |
| ex_straight_arm_cable_pulldown | Straight-Arm Cable Pulldown | Placeholder |
| ex_dumbbell_pullover | Dumbbell Pullover | Placeholder |
| ex_machine_pullover | Machine Pullover | Placeholder |
| ex_inverted_row | Inverted Row | Placeholder |
| ex_back_extension | Back Extension | Placeholder |
| ex_cable_pullover | Cable Pullover | Placeholder |
| ex_barbell_overhead_press | Barbell Overhead Press | Placeholder |
| ex_seated_barbell_shoulder_press | Seated Barbell Shoulder Press | Placeholder |
| ex_dumbbell_shoulder_press | Dumbbell Shoulder Press | Placeholder |
| ex_arnold_press | Arnold Press | Placeholder |
| ex_machine_shoulder_press | Machine Shoulder Press | Placeholder |
| ex_smith_machine_shoulder_press | Smith Machine Shoulder Press | Placeholder |
| ex_dumbbell_lateral_raise | Dumbbell Lateral Raise | Placeholder |
| ex_seated_dumbbell_lateral_raise | Seated Dumbbell Lateral Raise | Placeholder |
| ex_cable_lateral_raise | Cable Lateral Raise | Placeholder |
| ex_machine_lateral_raise | Machine Lateral Raise | Placeholder |
| ex_dumbbell_front_raise | Dumbbell Front Raise | Placeholder |
| ex_cable_front_raise | Cable Front Raise | Placeholder |
| ex_plate_front_raise | Plate Front Raise | Placeholder |
| ex_reverse_pec_deck | Reverse Pec Deck | Placeholder |
| ex_bent_over_dumbbell_reverse_fly | Bent-Over Dumbbell Reverse Fly | Placeholder |
| ex_cable_rear_delt_fly | Cable Rear Delt Fly | Placeholder |
| ex_face_pull | Face Pull | Placeholder |
| ex_barbell_upright_row | Barbell Upright Row | Placeholder |
| ex_dumbbell_shrug | Dumbbell Shrug | Placeholder |
| ex_barbell_shrug | Barbell Shrug | Placeholder |
| ex_barbell_curl | Barbell Curl | Placeholder |
| ex_ez_bar_curl | EZ-Bar Curl | Placeholder |
| ex_dumbbell_curl | Dumbbell Curl | Placeholder |
| ex_alternating_dumbbell_curl | Alternating Dumbbell Curl | Placeholder |
| ex_hammer_curl | Hammer Curl | Placeholder |
| ex_cross_body_hammer_curl | Cross-Body Hammer Curl | Placeholder |
| ex_incline_dumbbell_curl | Incline Dumbbell Curl | Placeholder |
| ex_preacher_curl | Preacher Curl | Placeholder |
| ex_machine_preacher_curl | Machine Preacher Curl | Placeholder |
| ex_concentration_curl | Concentration Curl | Placeholder |
| ex_cable_biceps_curl | Cable Biceps Curl | Placeholder |
| ex_rope_hammer_curl | Rope Hammer Curl | Placeholder |
| ex_bayesian_cable_curl | Bayesian Cable Curl | Placeholder |
| ex_spider_curl | Spider Curl | Placeholder |
| ex_cable_triceps_pushdown | Cable Triceps Pushdown | Placeholder |
| ex_rope_triceps_pushdown | Rope Triceps Pushdown | Placeholder |
| ex_reverse_grip_triceps_pushdown | Reverse-Grip Triceps Pushdown | Placeholder |
| ex_overhead_cable_triceps_extension | Overhead Cable Triceps Extension | Placeholder |
| ex_single_arm_cable_triceps_extension | Single-Arm Cable Triceps Extension | Placeholder |
| ex_dumbbell_overhead_triceps_extension | Dumbbell Overhead Triceps Extension | Placeholder |
| ex_single_arm_overhead_dumbbell_extension | Single-Arm Overhead Dumbbell Extension | Placeholder |
| ex_lying_ez_bar_triceps_extension | Lying EZ-Bar Triceps Extension | Placeholder |
| ex_dumbbell_skull_crusher | Dumbbell Skull Crusher | Placeholder |
| ex_close_grip_bench_press | Close-Grip Bench Press | Placeholder |
| ex_parallel_bar_triceps_dip | Parallel Bar Triceps Dip | Placeholder |
| ex_bench_dip | Bench Dip | Placeholder |
| ex_triceps_extension_machine | Triceps Extension Machine | Placeholder |
| ex_dumbbell_triceps_kickback | Dumbbell Triceps Kickback | Placeholder |
| ex_barbell_back_squat | Barbell Back Squat | Placeholder |
| ex_barbell_front_squat | Barbell Front Squat | Placeholder |
| ex_smith_machine_squat | Smith Machine Squat | Placeholder |
| ex_goblet_squat | Goblet Squat | Placeholder |
| ex_hack_squat | Hack Squat | Placeholder |
| ex_leg_press_45 | Leg Press 45° | Placeholder |
| ex_horizontal_leg_press | Horizontal Leg Press | Placeholder |
| ex_single_leg_press | Single-Leg Press | Placeholder |
| ex_leg_extension | Leg Extension | Placeholder |
| ex_single_leg_extension | Single-Leg Extension | Placeholder |
| ex_bulgarian_split_squat | Bulgarian Split Squat | Placeholder |
| ex_dumbbell_walking_lunge | Dumbbell Walking Lunge | Placeholder |
| ex_reverse_lunge | Reverse Lunge | Placeholder |
| ex_forward_lunge | Forward Lunge | Placeholder |
| ex_step_up | Step-Up | Placeholder |
| ex_sissy_squat | Sissy Squat | Placeholder |
| ex_belt_squat | Belt Squat | Placeholder |
| ex_cyclist_squat | Cyclist Squat | Placeholder |
| ex_romanian_deadlift | Romanian Deadlift | Placeholder |
| ex_dumbbell_romanian_deadlift | Dumbbell Romanian Deadlift | Placeholder |
| ex_stiff_leg_deadlift | Stiff-Leg Deadlift | Placeholder |
| ex_seated_leg_curl | Seated Leg Curl | Placeholder |
| ex_lying_leg_curl | Lying Leg Curl | Placeholder |
| ex_standing_single_leg_curl | Standing Single-Leg Curl | Placeholder |
| ex_nordic_hamstring_curl | Nordic Hamstring Curl | Placeholder |
| ex_glute_ham_raise | Glute-Ham Raise | Placeholder |
| ex_barbell_hip_thrust | Barbell Hip Thrust | Placeholder |
| ex_smith_machine_hip_thrust | Smith Machine Hip Thrust | Placeholder |
| ex_dumbbell_hip_thrust | Dumbbell Hip Thrust | Placeholder |
| ex_glute_bridge | Glute Bridge | Placeholder |
| ex_single_leg_glute_bridge | Single-Leg Glute Bridge | Placeholder |
| ex_cable_glute_kickback | Cable Glute Kickback | Placeholder |
| ex_glute_kickback_machine | Glute Kickback Machine | Placeholder |
| ex_hip_abduction_machine | Hip Abduction Machine | Placeholder |
| ex_hip_adduction_machine | Hip Adduction Machine | Placeholder |
| ex_cable_hip_abduction | Cable Hip Abduction | Placeholder |
| ex_cable_pull_through | Cable Pull-Through | Placeholder |
| ex_sumo_squat | Sumo Squat | Placeholder |
| ex_frog_pump | Frog Pump | Placeholder |
| ex_reverse_hyperextension | Reverse Hyperextension | Placeholder |
| ex_standing_calf_raise_machine | Standing Calf Raise Machine | Placeholder |
| ex_seated_calf_raise_machine | Seated Calf Raise Machine | Placeholder |
| ex_leg_press_calf_raise | Leg Press Calf Raise | Placeholder |
| ex_smith_machine_calf_raise | Smith Machine Calf Raise | Placeholder |
| ex_dumbbell_standing_calf_raise | Dumbbell Standing Calf Raise | Placeholder |
| ex_single_leg_calf_raise | Single-Leg Calf Raise | Placeholder |
| ex_donkey_calf_raise | Donkey Calf Raise | Placeholder |
| ex_tibialis_raise | Tibialis Raise | Placeholder |
| ex_crunch | Crunch | Placeholder |
| ex_cable_crunch | Cable Crunch | Placeholder |
| ex_machine_ab_crunch | Machine Ab Crunch | Placeholder |
| ex_reverse_crunch | Reverse Crunch | Placeholder |
| ex_lying_leg_raise | Lying Leg Raise | Placeholder |
| ex_hanging_knee_raise | Hanging Knee Raise | Placeholder |
| ex_hanging_leg_raise | Hanging Leg Raise | Placeholder |
| ex_captain_s_chair_leg_raise | Captain's Chair Leg Raise | Placeholder |
| ex_plank | Plank | Placeholder |
| ex_side_plank | Side Plank | Placeholder |
| ex_dead_bug | Dead Bug | Placeholder |
| ex_bird_dog | Bird Dog | Placeholder |
| ex_russian_twist | Russian Twist | Placeholder |
| ex_bicycle_crunch | Bicycle Crunch | Placeholder |
| ex_mountain_climber | Mountain Climber | Placeholder |
| ex_ab_wheel_rollout | Ab Wheel Rollout | Placeholder |
| ex_pallof_press | Pallof Press | Placeholder |
| ex_cable_woodchopper | Cable Woodchopper | Placeholder |
| ex_flutter_kicks | Flutter Kicks | Placeholder |
| ex_hollow_body_hold | Hollow Body Hold | Placeholder |
| ex_conventional_deadlift | Conventional Deadlift | Placeholder |
| ex_sumo_deadlift | Sumo Deadlift | Placeholder |
| ex_trap_bar_deadlift | Trap Bar Deadlift | Placeholder |
| ex_kettlebell_swing | Kettlebell Swing | Placeholder |
| ex_dumbbell_thruster | Dumbbell Thruster | Placeholder |
| ex_barbell_thruster | Barbell Thruster | Placeholder |
| ex_burpee | Burpee | Placeholder |
| ex_dumbbell_clean_and_press | Dumbbell Clean and Press | Placeholder |
| ex_barbell_clean_and_press | Barbell Clean and Press | Placeholder |
| ex_power_clean | Power Clean | Placeholder |
| ex_hang_clean | Hang Clean | Placeholder |
| ex_push_press | Push Press | Placeholder |
| ex_dumbbell_snatch | Dumbbell Snatch | Placeholder |
| ex_kettlebell_turkish_get_up | Kettlebell Turkish Get-Up | Placeholder |
| ex_farmer_s_carry | Farmer's Carry | Placeholder |
| ex_man_maker | Man Maker | Placeholder |

