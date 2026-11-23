# RepDB Free migration — implementation and acceptance report

Date: 2026-11-03. **Status: incomplete; not release-ready.**

The existing working tree, import, mappings and recovery archive were continued. No dataset download or import was repeated in this continuation. Arabic instruction coverage remains below the requested acceptance threshold.

## Coverage

| Item | Verified result |
| --- | --- |
| Pinned dataset | `66c4298af8d99b9dc397dad6699e508fb871d249`, schema 3 |
| Active built-in exercises | 701, all canonical `repdb:<original-id>` IDs |
| Official English names/instructions | All 701 names and all 3,684 steps preserved exactly |
| Arabic names | 701 authored and context-reviewed; 13 corrections, zero duplicate Arabic names |
| Arabic instructions | 35 exercises / 174 steps individually authored and reviewed |
| Arabic instruction gap | **666 exercises / 3,510 steps still untranslated** |
| Arabic safety tips | Not yet translated; original English cues remain available with a pending notice |
| Artwork | 701 exercises covered: 516 start/peak pairs, 185 single images |
| Image files | 1,217 unique WebP files, 20,097,762 bytes; all hashes and full decodes pass |
| Imported premium assets | Zero |
| Approved legacy mappings | 35 exact equivalences retained |
| Unmatched legacy records | All 145 preserved; no approximate substitutions |
| Legacy media | Original 180 records, 144 illustration mappings and 106 MuscleWiki links unchanged |

The exact translation backlog is in [repdb-translation-coverage.json](repdb-translation-coverage.json). Missing source anatomy/equipment remains missing; notably `savasana` has no recorded primary muscle. Category, body-region, primary/secondary muscle and equipment taxonomy labels are tested for Arabic coverage across every source record.

## Implementation

- The active repository loads only RepDB built-ins. A separate compatibility loader resolves old references without appending them to active browsing. Existing custom exercises retain their IDs, user-owned Hive repository and original names.
- An immutable normalized model retains official IDs, English names, steps, taxonomy, source/version and pose paths. Version/coverage validation prevents stale Arabic overlays from being joined to the wrong catalog. Unreviewed instruction/tip drafts cannot be displayed as Arabic guidance.
- A central resolver serves bundled start, peak or single images. Cards use actual primary-muscle labels, equipment, bilingual names and independent selection. Details show pose images, all available anatomy, ordered instructions and original English fallbacks. Thumbnail decoding is bounded and uses Flutter's image cache; loading failures have explicit placeholders.
- Workout creation, draft replacement, template management and active-session pickers use the full-screen library without changing selection result types or scope/persistence callbacks. Details can select an exercise; the existing picker confirmation still performs persistence.
- Production standard-program saving rejects unresolved built-in references before any writes. Users resolve marked legacy rows through the existing Replace control. Tests cover an explicit replacement followed by saving, preserving assignment IDs, targets, ordering and the chosen language snapshot.
- The version-1 local template migration uses approved aliases only, a user-scoped write-ahead journal, owner checks and the existing edit queue. It skips archived and active-session days, preserves assignment/snapshot/target fields and supports interruption recovery, idempotency and guarded rollback. Sessions, sets, history and PR values are outside its write boundary.

The full dependency/recovery audit is in [repdb-migration-audit.md](repdb-migration-audit.md).

## Changed files

Compared with the pre-migration recovery inventory, 29 existing files were modified. The exact paths, added files and migration tools are in [repdb-change-inventory.json](repdb-change-inventory.json). No baseline file was deleted.

Application changes cover:

- Models: `exercise_catalog_item.dart`, `exercise_library_item.dart`.
- Repositories/services: `exercise_catalog_repository.dart`, `combined_exercise_library_catalog.dart`, `standard_workout_template_repository.dart`, `workout_template_import_service.dart`; new `legacy_exercise_migration.dart`.
- DI/Cubits: `workout_programs_dependencies.dart`, `workout_template_cubit.dart`, `workout_program_draft_cubit.dart`.
- New screens: `exercise_library_screen.dart`, `exercise_detail_screen.dart`, `exercise_sources_screen.dart`.
- Existing screens/widgets: active workout, workout draft, App Settings, library card/picker, inline/dialog template management and shared template layout.
- New widgets/helpers: `exercise_media_resolver.dart`, `exercise_taxonomy_labels.dart`.
- Assets/configuration: the `lib/assets/repdb/` bundle (1,217 images plus six metadata/license/overlay files), asset declarations in `pubspec.yaml`, localized ARB strings and their generated Dart files. No app dependency was added.
- Tests: three new `repdb_*_test.dart` files plus the affected catalog, card, bundled picker, active editing, standard-template and fixture regressions.
- Tools: pinned importer/legacy mapping generator, recorded Arabic name review and reviewed instructions, localization coverage/check tool and APK verifier. The rejected offline translation experiment is explicitly labeled experimental and does not write app assets.

## Verification

