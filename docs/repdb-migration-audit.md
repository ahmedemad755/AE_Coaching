# RepDB migration audit

## Baseline and recovery

The pre-migration working tree contains substantial tracked and untracked feature work. It has been preserved on `feature/repdb-free-catalog-20261103`, branched from `b8ac0a6a62bd7ac15659046959c4a9f29bf04366`. A ZIP of all existing `lib`, `test`, and `docs` files, package configuration, tracked/staged patches, Git status, and SHA-256 inventory is recorded in `build/repdb-audit/backup-path.txt`. This backup contains project files, not live device Hive or Firebase records. No storage reset, uninstall, clean, stash, deployment, or remote data write is part of this migration.

## Existing dependencies

| Area | Existing implementation | Compatibility requirement |
| --- | --- | --- |
| Bundled catalog | `lib/assets/data/exercises_catalog.json`, `ExerciseCatalogItem`, `ExerciseCatalogRepository` | Preserve all 180 legacy IDs/names as compatibility data; replace active browsing source only after validation. |
| Combined library | `CombinedExerciseLibraryCatalog`, `ExerciseLibraryItem`, `CustomExerciseRepository` | Custom exercises remain user-owned, with original custom IDs and names. No bundled test fixtures become real exercises. |
| Custom storage | `custom_exercises_$uid`, Hive adapter 6 | No adapter or record rewrite. Single-name custom records have no inferred translation or anatomy. |
| Template assignments | `WorkoutTemplateExerciseAssignment`, adapter 7; `WorkoutTemplateRepository` | Preserve assignment ID, snapshot name, position, planning targets and reference type. Only approved exact equivalences may change a reusable assignment's exercise ID. |
| Standard programs | `StandardWorkoutTemplateRepository`, `WorkoutProgramDraft`, draft Cubit/screens | Existing split/day/target content remains intact; resolve exact catalog aliases for newly imported programs and retain unmatched legacy snapshots. |
| Template editing | `TemplateExerciseManager`, `ManageTemplateExercisesDialog`, draft picker | Existing save, duplicate protection, target editing, reorder and cancellation behavior must remain. |
| Active session editing | `ActiveWorkoutEditService`, `SessionExerciseCubit`, `WorkoutSessionRepository` | Never migrate an active session or its captured assignment snapshot automatically. Existing session-only/program scopes remain. |
| Completed sessions | `WorkoutSession`, adapter 5, session repository/history Cubits | Completed records retain their captured identity, names and values. No catalog migration writes completed sessions. |
| Logged sets | `ExerciseSet`, adapter 0, `SessionExerciseRepository` | Names and session links are historical identity inputs; never rename/rekey sets or rewrite weights/reps/notes. |
| Analytics/PRs | Program analytics, personal-record detection, Home comparison services, My Progress | Existing calculations and grouping semantics must not change. Historical snapshot strings remain authoritative. |
| Artwork | `ExerciseIllustrations`, `ExerciseArtwork`, local reviewed WebP assets, provenance/license manifest | Retain 144 legacy mappings and all legacy assets for recovery/history; RepDB resolver owns new catalog media. |
| Videos | `ExerciseVideoLinks`, `url_launcher` external-browser behavior | Keep verified legacy links. Never infer a RepDB video URL from its name or transfer a link across an unreviewed variation. |
| UI/search | `ExercisePickerDialog`, `ExerciseLibraryCard`, `normalizeExerciseName`, metadata badges | Offline bilingual search, Arabic normalization, equipment/muscle filters, custom exercises and independent selection stay supported. |
| Favorites | No persisted exercise favorites implementation found | Do not create a decorative or nonfunctional favorites control. |
| DI/navigation | `workout_programs_dependencies.dart`, `AppRouter`, typed template import result | Keep the same repository/Cubit graph and typed navigation contracts; no duplicate active catalogs. |
| Settings/profile | Existing Personal Hub/App Settings and localization ARB/generated classes | Add visible source/license credits through existing settings navigation; do not change authentication/reminders. |
| Storage lifecycle | `UserStorageManager` owns supported per-user boxes and logout closure | Migration must be user-scoped and use existing queues; no unowned global box, adapter reset or cloud schema changes. |
| Firebase | Existing metadata synchronization paths for programs/templates/sessions | No new cloud sync fields, services, rules, deployment or production data operations. |

## Official source and license

Source: https://github.com/RepDB/exercise-dataset

Pinned commit: `66c4298af8d99b9dc397dad6699e508fb871d249`.

The inspected Free Tier License v1.0 permits personal/commercial **in-app** JSON and free-image use with visible `Exercise data by RepDB (repdb.co)` attribution. It prohibits redistribution as a dataset/dataset API and generative-AI derivation from artwork. Premium preview assets are evaluation-only and excluded from app assets. The complete license and attribution must ship with the integration. Arabic text enrichment is an app-local overlay; English source data remains unchanged. No artwork is sent to image-generation tools or used to generate substitute images.

## Inspected upstream schema

