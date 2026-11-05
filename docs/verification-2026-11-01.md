# Verification and stabilization — November 1, 2026

## Outcome

- Final full Flutter suite: **521 passed, 0 failed** (61 seconds reported).
- Final `flutter analyze --no-pub`: **No issues found** (36.3 seconds).
- Final `flutter build apk --debug --no-pub`: **passed**, Gradle 21.5 seconds.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Emulator verification: **blocked**, not passed. No app was installed, uninstalled, launched, or cleared during this task.
- Existing tracked and untracked work retained. No commits, pushes, Firebase deployments, production document changes, migrations, service activation, or synchronization-policy changes.

## Baseline

Flutter executable: `C:\flutter\src\flutter\flutter\bin\flutter.bat`.
Commands ran from the project root. `--no-pub` avoided dependency resolution.

The first sandboxed Flutter command stalled in the Windows launcher before loading tests because the SDK cache is outside the writable workspace. Only that command was interrupted; the command was retried with approved SDK-cache access. No SDK lock file was deleted and no IDE process was stopped.

### Focused baseline — 171 passed, 6 failed

```text
flutter test --no-pub
  test/features/workout/template_exercise_session_persistence_test.dart
  test/features/workout/workout_template_repository_test.dart
  test/features/workout/workout_session_repository_test.dart
  test/features/workout/workout_session_cubit_test.dart
  test/features/workout/session_exercise_test.dart
  test/core/storage
  test/core/session
  test/features/profile
  test/core/theme
  test/core/notifications
  test/features/workout/program_analytics_service_test.dart
  test/features/workout/program_analytics_cubit_test.dart
  test/features/workout/personal_record_detection_service_test.dart
  test/features/workout/workout_programs_screen_test.dart
```

Arguments above were passed in one command, not separate invocations.
Failures: four profile-photo storage cases, avatar semantics finder, Home activation finder.

### Other baseline commands

| Command | Result | Log |
| --- | --- | --- |
| `flutter analyze --no-pub` | Two async-context informational findings in Personal Hub; exit 1 | `build/verification-analyze-baseline.log` |
| `flutter test --no-pub --reporter expanded` | 499 passed, 13 failed | `build/verification-tests-baseline.log` |
| `flutter build apk --debug --no-pub` | Passed; Gradle 93.4 seconds | `build/verification-apk-baseline.log` |

Full-suite failures comprised the six focused failures plus five history-test setup failures, one log-set note icon assertion, and one workout weight-text assertion.

## Demonstrated bugs fixed

1. **Photo persistence on Windows:** `File.absolute.path` retained mixed separators. Ownership checks rejected the app's saved photo path, breaking reload, replacement cleanup, and removal. File URI normalization now canonicalizes separators and parent segments before checking ownership. Newly saved files use URI-derived paths. The same UID directories and Hive keys remain in use. Tests also cover legacy mixed separators and rejecting parent traversal without deleting an outside file.
2. **Reminder preference ownership:** an open Settings stream captured the initial UID forever. A new regression reproduced the wrong value after account switching. The stream now follows authentication changes, ignores outgoing-account preference writes, and cancels both subscriptions on disposal. Scheduling logic and preference keys are unchanged.
3. **Personal Hub async-context hazards:** mounted and account checks now run after photo decoding and after awaiting an error-path photo reload, before opening UI or using its context.

## Test stabilization and added coverage

- Avatar: enable semantics, match the merged label, dispose the semantics handle before test-end verification.
- Home activation: target the action by its plan card; create the interaction's asynchronous work in `runAsync` and await the actual loaded state instead of a fixed delay. Production activation code is unchanged.
- History: inject a fake set remote data source instead of accidentally resolving a real Firebase instance.
- Log-set note: assert the note field's prefix icon instead of assuming there is only one note icon in the whole dialog.
- Workout note: match the existing double-valued weight display (`40.0kg × 8`). Production formatting is unchanged.
- New Settings tests: Arabic RTL/English LTR, all three theme choices and persistence calls, reminder switching, denied permission display, logout callback.
- New profile repository tests: trimmed name-only writes, validation, wrong-account refusal, Firestore failure, Auth fallback failure, account switching during save. All use local fakes.
- Nine tests added in total; baseline 512 tests, final 521.