| Command/check | Result |
| --- | --- |
| `dart format` on the 35 changed/new migration Dart files | Passed |
| `flutter pub get` | Passed; existing package-constraint update notices only |
| `flutter analyze --no-pub` | **No issues found** |
| Focused migration/library/active-edit/template test command below | **47 tests passed** |
| `flutter test --no-pub --concurrency=2 --reporter expanded` | **635 tests passed** |
| All source image hashes and full WebP decoding | 1,217 passed, zero failures |
| `python -B tool/report_exercise_media.py --check` | Passed; original catalog and legacy mappings retained |
| Recovery archive ZIP integrity | Passed; no corrupt entry, no baseline file missing |
| Fresh Android Dart compilation | Passed |
| `flutter build apk --debug --no-pub` | **Passed** |
| `python -B tool/verify_repdb_apk.py` | **Passed**: exact 1,217 image hashes, current catalog/overlay/license, no premium assets and fresh kernel |
| `python -B tool/verify_exercise_media_apk.py` | **Passed**: original legacy catalog, 144 image mappings / 143 files and 105 distinct video URLs retained |

Focused command:

```powershell
flutter test --no-pub --concurrency=2 --reporter expanded `
  test/features/workout/repdb_catalog_test.dart `
  test/features/workout/repdb_migration_test.dart `
  test/features/workout/repdb_library_widget_test.dart `
  test/features/workout/exercise_picker_bundled_catalog_test.dart `
  test/features/workout/active_workout_edit_widget_test.dart `
  test/features/workout/standard_workout_templates_test.dart
```

Coverage includes all 701 cards in each language at narrow width/increased text size; Light/LTR and Dark/RTL; search normalization and combined filters; pose preview and independent selection; custom IDs and missing media; credits/license; canonical builder saving; unmatched references; active-session scopes and editing; completed snapshot immutability; account isolation; interrupted migration recovery; idempotency and rollback. Existing history, analytics, profile, persistence and navigation suites also passed in the full run.

Logs: `build/repdb-audit/focused-final.log`, `full-tests-final.log`, `analyze-final.log`, `pub-get-final.log`, `forcecompile-final.log`, `apk-build-final.log`. Preview images: `build/exercise-picker-previews/picker-en.png` and `picker-ar.png`.

No physical-device or emulator installation/restart walkthrough of this APK was performed. Widget tests and generated previews do not replace that remaining device verification.

## Debug APK and size

APK: `build/app/outputs/flutter-apk/app-debug.apk`.

- Size: **208,769,994 bytes** (208.77 MB / 199.10 MiB).
- SHA-256: `36347ea7d54d12fb6afa72e83c920a298eb019974070ec82d856bbf244dc7f89`.
- Prior debug APK: 140,147,550 bytes, SHA-256 `fed57a1b9d19dc481c09f50e01b6a0320bb935b79903bd0af11defc6afc652f8`.
- Total debug APK increase: **68,622,444 bytes (+48.96%)**.
- Actual compressed RepDB entries in the APK: **21,000,578 bytes**. The total debug-size difference is larger than the catalog payload and has not been attributed fully; do not present all 68.62 MB as artwork size. This debug build includes ARMv7, ARM64 and x86-64 Flutter engines. No Android configuration was changed to alter packaging, and release-size impact has not been measured.
- No duplicate ZIP paths, no premium assets and no translation model/runtime are packaged. Exact asset/kernel checks are recorded in [repdb-apk-verification.json](repdb-apk-verification.json).

## Licensing and data preservation

Source/license: [RepDB Free Tier License v1.0 at the pinned commit](https://github.com/RepDB/exercise-dataset/blob/66c4298af8d99b9dc397dad6699e508fb871d249/LICENSE-DATA.md). Commercial in-app use requires attribution. Visible `Exercise data by RepDB (repdb.co)` links and the full bundled license are available through App Settings → Data Sources and Exercise Details. No standalone RepDB dataset/API export, premium media, artwork generation, downloads at runtime or new cloud service was introduced. Arabic text is a documented app-local overlay; English JSON and image bytes are unchanged.

The free, build-only OPUS-MT sample failed terminology review, so it was stopped. None of its machine output was imported. It does not count toward Arabic coverage and its model/runtime is not shipped in the app.

The source backup is `build/repdb-audit/pre-migration-20261103-040415.zip` (5,505,673 bytes, 450 entries including recovery metadata). Protected source catalog, standard-template contents, legacy illustration/video registries, session model/adapters and Firebase configuration match that baseline. No live device Hive data or production Firestore was modified. No uninstall, application-data clear, rules deployment or Firebase-service activation occurred. No legacy asset was deleted.

Branch: `feature/repdb-free-catalog-20261103`. **Commits created: 0; pushes: 0.** The substantial pre-existing uncommitted feature work remains present; it has not been bundled into migration commits.

## Acceptance still outstanding

1. Individually translate and review the remaining 666 exercises' 3,510 instruction steps, preserving the exact movement/equipment/grip and step order. Do not substitute generic instructions or approve the rejected translation drafts.
2. Translate/review Arabic form cues; keep the explicit English fallback until then.
3. Perform a physical-device/emulator walkthrough of the new APK: language switching, offline catalog/search/filter, image/detail navigation, saved/custom templates, active-session editing, restart and account switching with existing data intact.
4. Investigate the debug-size difference beyond the measured 21 MB RepDB bundle before setting a production download-size expectation; no release APK was rebuilt in this task.
5. Treat this as a tested migration implementation with an open localization backlog, not a completed migration or production release.

## Run locally

```powershell
Set-Location -LiteralPath 'F:\my projects\maps\fittrack\ae_coaching'
$flutter = 'C:\flutter\src\flutter\flutter\bin\flutter.bat'
& $flutter pub get
& $flutter analyze
& $flutter test
& $flutter run
# Build without installing or clearing data:
& $flutter build apk --debug
# Recheck actual Arabic coverage:
python -B tool/review_repdb_localization.py
```
