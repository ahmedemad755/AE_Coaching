# Workout template route result typing

## Failing route and root cause

The failing named route is `AppNavigator.workoutTemplates`, whose route name is `standard-workout-templates`. `WorkoutProgramsScreen._openWorkoutTemplates` calls `Navigator.pushNamed<WorkoutTemplateImportResult>`. Flutter's named-route implementation checks that the returned route supports that result type. An untyped `MaterialPageRoute` created inside the non-generic `onGenerateRoute` factory defaults to `MaterialPageRoute<dynamic>`. It cannot satisfy the runtime cast to `Route<WorkoutTemplateImportResult?>?`, causing the reported `_TypeError` before the browser opens.

The working tree already contained a partial fix explicitly typing this named route. That work was preserved. The complete browser/preview/customization chain now makes its result type explicit; the regression tests both reproduce the former untyped-factory exception and exercise the actual current app router/caller.

## Complete result flow

| Caller / return point | Operation | Route / result type |
| --- | --- | --- |
| My Programs | `pushNamed<WorkoutTemplateImportResult>(AppNavigator.workoutTemplates)` | `Future<WorkoutTemplateImportResult?>` |
| AppRouter named factory | `MaterialPageRoute<WorkoutTemplateImportResult>(settings: settings, ...)` | Typed browser route |
| Template browser | `push<WorkoutTemplateImportResult>` with explicitly typed `MaterialPageRoute` | Typed preview route; nullable returned result |
| Preview, Use Template | `push<WorkoutTemplateImportResult>` with explicitly typed `MaterialPageRoute` | Typed draft route; nullable returned result |
| Draft, Save | `pop<WorkoutTemplateImportResult>(..., state.saved)` | Saved result |
| Preview and browser, after a save | `pop<WorkoutTemplateImportResult>(..., saved)` | Same saved result propagates to My Programs |
| Draft discard | `pop<WorkoutTemplateImportResult>(context)` | Null cancellation result; preview stays open |
| Browser / preview Back | Normal route pop | Null result; no save or My Programs refresh |

`PopScope<WorkoutTemplateImportResult>` on customization matches its route. `Navigator.push` and `pushNamed` already return `Future<T?>`; `T` does not need to become nullable to support cancellation. The source caller already checks null before refreshing programs or showing saved feedback. No unsafe result cast or production dynamic-route workaround is used.

The active-workout scope dialog explicitly pops `ActiveWorkoutEditScope`; the exercise picker pops `List<ExerciseLibraryItem>`; the target editor pops `WorkoutTemplateExerciseAssignment`. Cancel returns null for each dialog. Their existing `showDialog<T>` calls use these same types. Session-only versus Session + Program behavior is unchanged by this navigation fix.

## Files changed for this fix

- `lib/core/routes/app_router.dart`: preserve and document the typed named route and its RouteSettings; normalize formatting.
- `lib/features/workout/presentation/screens/workout_programs_screen.dart`: explicitly declare the nullable returned result at the existing typed named-route call.
- `lib/features/workout/presentation/screens/standard_workout_templates_screen.dart`: explicit preview/draft route generics and typed result forwarding.
- `lib/features/workout/presentation/screens/workout_program_draft_screen.dart`: matching PopScope and typed save/discard pops.
- `lib/features/workout/presentation/screens/active_workout_session_screen.dart`: explicit scope-dialog result/cancellation types.
- `lib/features/workout/presentation/widgets/exercise_picker_dialog.dart`: explicit selection and cancellation pop types.
- `lib/features/workout/presentation/widgets/workout_exercise_targets_dialog.dart`: explicit target and cancellation pop types.
- `test/features/workout/workout_template_navigation_test.dart`: former failure reproduction, actual My Programs/onGenerateRoute/save propagation, browser/preview cancellation and draft discard/keep behavior.
- `test/features/workout/active_workout_edit_widget_test.dart`: Add/Replace/target dialog return paths, removal/protection/retry, scopes, bilingual phone-sized layout and navigation/resume checks. Search selects a verified catalog entry before tapping its checkbox, including when other rows are outside the viewport.
- `docs/workout-template-navigation.md`: this report.
- `docs/active-workout-editing.md`: update the retained feature's final verification record.

The navigation change does not alter models, repositories, Hive adapters/storage policy, existing programs or workout history, Firebase configuration, catalog IDs, artwork or video mappings. Earlier authorized active-workout changes already present in the working tree are retained; their implementation details are documented separately in `active-workout-editing.md`.

## Verification

The navigation test's intentionally faulty fixture uses an explicitly dynamic route solely to reproduce the old factory. It catches and asserts the exact TypeError, rather than leaving an uncaught exception. Production tests use the real `WorkoutProgramsScreen`, its typed `pushNamed` call and `AppRouter.onGenerateRoute`; fake Cubits/import services avoid opening or writing user Hive/Firestore data.

Four navigation tests and four active-workout widget tests passed (`build/workout-navigation-widget.log`). They verify saving returns through all three routes once, cancellation/discard does not save or refresh programs, and English/dark/LTR plus Arabic/light/RTL editing at 360 x 780 returns to the active workout. The persisted scope behavior, logged-set protection and template/session snapshot regressions are covered by the broader focused/full checks.

| Check | Result | Evidence |
| --- | --- | --- |
| Navigation + active-edit widget tests | 8 passed, 8 seconds | `build/workout-navigation-widget.log` |
| Broader focused regressions | 41 passed, 18 seconds | `build/workout-navigation-focused.log` |
| `flutter analyze --no-pub` | No issues found, 17.4 seconds | `build/workout-navigation-analyze.log` |
| Full suite, `flutter test --no-pub --concurrency=2 --reporter expanded` | 591 passed, 84 seconds | `build/workout-navigation-full-tests.log` |
| Original media/catalog validator | Passed: 180 exercise IDs, 144 illustrations, 106 video mappings | `build/workout-navigation-media-check.log` |
| Fresh debug APK | Passed: forced compilation then `flutter build apk --debug --no-pub -v` | `build/workout-navigation-force-compile.log`, `build/workout-navigation-apk.log` |
| Packaged kernel / templates | Passed: APK kernel byte-for-byte equals fresh compiler output; current feature markers and original template JSON present | `build/workout-navigation-package-result.json` |
| Packaged media preservation | Passed: 144 mappings / 143 image files, 105 distinct URLs supporting the existing 106 video mappings; exact image/license/provenance bytes and catalog | `build/workout-navigation-package-verification.log` |

Focused command: `flutter test --no-pub --reporter expanded` followed by these paths:

- `test/features/workout/workout_template_navigation_test.dart`
- `test/features/workout/active_workout_edit_widget_test.dart`
- `test/features/workout/active_workout_edit_service_test.dart`
- `test/features/workout/template_exercise_session_persistence_test.dart`
- `test/features/workout/exercise_library_flow_test.dart`
- `test/features/workout/standard_workout_templates_widget_test.dart`
- `test/features/workout/program_analytics_theme_widget_test.dart`

APK: `build/app/outputs/flutter-apk/app-debug.apk` (208,544,540 bytes). SHA-256: `202e65f0e3b0b66d3765fe599e161f4b0735e08fe3f66228e6d872669923288b`. Existing Gradle/Flutter deprecation notices did not prevent compilation or packaging. No build configuration or SDK lock was changed to obtain the build.

No device was connected in the recorded `adb devices -l` check; physical-device testing remains unverified. No installation, data clearing, uninstall, Firebase change, deployment, commit or push was performed. The fix is ready for device acceptance testing using this fresh APK.
