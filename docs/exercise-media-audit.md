# Complete exercise-media catalog audit

Audited November 1, 2026. This replaces the earlier 5-image/12-link sample audit.

## Exact coverage

**All 180 catalog entries were audited. Coverage remains incomplete; gaps are explicit.**

| Measure | Total |
| --- | ---: |
| Exercises audited | **180/180** |
| Verified illustration mappings | **144/180** |
| Distinct bundled illustration files | **143** |
| Missing illustrations / placeholders | **36** |
| Verified MuscleWiki page-link mappings | **106/180** |
| Distinct verified destination URLs | **105** |
| Missing/unverified video links / hidden actions | **74** |

This adds 139 illustration mappings and 94 page-link mappings to the previous implementation. No placeholder is included in the verified illustration count. Candidate URLs are never included in the verified-link count or runtime registry.

| Existing catalog category | Catalog | Illustrations | MuscleWiki links |
| --- | ---: | ---: | ---: |
| Chest | 22 | 19 | 15 |
| Back | 26 | 20 | 16 |
| Shoulders | 20 | 19 | 12 |
| Biceps | 14 | 12 | 8 |
| Triceps | 14 | 14 | 8 |
| Quadriceps | 18 | 12 | 9 |
| Hamstrings / glutes | 22 | 18 | 16 |
| Calves | 8 | 5 | 6 |
| Abs / core | 20 | 18 | 12 |
| Full body | 16 | 7 | 4 |
| **Total** | **180** | **144** | **106** |

The [180-row CSV](exercise-media-coverage.csv) includes both original names, IDs, muscles, equipment, movement/variation review requirements, source candidates, licensing, approved paths/URLs and separate image/video gap reasons. Each ID occurs exactly once. The same inventory is available in [JSON](exercise-media-review.json). Original classifications were retained, including the combined hamstrings/glutes category.

## Sources, licensing and provenance

Only these three artwork sources are bundled. All offer their artwork under **CC BY-SA 4.0**; attribution, the license, changes and upstream notices are retained.

