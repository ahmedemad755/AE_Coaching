# Workout Templates runtime loading diagnosis

Updated November 5, 2026. No release APK was built. No application data was accessed or changed.

## Observed error and runtime flow

The Arabic text is `standardTemplateLoadError` in `lib/l10n/app_ar.arb`: `تعذر تحميل قوالب التمارين.` The generated Arabic localization exposes it through the same getter. `StandardWorkoutTemplatesScreen` displays it whenever `StandardWorkoutTemplatesCubit.state.failed` is true.

The production path is:

1. `AppNavigator.workoutTemplates` creates `StandardWorkoutTemplatesScreen` with dependencies from GetIt.
2. The screen creates `StandardWorkoutTemplatesCubit` and invokes `load()`.
3. `initWorkoutTemplates()` supplies `StandardWorkoutTemplateRepository(catalog: sl())`; the catalog registration supplies `ExerciseCatalogRepository()`.
4. The catalog loads `lib/assets/repdb/exercises.json` and `lib/assets/repdb/ar.json` through `rootBundle.loadString`, validates schema/version/overlay coverage, and creates canonical `repdb:` items.
5. The template repository loads `lib/assets/data/standard_workout_templates.json` through `rootBundle.loadString`. It validates template schema 1, split/variant/day structure, targets and recovery schedules, and directly resolves each exercise against the active catalog.
6. The repository constructs the immutable standard template models and caches the completed result. The Cubit emits success or the generic failed state.

Previously the Cubit used `catch (_)`, discarding the exception and stack. This explains why template-specific failures were absent from the logs. The change adds Debug-only diagnostics without changing the UI or validation rules.

## Verified asset and parser findings

- Current source and real Flutter test asset bundle load **7 splits, 9 variants, 39 days, 214 references and 38 unique canonical exercises** through the production constructors, parser and Cubit.
- The actual Flutter asset manifest contains all three inputs required for normal template loading. The `pubspec.yaml` paths are already correct; no registration changes were needed.
- Template schema 1 and RepDB schema 3 are separate, correctly supported formats. No JSON/model mismatch was reproduced in the current source.
- A copy of the APK installed on the USB device was pulled read-only on November 4, before the device became unavailable. It matches the workspace `app-debug.apk` byte-for-byte. It contains **214 legacy template IDs**, starting with `ex_barbell_bench_press`, rather than the current canonical source.
- The installed template asset has 63,153 bytes; the normalized source has 61,081 bytes. RepDB exercises, Arabic overlay, global legacy mappings and legacy catalog all match the corresponding current source files exactly.
- The APK's embedded debug kernel also contains the older template repository with `resolveReference()` fallback. Its loader is not the current canonical-only validator.

Exact hashes and asset comparisons are retained in `build/template-loading-runtime-20261104/asset-evidence.json`. The pulled APK and embedded loader source are retained in the same audit directory. They were not installed or modified.

## Reproduced exception and limits of the diagnosis

Two isolated diagnostic tests used the exact template bytes pulled from the device:

1. The recovered old repository implementation loads its old template asset successfully, with 23 exercise occurrences still legacy-only.
2. The **current** production repository given that **old** template asset throws:

```text
FormatException: Invalid or duplicate canonical exercise ID: ppl_3/push/ex_barbell_bench_press
```

Therefore a current-loader/stale-asset mismatch is a demonstrated failure mode, and the installed APK is demonstrably behind the current source. However, the original on-device exception was swallowed. The active Dart code in a hot-reloaded process can differ from its APK's embedded kernel, and that process was not captured. It would be incorrect to claim the reproduced exception is conclusively the original device exception, or to claim the old APK alone necessarily fails at loading.