Schema 3 contains 701 records, including 574 strength, 88 stretching, 19 cardio, 16 Olympic and 4 plyometric exercises. It provides original slug IDs, EN/DE/ES names, descriptions, instructions and tips, primary/secondary muscles when recorded, body region, equipment where supplied, category, force type, mechanics, difficulty, goals/tags, unilateral/bodyweight flags, MET values and optional variation groups.

516 exercise records reference `start` and `peak`; 185 reference `main`. There are 1,217 image references and 1,217 unique referenced free image files, totalling 20,097,762 bytes in the pinned Git tree. No image path is shared between exercise records in this snapshot. All referenced paths exist in that tree. Missing equipment is not automatically classified as bodyweight unless the source bodyweight flag supports that distinction. One exercise (`savasana`) has no recorded primary muscle; missing anatomy remains missing. There are 3,684 English instruction steps (43,324 words), and no upstream Arabic localization.

## Migration boundary

RepDB canonical IDs are namespaced as `repdb:<original-id>`. Custom and unmatched legacy IDs remain unchanged. Exact legacy mappings require an explicit reviewed table; approximate/fuzzy candidates are never sufficient for automatic conversion. Session snapshots and logged sets are outside the migration write boundary. Template migration must skip active-session days, be serialized/idempotent, verify account ownership between asynchronous operations and preserve a rollback record before each write. Unmatched legacy references must remain visible and replaceable through the existing exercise picker.

## Validation/acceptance

Import and translation coverage, exact mapping evidence, tests, packaged APK verification and remaining review items are reported separately as implementation progresses. This audit is not a claim that the migration or Arabic review is complete.

## Continuation review — 2026-11-03

The existing snapshot and approved mappings were reused; no dataset download or import was repeated. The recovery archive remains intact, and no file in its baseline inventory has been deleted. Application assets retain the exact pinned source JSON and all 1,217 original free image files. Independently decoding every WebP with Pillow found zero failures.

The active repository loads only the 701 RepDB records; legacy lookup is a separate compatibility operation. Custom exercises are still read through their original per-user repository. All 35 exact aliases remain approved and all 145 other legacy references remain unmatched. New standard-program drafts retain visibly marked unmatched references until the user explicitly replaces them; the production importer rejects saving unresolved built-in references before writing a program. Historical sessions, sets, analytics and PR grouping are never rewritten by the catalog migration.

All 701 Arabic names were compared individually with the actual source names, equipment and descriptions in seven ordered review batches. Thirteen corrections clarify support position, hang starts, split stance, triceps load count, a Pilates reverse plank and the thoracic bridge. The app-local overlay records a context hash per reviewed name. The review is implementation text review, not a fitness professional's certification. Instructions have their own independent coverage and source hashes; a reviewed name never implies reviewed instructions.

Arabic instructions are individually authored and reviewed for 35 exercises (174 of 3,684 English steps). The remaining 666 exercises still require Arabic instruction translation/review. Arabic safety-tip translations are also pending; original English cues remain visible with a pending-translation notice. Complete outstanding IDs and step counts are in `repdb-translation-coverage.json`. Do not label this migration complete or release-ready.

A build-only offline OPUS-MT/ONNX drafting experiment was evaluated using public text only. Its first samples mistranslated anatomy and emitted stray language tokens. The experiment was stopped and none of its output was imported into app assets. The model/tool packages remain confined to ignored `build/repdb-audit`; no model, runtime translator, paid API, app dependency or backend was added. No RepDB artwork was used for generation.

Widget regressions now load the correct JSON asset for each requested path, use canonical IDs and actual source taxonomy, and isolate real file I/O from the widget test clock. Every one of the 701 cards is rendered in both languages at narrow width and increased text size. Additional checks cover detailed pose images, selection isolation, custom IDs, exact-alias exclusion, settings credits and explicit legacy replacement in the builder.

The dedicated branch preserves the pre-existing uncommitted feature work. No commits or pushes have been made. Validation only uses temporary test Hive directories; no device application data or production Firebase data has been accessed or modified.

## Recovery and maintenance

- Code recovery archive: the absolute path in `build/repdb-audit/backup-path.txt`; this is a source backup, not a backup of live Hive data. Do not reset or unpack over current work without first reviewing the inventory/diff.
- Local migration journals: application-support directory, `catalog-migrations/<URI-encoded-user-id>/repdb-v1.json`. A full before/after template snapshot is flushed before its Hive write. Interrupted prepared records are recovered idempotently.
- `LegacyExerciseMigration.rollback()` is an explicit maintenance API, not an automatic downgrade. It first disables this migration for that user's journal, restores only templates still identical to the recorded migrated version, and skips active days or subsequent user edits. It never rewrites sessions or sets. Tests exercise recovery and rollback against temporary Hive stores.
- A corrupt or unwritable journal fails the migration/load safely; do not delete it to bypass recovery. Preserve it for diagnosis. Legacy source records and images remain bundled and recoverable.