| Source | Pinned revision | Mapped exercises |
| --- | --- | ---: |
| [Everkinetic / Greg Priday](https://github.com/everkinetic/data) | 446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6 | 14 |
| [Open Exercise Art / Alex Mollard](https://github.com/AlexMollard/Open-Exercise-Art) | 0f11ea4680746970e58b83448cdcdb64e4fc2793 | 124 |
| [Workout Guide / Bryl Lim](https://github.com/bryllim/workout-guide) | aac599224bb9780305239607ef98540b7e0ce389 | 6 |

Primary license records: [Everkinetic](https://github.com/everkinetic/data/blob/446bb9a3d0c3beb6b84f7c9d77dfc8af707a2ab6/LICENSE.md), [Open Exercise Art](https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/LICENSE-ARTWORK.md), [Workout Guide](https://github.com/bryllim/workout-guide/blob/aac599224bb9780305239607ef98540b7e0ce389/LICENSE-ASSETS).

Open Exercise Art's [provenance](https://github.com/AlexMollard/Open-Exercise-Art/blob/0f11ea4680746970e58b83448cdcdb64e4fc2793/PROVENANCE.md) identifies AI-generated drawings for Ironvellum, reviewed by its maintainer, with Everkinetic and Workout Guide as visual references. Those credits are preserved. No new image-generation service was used for this integration. Only artwork was imported; GPL conversion code from that project was not copied.

Workout Guide's per-frame Everkinetic attribution and previous modification history are retained in the image manifest. Redistributed artwork, adaptations and the artwork provenance collection remain under CC BY-SA 4.0. The application code, original exercise catalog and user workouts were not imported from these datasets.

All files live under lib/assets/exercise_illustrations/, including LICENSE.md, NOTICE.md, source-specific attribution/license/provenance files and manifest.json. The manifest records pinned source URLs, original byte hashes, converted byte hashes, dimensions, changes, review date and matching notes. Existing card credits, source links and offline license access remain available.

wger's public image metadata was also evaluated, with individual licenses rather than a repository-wide assumption. Reviewed candidates with missing creators, unclear upstream rights, contradictory equipment or stock-style diagrams without a verified rights chain were not imported. Examples and exact candidate records appear in the gap notes. A contributor's license label alone was not treated as sufficient proof of the upstream image rights. No wger images are redistributed.

No MuscleWiki images/videos were downloaded, cached as application media, embedded or rehosted. No free-exercise-db images were imported.

## Matching and image processing

The entire existing catalog and bilingual names were reviewed. Movement and grip/stance requirements are audit metadata inferred from the catalog's names/equipment, not changes to the exercise database.

Candidate discovery uses source catalogs and public search. It does not approve fuzzy name matches. Approved illustrations were visually inspected for equipment, pose and relevant variations; source-byte hashes freeze that review. Unresolved candidates remain placeholders.

Examples of prevented substitutions:

- Dumbbell Bulgarian split squat: the bodyweight drawing was rejected; a verified dumbbell Workout Guide frame was used.
- Standing calf machine: a bodyweight-only drawing was rejected; an original machine-based derivative was used.
- Spider curl: an EZ-bar/preacher illustration was rejected for the dumbbell catalog item.
- Reverse lunge: the dumbbell candidate was rejected for the bodyweight catalog item.
- Reverse hyperextension and machine glute kickback: ordinary back-extension/cable illustrations were not substituted for the specified machines.
- Captain's-chair leg raise: a bent-knee illustration was rejected.
- The previous neutral-grip incline-dumbbell candidate remains excluded; the new approved illustration depicts the conventional press.

Arnold press, push press and burpee use two complete reviewed frames side by side to show their distinguishing sequence. Other entries use a single still. Stills do not provide complete exercise instructions.

Images are WebP, at most 512 pixels on either axis, totaling **2,693,414 bytes**. White contour artwork is composited on charcoal for contrast in both themes; no pose, grip or equipment was redrawn. The original five image hashes are unchanged. Generic seated cable row and its close neutral-grip item share one explicitly reviewed image file, while retaining separate IDs and data.

The artwork is monochrome instructional line art with different source styles. It does not reproduce the reference's photorealistic muscle highlighting.

## Continuation: metadata-first batch verification

The continuation preserved all **142 previously approved ID/image/source records**, all **141 prior image-file byte hashes**, and all **106 verified MuscleWiki link reviews**. It reused the existing 180-row inventory and pinned source catalogs rather than restarting discovery.

`tool/batch_media_candidates.py` normalizes movement aliases (including reverse grip/underhand), checks equipment and opposed variations, ranks only unresolved IDs, and separates licensing holds from the download queue. Scores are candidate rankings, never approval evidence. Unknown equipment or missing variation terms still require visual review. Downloads are restricted to the already evaluated, pinned artwork repositories; MuscleWiki media and rights-uncertain wger images are excluded.

The continuation inspected **51 candidate placements in two labeled contact sheets of 26 and 25**, under `build/media-audit/continuation/`. Labels include stable ID, expected exercise/equipment, source key, missing variation terms, license and explicit unapproved status. Three ambiguous candidates were enlarged individually: underhand row grip, cable-fly direction and chest-supported machine mechanism.

Two additional images passed: Everkinetic's reverse-grip barbell row and Workout Guide's chest-supported plate-loaded machine row. The latter meets the existing catalog's machine/chest-pad/bilateral requirements; it is not claimed to depict a selectorized-only machine. Cable-fly direction remained insufficiently established and was not approved. Other reviewed candidates either showed an incorrect variation or left required details unconfirmed. Twelve gaps had no licensed candidate passing the metadata shortlist; each still received a recorded decision.

[Continuation review records](exercise-media-batch-review.json) retain all 38 gap decisions, numbered candidate placements, sheet digests, held provenance records and frozen prior image/source mappings. The 180-row CSV incorporates the more specific remaining-gap findings. Coverage increased from 142 to **144 illustrations**; MuscleWiki coverage remains **106**. No previously verified mapping was removed.

The [wger project license guidance](https://github.com/wger-project/wger/blob/master/README.md#license) requires checking individual content entries. Its contributor labels did not resolve the upstream rights questions already recorded, so no wger artwork was imported.

## MuscleWiki page verification and limitations

Every catalog entry received a public-page search; all initially unresolved entries also received a second search using exact phrases/equipment aliases. Literal URLs were discovered through public results and directory links, then the actual exercise pages were opened and matched against the catalog movement/equipment/variation.

[Page evidence](exercise-media-page-evidence.json) records all 106 approved ID-to-page matches, content-capture hashes and individual matching notes. This includes:

- 50 pages with an exercise-specific YouTube demonstration link.
- 56 pages with exercise-labeled demonstration media panels.
- **No claim that video playback was independently tested.**

Nineteen approved destinations use real locale-prefixed public URLs discovered during the audit. They can open in a website language different from the app. No English URLs were fabricated by stripping locale prefixes or deriving slugs from exercise names.

The generic cable-pullover and straight-arm cable-pulldown items share one page after checking that both specify the same standing high-cable shoulder-extension motion with fixed elbows. Their application IDs, assignments and histories remain independent.

The 74 unresolved entries retain unavailable video actions. Reasons include different equipment/grip/stance, unreadable public pages, contradictory guidance and unverified exact variations. For example, the plain reverse-lunge slug resolves to a medicine-ball exercise; the plain plank slug is a medicine-ball plank; the sumo-deadlift article contains conflicting grip guidance. Exact names alone were not sufficient.

Existing url_launcher external-application mode is reused, with localized failure handling and independent selection controls. There is no MuscleWiki API, paid API/subscription, backend, API key, embedded player, runtime asset download or new synchronization behavior. The OS chooses its external URL handler. Remote pages and media can change later.

## Verification results

| Check | Result | Evidence |
| --- | --- | --- |
| Offline inventory/provenance/registry/CSV validation | **Passed: all 180 IDs represented exactly once** | tool/report_exercise_media.py --check |
| Adversarial Python validator tests | **13 passed** (media, continuation and specification tests) | python -m unittest discover -s tool -p test_*media*.py -v |
| Focused media/picker/persistence Flutter tests | **84 passed** | build/exercise-media-batch-focused.log |
| Full Flutter suite | **546 passed**, 56 seconds | build/exercise-media-batch-full-tests.log |
| flutter analyze --no-pub | **No issues found**, 22.5 seconds | build/exercise-media-batch-analyze.log |
| flutter build apk --debug --no-pub -v | **Passed**, Gradle 150.2 seconds | build/exercise-media-batch-apk.log |
| Actual APK contents and compiled registry | **Passed** | build/exercise-media-batch-apk-verification.log |

Focused test paths, all under test/features/workout/:

- exercise_media_test.dart
- exercise_library_card_test.dart
- exercise_picker_dialog_test.dart
- exercise_picker_bundled_catalog_test.dart
- exercise_library_flow_test.dart
- template_exercise_session_persistence_test.dart
- workout_template_repository_test.dart
- workout_session_repository_test.dart

Command prefix: flutter test --no-pub --reporter expanded, followed by those eight paths. Full suite: flutter test --no-pub --reporter expanded.

New checks cover all 180 audit records, original catalog checksum, every mapped image/source/license, all 143 image decodes, rejected-variation fallbacks, recorded page-content reviews, exact registry/report agreement, invalid destinations, duplicate/missing IDs and false playback claims. Existing selection, bilingual search/filtering, custom exercises, RTL/LTR and workout persistence regressions pass.

The first focused run exposed an overly large scroll step in an existing picker test after more illustrated cards gained credits. A smaller step passes the same filter/search behavior. Only the test assumption changed.

Dark/LTR and light/RTL offscreen Flutter captures were regenerated and inspected under build/exercise-picker-previews/. They are not device screenshots. ADB listed no connected device/emulator, so physical browser launching and native visual interaction remain **unverified**.

APK: build/app/outputs/flutter-apk/app-debug.apk, **208,452,715 bytes**. The package verifier checked exact bytes for all 143 artwork files, license/provenance files, the unchanged catalog, and the new image/video registry strings in the compiled debug kernel. This guards against the stale-output issue seen in the earlier sample integration.

## Files changed in this catalog-wide task

- lib/features/workout/presentation/widgets/exercise_illustrations.dart: expanded reviewed illustration registry.
- lib/features/workout/presentation/widgets/exercise_video_links.dart: expanded reviewed URL registry; launcher logic unchanged.
- lib/assets/exercise_illustrations/: 143 WebP files total, manifest and license/attribution/provenance records.
- test/features/workout/exercise_media_test.dart: catalog-wide media/evidence/decode regressions.
- test/features/workout/exercise_picker_bundled_catalog_test.dart: robust scrolling with taller illustrated cards.
- tool/exercise_media_inventory.tsv, exercise_media_image_reviews.json, exercise_media_video_reviews.tsv and exercise_media_video_gaps.tsv: review decisions for every ID.
- tool/prepare_exercise_illustrations.py and report_exercise_media.py: reviewed asset generation, registries, reports and offline validation.
- tool/audit_media_candidates.py, collect_musclewiki_candidates.py, inspect_wger_candidates.py, download_media_candidates.py and build_media_page_evidence.py: development audit/reproduction helpers.
- tool/batch_media_candidates.py and test_batch_media_candidates.py: metadata-first continuation, contact sheets and preservation regressions.
- docs/exercise-media-batch-review.json: continuation decisions and frozen preservation evidence.
- tool/test_exercise_media_validation.py and verify_exercise_media_apk.py: negative validation tests and final-package checks.
- docs/exercise-media-coverage.csv, exercise-media-review.json, exercise-media-page-evidence.json and this report.

No new Flutter dependency or runtime network behavior was introduced in this task. Existing tracked/untracked work was preserved. No workout business logic, catalog ID/name/equipment/classification, assignment/order, template, session, set, PR/analytics, Hive schema, Firestore rule or Firebase configuration was changed. No app uninstall/data clearing, deployment, backend activation, commit or push occurred.

## Reproduction and remaining options

To continue only unresolved image entries with existing cached source metadata, run `python tool/batch_media_candidates.py --download --sheets`. It never edits approvals or runtime mappings. Inspect sheets, then record explicit manual decisions before using the integration tools below. Sheet files are generated review artifacts under ignored build output; their hashes and review decisions are retained in the continuation JSON.

With Python and Pillow 9.5.0 available:

1. Download only frozen approved source files: python tool/download_media_candidates.py --approved-only. This is development-only network access to the licensed artwork repositories.
2. Reproduce local images: python tool/prepare_exercise_illustrations.py. Retained legal files must remain present.
3. Regenerate reports/URL registry: python tool/report_exercise_media.py --write.
4. Format the two Dart registries and run python tool/report_exercise_media.py --check.
5. Run the tests/build above and python tool/verify_exercise_media_apk.py.

For the **36 named image gaps**, the safe remaining options are original in-house/volunteer illustrations with a recorded rights grant, additional verified CC BY/CC BY-SA contributions, or explicit permission from the actual upstream creators of the rejected rights-uncertain candidates. Do not silently reuse a related movement or remove notices.

For the **74 link gaps**, review the listed candidates directly where access/content was insufficient, resolve contradictory variation descriptions, or wait for an exact public demonstration. Keep actions unavailable until then. English-only canonical destinations for the 19 locale-prefixed links would also need direct discovery/verification rather than automatic URL rewriting.

The catalog-wide audit and integration are complete with documented gaps. Automated checks and the packaged APK pass. Full media coverage and physical-device acceptance remain unfinished.

## Original illustration preparation ? November 2, 2026

The requested original 38-gap inventory has been exported to [exercise-illustration-completion-inventory.csv](exercise-illustration-completion-inventory.csv). Two entries were resolved by the preceding batch review and are explicitly marked approved; the other **36 require original generation and visual review**. No approved mapping was discarded to recreate a 38-gap state.

A final bounded round issued one public licensed-illustration query per current gap. [Search records](exercise-illustration-final-search.json) retain all 36 query/ID/variation associations and inspected-result decisions. No additional asset was approved. A Commons power-clean result is actually an Android cleaner icon; the Bayesian-curl research figure is retained only as a movement reference. Public reference access does not grant permission to reuse a site's media.

Deliverables are [human-readable specifications](exercise-illustration-specifications.md), [structured specifications](exercise-illustration-specifications.json), [JSONL prompts](exercise-illustration-prompts.jsonl) and [generation manifest](exercise-illustration-generation-manifest.json). Every remaining exercise has start/end poses, joint movement, exact equipment, grip/stance, camera, muscles, ordered phases and exercise-specific rejection criteria. The original Arabic/English names and categories are copied from the unchanged catalog.

Image generation is available but intentionally has not been invoked: the user requested the inventory/specifications first. All 36 jobs say not_started, pending review, approved=false, with no output path/hash, provider, model or rights claim. Future generated outputs must record those details and pass visual/provenance review before local integration. The manifest freezes all 144 current image mappings and their byte hashes, plus the unchanged video-review digest. No generated illustration is included in coverage totals.

Authoring choices are explicit rather than silently changing catalog definitions. In particular, the proposed full-squat receiving position for Hang Clean requires reviewer confirmation; the catalog specifies the hang start but not catch depth. Several exercises require multi-phase sequences to prevent a correct-looking final pose from misrepresenting the movement.

Reproduce/check exports with tool/prepare_original_exercise_specs.py --write / --check. Hand-authored exercise briefs live in tool/original_exercise_illustration_briefs.json; export boundary and preservation checks live in tool/test_original_media_specs.py. The preparation itself changes only documentation/development tooling. Runtime verification above applies to the two reviewed image additions; no app logic changed after those checks.