The user confirmed that no external phone is currently available. A running IDE session and `emulator-5554` subsequently appeared. Read-only ADB inspection found the launcher foregrounded and no template-loading exception in the recent logs. The crash buffer contained a separate `ScheduledNotificationReceiver` / `FlutterLocalNotificationsPlugin.setSmallIcon` NullPointerException at 02:11:15 on November 5. That is not evidence of the template loading failure and was not changed in this task; the captured stack is retained in `build/template-loading-runtime-20261104/emulator-crash.log`. No IDE or app process was terminated, no device data was cleared, and no new APK was installed. The template UI has not been verified on a device in this task. No additional parser or identity-policy change was made based on an unverified hypothesis.

## Changes

- `lib/features/workout/presentation/cubit/standard_workout_templates_cubit.dart`: capture loading exceptions and stacks. In Debug, log the fixed asset path, a parser `FormatException` reason or the unexpected exception's type, and the loading stack. Unexpected exception payloads and application/user state are not logged. Release behavior is unchanged.
- `test/features/workout/standard_workout_template_asset_loading_test.dart`: five regressions for manifest registration, real production `rootBundle` loading/counts/IDs, rejection of stale legacy assets, Debug diagnostics plus successful retry, and suppression of arbitrary unexpected exception payloads.
- This report.

The temporary APK-snapshot probe was archived to `build/template-loading-runtime-20261104/installed-snapshot-probe-source.zip` and removed from the normal test tree. No legacy loader was added to application code.

## Reproduction when a device is available

Run from the current project root using the Flutter SDK configured in `android/local.properties`:

```powershell
& 'C:\flutter\src\flutter\flutter\bin\flutter.bat' devices
& 'C:\flutter\src\flutter\flutter\bin\flutter.bat' run --debug -d <device-id>
```

Stop the previous debug run before starting this fresh run so the current code and bundled assets are rebuilt and installed together. A restart of an old installed APK cannot update its packaged JSON. Hot reload can retain the GetIt repository singleton, parsed caches and failed catalog Future; it is insufficient evidence that new assets are being used.

Open My Programs, open Workout Templates, and tap Retry if needed. Capture the terminal block beginning `[WorkoutTemplates] Load failed` together with `[WorkoutTemplates] Loading stack trace`. It now identifies the parser reason and throwing location. The existing `[ExerciseCatalog]` diagnostics identify catalog/overlay failures earlier in the flow.

Do not uninstall the app or clear app data. No release build, Firebase change, legacy mapping rewrite or user-data migration is needed for this diagnostic workflow.

## Verification

The five new asset-loading tests and the two isolated installed-snapshot probes passed. The combined targeted run completed with 83 passing tests and one timeout: the existing test hashing all 1,217 RepDB images exceeded its default 30-second limit. It reported no hash mismatch. That test then passed in five seconds when rerun separately with a two-minute timeout, without changing its implementation or any assets. All 84 selected tests therefore have passing results; the initial combined run itself remains recorded as 83 passed and one timed out.

The combined command was `flutter test --no-pub` with these paths under `test/features/workout/`:

- `standard_workout_template_asset_loading_test.dart`
- `built_in_template_repdb_integration_test.dart`
- `built_in_template_repdb_widget_test.dart`
- `standard_workout_templates_test.dart`
- `standard_workout_templates_widget_test.dart`
- `workout_template_navigation_test.dart`
- `repdb_catalog_test.dart`
- `repdb_migration_test.dart`
- `template_exercise_session_persistence_test.dart`

Logs are retained in `build/template-loading-runtime-20261104/targeted-tests.log`, `asset-loading-tests.log`, and `installed-snapshot-probe-final.log`. `flutter analyze --no-pub` passed with no issues (432.9 seconds); see `analyze.log`. The isolated image-integrity retry passed; see `image-integrity-retry.log`. The five new tests also passed in their standalone run; the two snapshot probes are additional diagnostic checks rather than part of the 84 selected tests. The full suite was not rerun for this focused diagnostic task.

Snapshot SHA-256 comparisons confirm the repository, normalized template JSON, RepDB catalog, Arabic overlay, global legacy mappings, pubspec and Android app Gradle configuration were unchanged during this task. Only the Cubit diagnostics, new test and this report were changed. The changed Dart files were formatted. No APK build or device installation was performed during this correction.