## Diagnostic reruns

The following targeted command was run during stabilization:

```text
flutter test --no-pub --reporter expanded
  test/features/profile
  test/core/theme
  test/core/notifications
  test/features/workout/workout_history_cubit_test.dart
  test/features/workout/workout_programs_screen_test.dart
  test/features/workout/log_set_dialog_test.dart
  test/features/workout/workout_finish_experience_test.dart
```

- First run (`build/verification-targeted-fixes.log`) was interrupted after a Home-test fake-async stall; it was not counted as passing.
- Next run (`build/verification-targeted-final.log`) completed with 65 passed, 1 failed: avatar test semantics-handle cleanup. That cleanup was corrected and all these tests subsequently passed in the final full suite.
- The single new reminder regression was run with `--plain-name 'an open preference stream follows account changes and logout'`: it failed before the service fix; its old-stream cleanup stalled and that owned run was interrupted. The isolated post-fix run passed 1/1.
- An intermediate analyzer run caught four warnings in new Firestore test doubles. Narrow, documented test-only ignores were added for Firestore's sealed/immutable reference annotations. No production lint was suppressed.

## Final commands and evidence

| Command | Result | Log |
| --- | --- | --- |
| `flutter test --no-pub --reporter expanded` | **521 passed, 0 failed**, exit 0 | `build/verification-tests-final.log` |
| `flutter analyze --no-pub` | **No issues found**, exit 0 | `build/verification-analyze-final.log` |
| `flutter build apk --debug --no-pub` | **Built app-debug.apk**, exit 0 | `build/verification-apk-final.log` |

The complete suite includes template partial-completion/stale-remote/reopen regressions, session snapshots, per-user Hive storage, theme/reminder persistence, scoped analytics, global PR detection, exercise library flows, Home plan ordering/activation, profile storage, settings, and name-update tests.

## Files changed by this stabilization task

Production:

- `lib/features/profile/data/local_profile_photo_store.dart`
- `lib/features/profile/presentation/personal_hub_screen.dart`
- `lib/core/notifications/inactivity_reminder_service.dart`

Tests:

- `test/features/profile/local_profile_photo_store_test.dart`
- `test/features/profile/profile_avatar_widget_test.dart`
- `test/features/profile/app_settings_screen_test.dart` (new)
- `test/features/profile/user_profile_repository_test.dart` (new)
- `test/core/notifications/inactivity_reminder_service_test.dart`
- `test/features/workout/workout_history_cubit_test.dart`
- `test/features/workout/workout_programs_screen_test.dart`
- `test/features/workout/log_set_dialog_test.dart`
- `test/features/workout/workout_finish_experience_test.dart`

Documentation: this report. Build and verification logs are generated under `build/`.
Other working-tree changes predate this task and were retained.

## Emulator verification and remaining limits

`adb devices -l` listed no connected devices. Existing AVDs were inspected, and Pixel_4 was started without wiping data, using `-no-snapshot-save`. Startup failed:

```text
Not enough space to create userdata partition.
Available: 5691.730469 MB ... need 7372.800000 MB.
```

No storage was deleted or resized. Windows app inventory also showed no running emulator.

All requested **on-device** checks remain unverified: Arabic/English rendering, Light/Dark/System behavior, gallery add/change/remove/preview, photo persistence after app restart, Edit Profile, Personal Hub/My Progress navigation, App Settings, logout confirmation, Home activation, and template persistence. Automated tests support many of these behaviors, but do not replace device testing. The new Settings test validates dispatch to the existing logout callback, not the full authenticated logout dialog and lifecycle.

Actual notification delivery, device-gallery behavior, live Firebase profile permissions, and authenticated screen/account-switch races still require a safe device/test-backend session. Production name, plan, and template edits were intentionally not exercised because this task forbids production Firestore mutations.

Existing policies remain: local-only profile photos and template assignments, app-wide language, per-user theme/reminder preferences, exact-name global PRs, and scoped completed-session analytics. The My Progress all-time PR display still uses the existing all-sets/global detector semantics; no eligibility definition was changed. The incomplete Firestore rules and dormant backend reminder scheduler were untouched.

**Readiness:** automated stabilization is complete and suitable for the next development stage, with device acceptance testing still outstanding. This is not a release sign-off.
