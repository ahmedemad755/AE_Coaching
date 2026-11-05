# Standard Workout Templates

Implemented November 2, 2026. Updated November 4: all 214 built-in exercise references now use canonical RepDB IDs (38 unique exercises). The active library is the existing 701-exercise RepDB catalog. See [the complete compatibility audit](standard-workout-template-mappings.md) for exact mappings, three first-party variation changes and preservation guarantees. Legacy exercise data and media remain available for existing records.

## Templates and navigation

My Programs now has a persistent **Workout Templates** entry, including when the program list is empty or loading. The flow is split → variant → day/exercise preview → Use Template → Customize Program → Save to My Programs. Saving returns to My Programs with a complete, inactive copy; it never changes the current active plan. Existing Make Active, rename, day editing and tracking flows remain available.

| Split | Variants | Ordered training days | Total weekly working sets |
| --- | --- | --- | ---: |
| Push Pull Legs | 3 days | Push, Pull, Legs | 44 |
| Push Pull Legs | 6 days | Push A, Pull A, Legs A, Push B, Pull B, Legs B | 72 |
| Upper / Lower | 4 days | Upper A, Lower A, Upper B, Lower B | 62 |
| Full Body | 3 days | Full Body A, B, C | 50 |
| Bro Split | 5 days | Chest, Back, Shoulders, Legs, Arms | 63 |
| Arnold Split | 3 days | Chest & Back, Shoulders & Arms, Legs | 48 |
| Arnold Split | 6 days | Chest & Back A, Shoulders & Arms A, Legs A, Chest & Back B, Shoulders & Arms B, Legs B | 68 |
| Hybrid | 5 days | Upper, Lower, Push, Pull, Legs | 66 |
| Anterior / Posterior | 4 days | Anterior A, Posterior A, Anterior B, Posterior B | 61 |

The Hybrid days use complementary exercise selections across the upper/lower and push/pull/legs portions. All variants include a seven-day suggested sequence with rest days; this is guidance, not a new persisted calendar or reminder schedule.

All 214 exercise occurrences resolve to 38 distinct existing stable catalog IDs. Names, equipment and muscle categories resolve from the bundled catalog. The November 4 update uses 35 approved exact matches and three documented first-party variation changes; no IDs were invented. [Complete exercise mapping, bilingual names and targets](standard-workout-template-mappings.md).

## Programming rationale

These are general adjustable hypertrophy starting plans, not claims that all seven splits have equal effectiveness or are individually optimized. Most entries use 2–3 working sets, compound rep ranges around 6–12, machine/accessory ranges around 10–20, and 60–180 seconds rest. Warm-ups are excluded; the UI explains progression within the rep range, leaving approximately 1–3 repetitions in reserve, and adjusting recovery/volume. Calf and abdominal work use rep targets, not timed-set semantics.

The [2026 ACSM position-stand summary](https://acsm.org/resistance-training-guidelines-update-2026/) supports progressive resistance training and identifies higher weekly per-muscle volume, around ten sets, as useful for hypertrophy. It does not establish a mandatory minimum for every exercise or make a single split universally best. Presets deliberately start at moderate volumes; pressing/pulling also load the arms and deltoids, so isolated-muscle catalog labels are not treated as a complete physiological volume model.

The [IUSCA position stand](https://journal.iusca.org/index.php/Journal/article/download/81/140/5323) supports distributing workload and allowing sufficient rest, particularly for demanding multijoint lifts. The selected rest/rep defaults are practical design choices within that evidence, not copied individualized prescriptions. Six-day plans have smaller A/B sessions rather than doubling the three-day sessions. Their preview explicitly describes the recovery demands. Three-day PPL/Arnold and the Bro split have lower direct training frequency per body part than Full Body/Upper-Lower; users can choose a different frequency or customize volume.

Anterior days emphasize chest, quadriceps, anterior/lateral deltoids, biceps and abs. Posterior days emphasize back, hamstrings, glutes, rear deltoids, triceps and calves. Compound overlap is intentional; no catalog muscle classification was changed. A/B selections vary exercises and load patterns.

## Editing and independent copies

Predefined data is bundled deterministic JSON, loaded through a validating repository. All exposed template/variant/day/exercise lists are immutable. Validation rejects missing variants, invalid day counts/recovery sequences, empty translations, invalid/duplicate exercise IDs and invalid targets before the template can be used.

Use Template creates an in-memory draft with fresh program, day and assignment IDs. Every day owns an independent immutable assignment list. Program/day names, add/remove/replace, ordering and set/rep/rest targets are editable before saving. Replacement retains the assignment ID, position and targets inside the independent copy. The existing bilingual exercise picker supports built-in and custom exercises; duplicates are rejected. Move-up/down controls work on touch devices without requiring drag gestures. Discard confirmation prevents accidental loss of an unsaved draft; discarding writes no program or workout days. Custom exercises explicitly created through the existing picker remain in the user's exercise library under its existing behavior.

The existing persisted day editor now exposes the shared target editor. Session screens display the original session's target snapshot as planning guidance. No planned target is counted as a logged set, no sets are auto-created, and no target changes PR, volume, workout-count or progress calculations. Existing manual rest-timer behavior is retained; a target is guidance and does not override the user's timer.

## Persistence and safety

The existing assignment adapter keeps type ID 7 and fields 0–3. Nullable fields 4–7 add working sets, rep minimum/maximum and rest seconds. Old four-field Hive bytes decode with absent targets. No data reset, box rename, schema migration, new box, adapter-ID change or rewrite of old user records is performed. The updated adapter also continues to store complete targets inside existing session snapshots.

Save uses the existing user-scoped program/day repositories. It validates the draft, checks account ownership around asynchronous boundaries and refuses to overwrite existing IDs. All new days are written before the inactive program is published. Ordinary local write failures attempt rollback of only the fresh draft IDs and retain the draft for retry. It never invokes cascade deletion, changes existing programs, or writes session/set/history boxes. Repeated Save is blocked while saving or after success.

Program/day metadata uses the existing remote data-source methods and existing payload shapes. Exercise assignments and their targets remain local, just like ordinary day assignments: they are **not newly synchronized to Firestore**. No Firebase configuration, rules, service enablement, backend scheduler or cloud collection was changed.

After local storage succeeds, the UI waits at most eight seconds overall for cloud acknowledgement after a successful local save. If offline/error/timed out, it reports that the complete local program is saved and cloud backup is incomplete; it does not invite a duplicate save. Already submitted Firestore writes keep the SDK's existing behavior. Reopening My Programs and the program's days uses the existing fetch/sync flow; there is no new background sync engine.

Hive has no transaction spanning the program and day boxes. The ordering/rollback protects existing records and prevents publishing a partially assembled program during normal failures; an abrupt process/storage failure in that small interval could leave unpublished new day records. No existing history is affected. Unsaved drafts are intentionally in memory and do not survive process termination.

## Files

New application files:

- lib/assets/data/standard_workout_templates.json
- lib/features/workout/data/models/standard_workout_template.dart
- lib/features/workout/data/models/workout_program_draft.dart
- lib/features/workout/data/repositories/standard_workout_template_repository.dart
- lib/features/workout/data/repositories/workout_template_import_service.dart
- lib/features/workout/presentation/cubit/standard_workout_templates_cubit.dart
- lib/features/workout/presentation/cubit/workout_program_draft_cubit.dart
- lib/features/workout/presentation/screens/standard_workout_templates_screen.dart
- lib/features/workout/presentation/screens/workout_program_draft_screen.dart
- lib/features/workout/presentation/widgets/workout_exercise_targets_dialog.dart

Modified application files:

- lib/features/workout/data/models/workout_template_exercise_assignment.dart and its adapter .g.dart
- lib/features/workout/data/repositories/workout_template_repository.dart
- lib/features/workout/presentation/widgets/template_exercise_manager.dart
- lib/features/workout/presentation/screens/workout_programs_screen.dart
- lib/features/workout/presentation/screens/active_workout_session_screen.dart (planning-target display only)
- lib/core/di/workout_programs_dependencies.dart
- lib/core/routes/app_router.dart
- lib/l10n/app_en.arb, app_ar.arb and their three generated localization classes
- pubspec.yaml (one bundled JSON asset; no new dependencies)

New development files: tool/build_standard_workout_templates.py, test/features/workout/standard_workout_templates_test.dart, standard_workout_templates_widget_test.dart, support/standard_template_fixtures.dart, this report and the mapping report. The authoring tool reproduces the fixed JSON from explicit canonical RepDB slugs and checks against the active catalog; it is not a runtime generator. Run it with `--check` for read-only verification. It preserves the detailed compatibility audit instead of overwriting it.

## Verification

Tests use temporary Hive directories and fake remote services; no production Firestore writes or device-data changes occur.

| Check | Result | Evidence |
| --- | --- | --- |
| Focused feature and persistence regressions | 70 passed | build/standard-templates-focused.log |
| Full Flutter suite | 561 passed, 65 seconds | build/standard-templates-full-tests.log |
| Final bilingual/RTL widget verification | 4 passed, 5 seconds | build/standard-templates-widget-final.log |
| flutter analyze --no-pub | No issues found, 13.3 seconds | build/standard-templates-analyze-final.log |
| Media/catalog preservation validator | Passed: 180 original IDs, 144 illustrations, 106 video mappings | tool/report_exercise_media.py --check |
| Debug APK | Passed; fresh package is 208,512,116 bytes | build/standard-templates-apk-final.log |
| APK template/code verification | Passed: exact bundled JSON, 7 splits, 9 variants, 39 days, 214 exercise occurrences and compiled feature markers | build/standard-templates-package-result.json |
| APK media preservation | Passed: 144 image mappings / 143 files, 105 distinct video URLs, exact artwork/license/provenance bytes and original catalog | build/standard-templates-package-verification.log |

The final RTL change isolates the Latin numeric rep range in the display widget using explicit escaped Unicode controls. This keeps 8–12 in the intended order in Arabic while avoiding raw directional controls in generated Dart files. The final bilingual widget rerun and analyzer both passed afterward.

The first APK command reported success but reused stale compiled output. Package inspection detected the missing template JSON and screens. The Flutter compilation task was rerun with Gradle's `--rerun-tasks --no-watch-fs`, followed by a successful normal Flutter APK build and inspection of the actual ZIP contents. No build configuration was changed and no build directory, SDK lock or user data was deleted. Existing Flutter/Gradle deprecation notices remain in the build log; they did not prevent compilation or packaging.

Final artifact: `build/app/outputs/flutter-apk/app-debug.apk`. SHA-256: `ef9262b3de0083492b6eea930e7c17211c9cb7d7c5f6297e285d3ac76430b580`.

Focused paths:

- test/features/workout/standard_workout_templates_test.dart
- test/features/workout/standard_workout_templates_widget_test.dart
- test/features/workout/template_exercise_session_persistence_test.dart
- test/features/workout/workout_template_repository_test.dart
- test/features/workout/workout_session_repository_test.dart
- test/features/workout/workout_programs_screen_test.dart
- test/features/workout/exercise_library_flow_test.dart

Command: flutter test --no-pub --reporter expanded followed by those paths. Full suite: flutter test --no-pub --reporter expanded. Analyzer: flutter analyze --no-pub. Build: flutter build apk --debug --no-pub -v.

The feature tests exercise all seven splits/nine variants, 39 days, exact catalog references and targets, immutable source data, independent copy IDs, all customization operations, retry/error/discard states, complete local saves, bounded pending-cloud acknowledgement, duplicate-save refusal, local-write rollback, mixed-case user IDs/account isolation, real legacy four-field Hive bytes, preserved session snapshots, and unchanged historical session/set records.

English/dark and Arabic/light offscreen library/customization captures are under build/standard-template-previews/. They were visually inspected. These are widget renders, not a claim of physical-device verification. No ADB device was connected; installation, touch interaction and process-restart behavior on a device remain unverified. The feature is ready for device acceptance testing and the next development stage, subject to that verification and the local-storage limitations described above.

No exercise illustration/link or image-completion specification was edited. No app uninstall/data clearing, deployment, commit, push, production-data modification or unrelated functionality change was performed.
