# Built-in workout templates: canonical RepDB compatibility audit

Updated November 4, 2026. This supersedes the earlier legacy-ID template mapping. Dataset commit: `66c4298af8d99b9dc397dad6699e508fb871d249`.

## Cause and scope

The bundled source used 214 legacy-ID references (38 unique exercises). The template loader accepted compatibility-only catalog entries, but the production importer correctly required active RepDB exercises when saving a new copy. Approved exact aliases resolved 191 entries; 23 entries (three variations) remained legacy-only. Every variant was affected. This was stale first-party template source, not rejection of valid RepDB IDs.

The source now contains only canonical `repdb:` IDs. The bundled-template loader requires direct membership in the active catalog and checks canonical per-day uniqueness. Saved-user-data resolution and the global exact-only legacy mapping are unchanged. No template-only runtime identity map was introduced.

## Complete variant audit

| Variant | Days | Exercise references | Previously unresolved | Canonical now | Duplicate exercises within a day |
| --- | ---: | ---: | ---: | ---: | ---: |
| ppl_3 | 3 | 16 | 2 | 16 | 0 |
| ppl_6 | 6 | 29 | 3 | 29 | 0 |
| upper_lower_4 | 4 | 26 | 3 | 26 | 0 |
| full_body_3 | 3 | 20 | 2 | 20 | 0 |
| bro_5 | 5 | 25 | 2 | 25 | 0 |
| arnold_3 | 3 | 18 | 2 | 18 | 0 |
| arnold_6 | 6 | 28 | 3 | 28 | 0 |
| hybrid_5 | 5 | 27 | 3 | 27 | 0 |
| anterior_posterior_4 | 4 | 25 | 3 | 25 | 0 |

Total: **7 splits, 9 variants, 39 days, 214 references, 38 unique canonical exercises, zero unresolved references**. Repetition across different days is intentional; no within-day canonical collisions were found. Split, variant and day IDs; schedules; order; sets; reps; and rest are structurally unchanged.

## Three first-party exercise choices

These are explicit changes to future built-in template content, not claims of exact equivalence and not new global legacy mappings. Reasoning below is based on the pinned dataset descriptions, primary/secondary muscles, equipment and instructions.

### Rope Triceps Pushdown -> Cable Tricep Pushdown

- `ex_rope_triceps_pushdown` -> `repdb:tricep-pushdown`, 9 entries.
- RepDB: cable equipment, isolation push, primary `triceps_brachii`; upright torso, elbows by sides, extend elbows against the cable.
- Preserves the bilateral cable elbow-extension/triceps accessory purpose and shoulder position. The straight-bar attachment replaces the rope: hand positions are constrained together rather than allowing rope separation/independent wrist orientation. Do not represent it as a rope exercise. RepDB does not specify grip orientation for this record.
- A V-bar alternative also changes attachment; an overhead extension additionally changes shoulder position. The straight-bar record preserves the requested pushdown movement with fewer positional changes.

### Leg Press 45 degrees -> Leg Press

- `ex_leg_press_45` -> `repdb:leg-press`, 9 entries.
- RepDB: `leg_press` equipment, compound push, primary `gluteus_maximus` and `quadriceps`, secondary `hamstrings`; bilateral shoulder-width feet, supported seat/platform, knee flexion then extension.
- Preserves the supported bilateral lower-body press role. The source does not establish a 45 degrees sled angle; the template now intentionally uses the generic Leg Press name and its actual media/instructions. Machine geometry and resistance/force relationships may differ. No claim of equivalent load between machines is made.
- Explicit horizontal or unilateral variants would add unsupported orientation/laterality restrictions; the generic record is the least restrictive fit.

### Neutral-Grip Lat Pulldown -> Close Grip Lat Pulldown

- `ex_neutral_grip_lat_pulldown` -> `repdb:close-grip-lat-pulldown`, 5 entries.
- RepDB: cable, compound pull, primary `latissimus_dorsi`; secondary `biceps_brachii`, `brachialis`, `posterior_deltoid`, `rhomboids`. Seated with thighs secured, palms facing each other, pull the close-grip handle to upper chest.
- Preserves neutral hand orientation, seated vertical pulling and back accessory purpose. The previously unspecified grip width is now explicitly close/narrow, changing hand spacing and the arm path. The displayed name describes the actual chosen variation.
- Wide overhand Lat Pulldown would change grip orientation and duplicate the existing wider-grip entry. V-Bar Lat Pulldown also fits the general pattern but fixes a particular attachment; the chosen record explicitly confirms both close and neutral grip.

## All unique source replacements

The 35 exact mappings below use previously approved mappings without changing them. Only the three rows marked variation change are new first-party content decisions.

| Previous source ID | Canonical source ID | RepDB English name | Occurrences | Decision |
| --- | --- | --- | ---: | --- |
| ex_barbell_back_squat | repdb:squat | Barbell Back Squat | 9 | approved exact mapping |
| ex_barbell_bench_press | repdb:bench-press | Barbell Bench Press | 9 | approved exact mapping |
| ex_barbell_hip_thrust | repdb:hip-thrust | Barbell Hip Thrust | 5 | approved exact mapping |
| ex_bulgarian_split_squat | repdb:bulgarian-split-squat | Bulgarian Split Squat | 4 | approved exact mapping |
| ex_cable_chest_fly | repdb:cable-fly | Cable Fly | 2 | approved exact mapping |
| ex_cable_crunch | repdb:cable-crunch | Cable Crunch | 8 | approved exact mapping |
| ex_cable_lateral_raise | repdb:cable-lateral-raise | Cable Lateral Raise | 3 | approved exact mapping |
| ex_cable_rear_delt_fly | repdb:cable-reverse-fly | Cable Reverse Fly | 5 | approved exact mapping |
| ex_chest_supported_dumbbell_row | repdb:chest-supported-db-row | Chest-Supported Dumbbell Row | 7 | approved exact mapping |
| ex_close_grip_bench_press | repdb:close-grip-bench-press | Close-Grip Bench Press | 1 | approved exact mapping |
| ex_dumbbell_bench_press | repdb:db-bench-press | Dumbbell Bench Press | 2 | approved exact mapping |
| ex_dumbbell_fly | repdb:db-fly | Dumbbell Fly | 1 | approved exact mapping |
| ex_dumbbell_lateral_raise | repdb:lateral-raise | Dumbbell Lateral Raise | 9 | approved exact mapping |
| ex_dumbbell_shoulder_press | repdb:dumbbell-shoulder-press | Dumbbell Shoulder Press | 8 | approved exact mapping |
| ex_ez_bar_curl | repdb:ez-bar-curl | EZ-Bar Curl | 9 | approved exact mapping |
| ex_hammer_curl | repdb:hammer-curl | Dumbbell Hammer Curl | 4 | approved exact mapping |
| ex_hanging_knee_raise | repdb:hanging-knee-raise | Hanging Knee Raise | 1 | approved exact mapping |
| ex_incline_barbell_bench_press | repdb:incline-bench-press | Incline Barbell Bench Press | 3 | approved exact mapping |
| ex_incline_dumbbell_curl | repdb:incline-db-curl | Incline Dumbbell Curl | 6 | approved exact mapping |
| ex_incline_dumbbell_press | repdb:incline-db-press | Incline Dumbbell Press | 9 | approved exact mapping |
| ex_lat_pulldown | repdb:lat-pulldown | Lat Pulldown | 9 | approved exact mapping |
| ex_leg_extension | repdb:leg-extension | Leg Extension | 6 | approved exact mapping |
| ex_leg_press_45 | repdb:leg-press | Leg Press | 9 | first-party variation change |
| ex_lying_leg_curl | repdb:leg-curl | Lying Leg Curl | 8 | approved exact mapping |
| ex_machine_chest_press | repdb:chest-press-machine | Machine Chest Press | 2 | approved exact mapping |
| ex_machine_shoulder_press | repdb:machine-shoulder-press | Machine Shoulder Press | 3 | approved exact mapping |
| ex_neutral_grip_lat_pulldown | repdb:close-grip-lat-pulldown | Close Grip Lat Pulldown | 5 | first-party variation change |
| ex_overhead_cable_triceps_extension | repdb:cable-overhead-tricep-extension | Cable Overhead Tricep Extension | 7 | approved exact mapping |
| ex_pec_deck_fly | repdb:pec-deck | Pec Deck | 1 | approved exact mapping |
| ex_reverse_crunch | repdb:reverse-crunches | Reverse Crunches | 2 | approved exact mapping |
| ex_reverse_pec_deck | repdb:machine-reverse-fly | Machine Reverse Fly | 7 | approved exact mapping |
| ex_romanian_deadlift | repdb:romanian-deadlift | Romanian Deadlift | 9 | approved exact mapping |
| ex_rope_triceps_pushdown | repdb:tricep-pushdown | Cable Tricep Pushdown | 9 | first-party variation change |
| ex_seated_cable_row | repdb:seated-cable-row | Seated Cable Row | 9 | approved exact mapping |
| ex_seated_calf_raise_machine | repdb:seated-calf-raise | Seated Calf Raise | 6 | approved exact mapping |
| ex_seated_leg_curl | repdb:seated-leg-curl | Seated Leg Curl | 6 | approved exact mapping |
| ex_standing_calf_raise_machine | repdb:standing-calf-raise | Standing Calf Raise | 9 | approved exact mapping |
| ex_straight_arm_cable_pulldown | repdb:straight-arm-pulldown | Straight-Arm Pulldown | 2 | approved exact mapping |

## Complete template exercise inventory

Names below come directly from RepDB and the existing Arabic overlay. All 38 unique exercises have English instructions, Arabic names, recorded primary muscles and existing offline WebP media. Reverse Crunches has no equipment value in the upstream data and is explicitly bodyweight; missing metadata was not invented. Three exercises (the three content choices above) currently use the existing English instruction fallback because Arabic instructions are not yet reviewed. The other 35 have reviewed Arabic instructions. No translation or media data was edited.

| Variant | Day | Canonical exercise ID | English | Arabic | Sets | Reps | Rest seconds |
| --- | --- | --- | --- | --- | ---: | --- | ---: |
| ppl_3 | Push | repdb:bench-press | Barbell Bench Press | بنش بار مستوي | 3 | 6-10 | 180 |
| ppl_3 | Push | repdb:incline-db-press | Incline Dumbbell Press | بنش دمبل مائل | 3 | 8-12 | 150 |
| ppl_3 | Push | repdb:dumbbell-shoulder-press | Dumbbell Shoulder Press | ضغط كتف بالدمبل | 2 | 8-12 | 150 |
| ppl_3 | Push | repdb:lateral-raise | Dumbbell Lateral Raise | رفرفة جانبي بالدمبل | 3 | 12-20 | 90 |
| ppl_3 | Push | repdb:tricep-pushdown | Cable Tricep Pushdown | دفع بار الكابل لأسفل للترايسبس | 3 | 12-15 | 90 |
| ppl_3 | Pull | repdb:lat-pulldown | Lat Pulldown | سحب أمامي | 3 | 8-12 | 150 |
| ppl_3 | Pull | repdb:seated-cable-row | Seated Cable Row | تجديف كابل جالس | 3 | 8-12 | 150 |
| ppl_3 | Pull | repdb:machine-reverse-fly | Machine Reverse Fly | فراشة عكسية جهاز للكتف الخلفي | 3 | 12-15 | 90 |
| ppl_3 | Pull | repdb:ez-bar-curl | EZ-Bar Curl | بايسبس ببار EZ | 3 | 10-15 | 90 |
| ppl_3 | Pull | repdb:hammer-curl | Dumbbell Hammer Curl | بايسبس هامر بالدمبل | 2 | 10-15 | 90 |
| ppl_3 | Legs | repdb:squat | Barbell Back Squat | سكوات بار خلفي | 3 | 6-10 | 180 |
| ppl_3 | Legs | repdb:romanian-deadlift | Romanian Deadlift | ديدليفت روماني بالبار | 3 | 8-10 | 180 |
| ppl_3 | Legs | repdb:leg-press | Leg Press | ضغط الرجلين جهاز | 2 | 10-15 | 180 |
| ppl_3 | Legs | repdb:leg-curl | Lying Leg Curl | رجل خلفي نايم جهاز | 3 | 12-15 | 90 |
| ppl_3 | Legs | repdb:standing-calf-raise | Standing Calf Raise | رفعة سمانة واقف جهاز | 3 | 10-20 | 90 |
| ppl_3 | Legs | repdb:cable-crunch | Cable Crunch | كرنش كابل | 2 | 10-20 | 60 |
| ppl_6 | Push A | repdb:bench-press | Barbell Bench Press | بنش بار مستوي | 3 | 6-10 | 180 |
| ppl_6 | Push A | repdb:incline-db-press | Incline Dumbbell Press | بنش دمبل مائل | 2 | 8-12 | 150 |
| ppl_6 | Push A | repdb:dumbbell-shoulder-press | Dumbbell Shoulder Press | ضغط كتف بالدمبل | 2 | 8-12 | 150 |
| ppl_6 | Push A | repdb:lateral-raise | Dumbbell Lateral Raise | رفرفة جانبي بالدمبل | 3 | 12-20 | 90 |
| ppl_6 | Push A | repdb:tricep-pushdown | Cable Tricep Pushdown | دفع بار الكابل لأسفل للترايسبس | 2 | 12-15 | 90 |
| ppl_6 | Pull A | repdb:lat-pulldown | Lat Pulldown | سحب أمامي | 3 | 8-12 | 150 |
| ppl_6 | Pull A | repdb:seated-cable-row | Seated Cable Row | تجديف كابل جالس | 3 | 8-12 | 150 |
| ppl_6 | Pull A | repdb:machine-reverse-fly | Machine Reverse Fly | فراشة عكسية جهاز للكتف الخلفي | 2 | 12-15 | 90 |
| ppl_6 | Pull A | repdb:ez-bar-curl | EZ-Bar Curl | بايسبس ببار EZ | 2 | 10-15 | 90 |
| ppl_6 | Pull A | repdb:hammer-curl | Dumbbell Hammer Curl | بايسبس هامر بالدمبل | 2 | 10-15 | 90 |
| ppl_6 | Legs A | repdb:squat | Barbell Back Squat | سكوات بار خلفي | 3 | 6-10 | 180 |
| ppl_6 | Legs A | repdb:romanian-deadlift | Romanian Deadlift | ديدليفت روماني بالبار | 3 | 8-10 | 180 |
| ppl_6 | Legs A | repdb:leg-extension | Leg Extension | فرد الرجلين جهاز | 2 | 12-15 | 90 |
| ppl_6 | Legs A | repdb:leg-curl | Lying Leg Curl | رجل خلفي نايم جهاز | 2 | 12-15 | 90 |
| ppl_6 | Legs A | repdb:standing-calf-raise | Standing Calf Raise | رفعة سمانة واقف جهاز | 3 | 10-20 | 90 |
| ppl_6 | Push B | repdb:incline-bench-press | Incline Barbell Bench Press | بنش بار مائل | 3 | 6-10 | 180 |
| ppl_6 | Push B | repdb:chest-press-machine | Machine Chest Press | ضغط صدر جهاز | 2 | 8-12 | 150 |
| ppl_6 | Push B | repdb:machine-shoulder-press | Machine Shoulder Press | ضغط كتف جهاز | 2 | 8-12 | 150 |
| ppl_6 | Push B | repdb:cable-lateral-raise | Cable Lateral Raise | رفرفة جانبي بالكابل | 3 | 12-20 | 90 |
| ppl_6 | Push B | repdb:cable-overhead-tricep-extension | Cable Overhead Tricep Extension | فرد الترايسبس بالكابل فوق الرأس | 2 | 12-15 | 90 |
| ppl_6 | Pull B | repdb:close-grip-lat-pulldown | Close Grip Lat Pulldown | سحب أمامي بقبضة ضيقة متوازية | 3 | 8-12 | 150 |
| ppl_6 | Pull B | repdb:chest-supported-db-row | Chest-Supported Dumbbell Row | تجديف دمبل مع إسناد الصدر | 3 | 8-12 | 150 |
| ppl_6 | Pull B | repdb:cable-reverse-fly | Cable Reverse Fly | تفتيح عكسي بالكابل للكتف الخلفي | 2 | 12-15 | 90 |
| ppl_6 | Pull B | repdb:incline-db-curl | Incline Dumbbell Curl | بايسبس دمبل على مقعد مائل | 2 | 10-15 | 90 |
| ppl_6 | Legs B | repdb:leg-press | Leg Press | ضغط الرجلين جهاز | 3 | 10-15 | 180 |
| ppl_6 | Legs B | repdb:hip-thrust | Barbell Hip Thrust | دفع الحوض بالبار | 2 | 8-12 | 150 |
| ppl_6 | Legs B | repdb:bulgarian-split-squat | Bulgarian Split Squat | سكوات بلغاري بالدمبل | 2 | 8-12 | 150 |
| ppl_6 | Legs B | repdb:seated-leg-curl | Seated Leg Curl | رجل خلفي جالس جهاز | 3 | 12-15 | 90 |
| ppl_6 | Legs B | repdb:seated-calf-raise | Seated Calf Raise | سمانة جالس جهاز | 3 | 12-20 | 90 |
| upper_lower_4 | Upper A | repdb:bench-press | Barbell Bench Press | بنش بار مستوي | 3 | 6-10 | 180 |
| upper_lower_4 | Upper A | repdb:seated-cable-row | Seated Cable Row | تجديف كابل جالس | 3 | 8-12 | 150 |
| upper_lower_4 | Upper A | repdb:incline-db-press | Incline Dumbbell Press | بنش دمبل مائل | 2 | 8-12 | 150 |
| upper_lower_4 | Upper A | repdb:lat-pulldown | Lat Pulldown | سحب أمامي | 2 | 8-12 | 150 |
| upper_lower_4 | Upper A | repdb:lateral-raise | Dumbbell Lateral Raise | رفرفة جانبي بالدمبل | 2 | 12-20 | 90 |
| upper_lower_4 | Upper A | repdb:ez-bar-curl | EZ-Bar Curl | بايسبس ببار EZ | 2 | 10-15 | 90 |
| upper_lower_4 | Upper A | repdb:tricep-pushdown | Cable Tricep Pushdown | دفع بار الكابل لأسفل للترايسبس | 2 | 12-15 | 90 |
| upper_lower_4 | Lower A | repdb:squat | Barbell Back Squat | سكوات بار خلفي | 3 | 6-10 | 180 |
| upper_lower_4 | Lower A | repdb:romanian-deadlift | Romanian Deadlift | ديدليفت روماني بالبار | 3 | 8-10 | 180 |
| upper_lower_4 | Lower A | repdb:leg-extension | Leg Extension | فرد الرجلين جهاز | 2 | 12-15 | 90 |
| upper_lower_4 | Lower A | repdb:leg-curl | Lying Leg Curl | رجل خلفي نايم جهاز | 2 | 12-15 | 90 |
| upper_lower_4 | Lower A | repdb:standing-calf-raise | Standing Calf Raise | رفعة سمانة واقف جهاز | 3 | 10-20 | 90 |
| upper_lower_4 | Lower A | repdb:cable-crunch | Cable Crunch | كرنش كابل | 2 | 10-20 | 60 |
| upper_lower_4 | Upper B | repdb:incline-bench-press | Incline Barbell Bench Press | بنش بار مائل | 3 | 6-10 | 180 |
| upper_lower_4 | Upper B | repdb:chest-supported-db-row | Chest-Supported Dumbbell Row | تجديف دمبل مع إسناد الصدر | 3 | 8-12 | 150 |
| upper_lower_4 | Upper B | repdb:dumbbell-shoulder-press | Dumbbell Shoulder Press | ضغط كتف بالدمبل | 2 | 8-12 | 150 |
| upper_lower_4 | Upper B | repdb:close-grip-lat-pulldown | Close Grip Lat Pulldown | سحب أمامي بقبضة ضيقة متوازية | 2 | 8-12 | 150 |
| upper_lower_4 | Upper B | repdb:machine-reverse-fly | Machine Reverse Fly | فراشة عكسية جهاز للكتف الخلفي | 2 | 12-15 | 90 |
| upper_lower_4 | Upper B | repdb:hammer-curl | Dumbbell Hammer Curl | بايسبس هامر بالدمبل | 2 | 10-15 | 90 |
| upper_lower_4 | Upper B | repdb:cable-overhead-tricep-extension | Cable Overhead Tricep Extension | فرد الترايسبس بالكابل فوق الرأس | 2 | 12-15 | 90 |
| upper_lower_4 | Lower B | repdb:leg-press | Leg Press | ضغط الرجلين جهاز | 3 | 10-15 | 180 |
| upper_lower_4 | Lower B | repdb:hip-thrust | Barbell Hip Thrust | دفع الحوض بالبار | 2 | 8-12 | 150 |
| upper_lower_4 | Lower B | repdb:bulgarian-split-squat | Bulgarian Split Squat | سكوات بلغاري بالدمبل | 2 | 8-12 | 150 |
| upper_lower_4 | Lower B | repdb:seated-leg-curl | Seated Leg Curl | رجل خلفي جالس جهاز | 3 | 12-15 | 90 |
| upper_lower_4 | Lower B | repdb:seated-calf-raise | Seated Calf Raise | سمانة جالس جهاز | 3 | 12-20 | 90 |
| upper_lower_4 | Lower B | repdb:hanging-knee-raise | Hanging Knee Raise | رفع الركبتين مع التعلق | 2 | 10-20 | 60 |
| full_body_3 | Full Body A | repdb:squat | Barbell Back Squat | سكوات بار خلفي | 3 | 6-10 | 180 |
| full_body_3 | Full Body A | repdb:bench-press | Barbell Bench Press | بنش بار مستوي | 3 | 6-10 | 180 |
| full_body_3 | Full Body A | repdb:seated-cable-row | Seated Cable Row | تجديف كابل جالس | 3 | 8-12 | 150 |
| full_body_3 | Full Body A | repdb:leg-curl | Lying Leg Curl | رجل خلفي نايم جهاز | 2 | 12-15 | 90 |
| full_body_3 | Full Body A | repdb:lateral-raise | Dumbbell Lateral Raise | رفرفة جانبي بالدمبل | 2 | 12-20 | 90 |
| full_body_3 | Full Body A | repdb:standing-calf-raise | Standing Calf Raise | رفعة سمانة واقف جهاز | 2 | 10-20 | 90 |
| full_body_3 | Full Body A | repdb:cable-crunch | Cable Crunch | كرنش كابل | 2 | 10-20 | 60 |
| full_body_3 | Full Body B | repdb:romanian-deadlift | Romanian Deadlift | ديدليفت روماني بالبار | 3 | 8-10 | 180 |
| full_body_3 | Full Body B | repdb:incline-db-press | Incline Dumbbell Press | بنش دمبل مائل | 3 | 8-12 | 150 |
| full_body_3 | Full Body B | repdb:lat-pulldown | Lat Pulldown | سحب أمامي | 3 | 8-12 | 150 |
| full_body_3 | Full Body B | repdb:leg-extension | Leg Extension | فرد الرجلين جهاز | 2 | 12-15 | 90 |
| full_body_3 | Full Body B | repdb:ez-bar-curl | EZ-Bar Curl | بايسبس ببار EZ | 2 | 10-15 | 90 |
| full_body_3 | Full Body B | repdb:tricep-pushdown | Cable Tricep Pushdown | دفع بار الكابل لأسفل للترايسبس | 2 | 12-15 | 90 |
| full_body_3 | Full Body C | repdb:leg-press | Leg Press | ضغط الرجلين جهاز | 3 | 10-15 | 180 |
| full_body_3 | Full Body C | repdb:db-bench-press | Dumbbell Bench Press | بنش دمبل مستوي | 3 | 8-12 | 150 |
| full_body_3 | Full Body C | repdb:chest-supported-db-row | Chest-Supported Dumbbell Row | تجديف دمبل مع إسناد الصدر | 3 | 8-12 | 150 |
| full_body_3 | Full Body C | repdb:seated-leg-curl | Seated Leg Curl | رجل خلفي جالس جهاز | 3 | 12-15 | 90 |
| full_body_3 | Full Body C | repdb:dumbbell-shoulder-press | Dumbbell Shoulder Press | ضغط كتف بالدمبل | 2 | 8-12 | 150 |
| full_body_3 | Full Body C | repdb:seated-calf-raise | Seated Calf Raise | سمانة جالس جهاز | 2 | 12-20 | 90 |
| full_body_3 | Full Body C | repdb:reverse-crunches | Reverse Crunches | كرنش عكسي | 2 | 10-20 | 60 |
| bro_5 | Chest | repdb:bench-press | Barbell Bench Press | بنش بار مستوي | 3 | 6-10 | 180 |
| bro_5 | Chest | repdb:incline-db-press | Incline Dumbbell Press | بنش دمبل مائل | 3 | 8-12 | 150 |
| bro_5 | Chest | repdb:db-fly | Dumbbell Fly | تفتيح دمبل مستوي | 2 | 12-15 | 90 |
| bro_5 | Chest | repdb:pec-deck | Pec Deck | تفتيح صدر على جهاز البيك ديك | 2 | 12-15 | 90 |
| bro_5 | Back | repdb:lat-pulldown | Lat Pulldown | سحب أمامي | 3 | 8-12 | 150 |
| bro_5 | Back | repdb:seated-cable-row | Seated Cable Row | تجديف كابل جالس | 3 | 8-12 | 150 |
| bro_5 | Back | repdb:chest-supported-db-row | Chest-Supported Dumbbell Row | تجديف دمبل مع إسناد الصدر | 2 | 8-12 | 150 |
| bro_5 | Back | repdb:straight-arm-pulldown | Straight-Arm Pulldown | سحب كابل بذراعين مستقيمين | 2 | 12-15 | 90 |
| bro_5 | Back | repdb:machine-reverse-fly | Machine Reverse Fly | فراشة عكسية جهاز للكتف الخلفي | 2 | 12-15 | 90 |
| bro_5 | Shoulders | repdb:dumbbell-shoulder-press | Dumbbell Shoulder Press | ضغط كتف بالدمبل | 3 | 8-12 | 150 |
| bro_5 | Shoulders | repdb:lateral-raise | Dumbbell Lateral Raise | رفرفة جانبي بالدمبل | 3 | 12-20 | 90 |
| bro_5 | Shoulders | repdb:cable-reverse-fly | Cable Reverse Fly | تفتيح عكسي بالكابل للكتف الخلفي | 3 | 12-15 | 90 |
| bro_5 | Shoulders | repdb:cable-crunch | Cable Crunch | كرنش كابل | 2 | 10-20 | 60 |
| bro_5 | Legs | repdb:squat | Barbell Back Squat | سكوات بار خلفي | 3 | 6-10 | 180 |
| bro_5 | Legs | repdb:romanian-deadlift | Romanian Deadlift | ديدليفت روماني بالبار | 3 | 8-10 | 180 |
| bro_5 | Legs | repdb:leg-press | Leg Press | ضغط الرجلين جهاز | 2 | 10-15 | 180 |
| bro_5 | Legs | repdb:leg-curl | Lying Leg Curl | رجل خلفي نايم جهاز | 3 | 12-15 | 90 |
| bro_5 | Legs | repdb:standing-calf-raise | Standing Calf Raise | رفعة سمانة واقف جهاز | 3 | 10-20 | 90 |
| bro_5 | Legs | repdb:cable-crunch | Cable Crunch | كرنش كابل | 2 | 10-20 | 60 |
| bro_5 | Arms | repdb:ez-bar-curl | EZ-Bar Curl | بايسبس ببار EZ | 3 | 10-15 | 90 |
| bro_5 | Arms | repdb:incline-db-curl | Incline Dumbbell Curl | بايسبس دمبل على مقعد مائل | 2 | 10-15 | 90 |
| bro_5 | Arms | repdb:hammer-curl | Dumbbell Hammer Curl | بايسبس هامر بالدمبل | 2 | 10-15 | 90 |
| bro_5 | Arms | repdb:close-grip-bench-press | Close-Grip Bench Press | بنش بار بقبضة ضيقة | 3 | 8-12 | 150 |
| bro_5 | Arms | repdb:tricep-pushdown | Cable Tricep Pushdown | دفع بار الكابل لأسفل للترايسبس | 2 | 12-15 | 90 |
| bro_5 | Arms | repdb:cable-overhead-tricep-extension | Cable Overhead Tricep Extension | فرد الترايسبس بالكابل فوق الرأس | 2 | 12-15 | 90 |
| arnold_3 | Chest & Back | repdb:bench-press | Barbell Bench Press | بنش بار مستوي | 3 | 6-10 | 180 |
| arnold_3 | Chest & Back | repdb:lat-pulldown | Lat Pulldown | سحب أمامي | 3 | 8-12 | 150 |
| arnold_3 | Chest & Back | repdb:incline-db-press | Incline Dumbbell Press | بنش دمبل مائل | 3 | 8-12 | 150 |
| arnold_3 | Chest & Back | repdb:seated-cable-row | Seated Cable Row | تجديف كابل جالس | 3 | 8-12 | 150 |
| arnold_3 | Chest & Back | repdb:straight-arm-pulldown | Straight-Arm Pulldown | سحب كابل بذراعين مستقيمين | 2 | 12-15 | 90 |
| arnold_3 | Shoulders & Arms | repdb:dumbbell-shoulder-press | Dumbbell Shoulder Press | ضغط كتف بالدمبل | 3 | 8-12 | 150 |
| arnold_3 | Shoulders & Arms | repdb:lateral-raise | Dumbbell Lateral Raise | رفرفة جانبي بالدمبل | 3 | 12-20 | 90 |
| arnold_3 | Shoulders & Arms | repdb:machine-reverse-fly | Machine Reverse Fly | فراشة عكسية جهاز للكتف الخلفي | 2 | 12-15 | 90 |
| arnold_3 | Shoulders & Arms | repdb:ez-bar-curl | EZ-Bar Curl | بايسبس ببار EZ | 3 | 10-15 | 90 |
| arnold_3 | Shoulders & Arms | repdb:incline-db-curl | Incline Dumbbell Curl | بايسبس دمبل على مقعد مائل | 2 | 10-15 | 90 |
| arnold_3 | Shoulders & Arms | repdb:tricep-pushdown | Cable Tricep Pushdown | دفع بار الكابل لأسفل للترايسبس | 3 | 12-15 | 90 |
| arnold_3 | Shoulders & Arms | repdb:cable-overhead-tricep-extension | Cable Overhead Tricep Extension | فرد الترايسبس بالكابل فوق الرأس | 2 | 12-15 | 90 |
| arnold_3 | Legs | repdb:squat | Barbell Back Squat | سكوات بار خلفي | 3 | 6-10 | 180 |
| arnold_3 | Legs | repdb:romanian-deadlift | Romanian Deadlift | ديدليفت روماني بالبار | 3 | 8-10 | 180 |
| arnold_3 | Legs | repdb:leg-press | Leg Press | ضغط الرجلين جهاز | 2 | 10-15 | 180 |
| arnold_3 | Legs | repdb:leg-curl | Lying Leg Curl | رجل خلفي نايم جهاز | 3 | 12-15 | 90 |
| arnold_3 | Legs | repdb:standing-calf-raise | Standing Calf Raise | رفعة سمانة واقف جهاز | 3 | 10-20 | 90 |
| arnold_3 | Legs | repdb:cable-crunch | Cable Crunch | كرنش كابل | 2 | 10-20 | 60 |
| arnold_6 | Chest & Back A | repdb:bench-press | Barbell Bench Press | بنش بار مستوي | 3 | 6-10 | 180 |
| arnold_6 | Chest & Back A | repdb:lat-pulldown | Lat Pulldown | سحب أمامي | 3 | 8-12 | 150 |
| arnold_6 | Chest & Back A | repdb:incline-db-press | Incline Dumbbell Press | بنش دمبل مائل | 2 | 8-12 | 150 |
| arnold_6 | Chest & Back A | repdb:seated-cable-row | Seated Cable Row | تجديف كابل جالس | 2 | 8-12 | 150 |
| arnold_6 | Shoulders & Arms A | repdb:dumbbell-shoulder-press | Dumbbell Shoulder Press | ضغط كتف بالدمبل | 2 | 8-12 | 150 |
| arnold_6 | Shoulders & Arms A | repdb:lateral-raise | Dumbbell Lateral Raise | رفرفة جانبي بالدمبل | 3 | 12-20 | 90 |
| arnold_6 | Shoulders & Arms A | repdb:ez-bar-curl | EZ-Bar Curl | بايسبس ببار EZ | 2 | 10-15 | 90 |
| arnold_6 | Shoulders & Arms A | repdb:tricep-pushdown | Cable Tricep Pushdown | دفع بار الكابل لأسفل للترايسبس | 2 | 12-15 | 90 |
| arnold_6 | Shoulders & Arms A | repdb:machine-reverse-fly | Machine Reverse Fly | فراشة عكسية جهاز للكتف الخلفي | 2 | 12-15 | 90 |
| arnold_6 | Legs A | repdb:squat | Barbell Back Squat | سكوات بار خلفي | 3 | 6-10 | 180 |
| arnold_6 | Legs A | repdb:romanian-deadlift | Romanian Deadlift | ديدليفت روماني بالبار | 3 | 8-10 | 180 |
| arnold_6 | Legs A | repdb:leg-extension | Leg Extension | فرد الرجلين جهاز | 2 | 12-15 | 90 |
| arnold_6 | Legs A | repdb:leg-curl | Lying Leg Curl | رجل خلفي نايم جهاز | 2 | 12-15 | 90 |
| arnold_6 | Legs A | repdb:standing-calf-raise | Standing Calf Raise | رفعة سمانة واقف جهاز | 3 | 10-20 | 90 |
| arnold_6 | Chest & Back B | repdb:db-bench-press | Dumbbell Bench Press | بنش دمبل مستوي | 3 | 8-12 | 150 |
| arnold_6 | Chest & Back B | repdb:chest-supported-db-row | Chest-Supported Dumbbell Row | تجديف دمبل مع إسناد الصدر | 3 | 8-12 | 150 |
| arnold_6 | Chest & Back B | repdb:cable-fly | Cable Fly | تفتيح صدر بالكابل | 2 | 12-15 | 90 |
| arnold_6 | Chest & Back B | repdb:close-grip-lat-pulldown | Close Grip Lat Pulldown | سحب أمامي بقبضة ضيقة متوازية | 2 | 8-12 | 150 |
| arnold_6 | Shoulders & Arms B | repdb:machine-shoulder-press | Machine Shoulder Press | ضغط كتف جهاز | 2 | 8-12 | 150 |
| arnold_6 | Shoulders & Arms B | repdb:cable-lateral-raise | Cable Lateral Raise | رفرفة جانبي بالكابل | 3 | 12-20 | 90 |
| arnold_6 | Shoulders & Arms B | repdb:incline-db-curl | Incline Dumbbell Curl | بايسبس دمبل على مقعد مائل | 2 | 10-15 | 90 |
| arnold_6 | Shoulders & Arms B | repdb:cable-overhead-tricep-extension | Cable Overhead Tricep Extension | فرد الترايسبس بالكابل فوق الرأس | 2 | 12-15 | 90 |
| arnold_6 | Shoulders & Arms B | repdb:cable-reverse-fly | Cable Reverse Fly | تفتيح عكسي بالكابل للكتف الخلفي | 2 | 12-15 | 90 |
| arnold_6 | Legs B | repdb:leg-press | Leg Press | ضغط الرجلين جهاز | 3 | 10-15 | 180 |
| arnold_6 | Legs B | repdb:hip-thrust | Barbell Hip Thrust | دفع الحوض بالبار | 2 | 8-12 | 150 |
| arnold_6 | Legs B | repdb:bulgarian-split-squat | Bulgarian Split Squat | سكوات بلغاري بالدمبل | 2 | 8-12 | 150 |
| arnold_6 | Legs B | repdb:seated-leg-curl | Seated Leg Curl | رجل خلفي جالس جهاز | 3 | 12-15 | 90 |
| arnold_6 | Legs B | repdb:seated-calf-raise | Seated Calf Raise | سمانة جالس جهاز | 3 | 12-20 | 90 |
| hybrid_5 | Upper | repdb:bench-press | Barbell Bench Press | بنش بار مستوي | 3 | 6-10 | 180 |
| hybrid_5 | Upper | repdb:seated-cable-row | Seated Cable Row | تجديف كابل جالس | 3 | 8-12 | 150 |
| hybrid_5 | Upper | repdb:incline-db-press | Incline Dumbbell Press | بنش دمبل مائل | 2 | 8-12 | 150 |
| hybrid_5 | Upper | repdb:lat-pulldown | Lat Pulldown | سحب أمامي | 2 | 8-12 | 150 |
| hybrid_5 | Upper | repdb:lateral-raise | Dumbbell Lateral Raise | رفرفة جانبي بالدمبل | 2 | 12-20 | 90 |
| hybrid_5 | Upper | repdb:ez-bar-curl | EZ-Bar Curl | بايسبس ببار EZ | 2 | 10-15 | 90 |
| hybrid_5 | Upper | repdb:tricep-pushdown | Cable Tricep Pushdown | دفع بار الكابل لأسفل للترايسبس | 2 | 12-15 | 90 |
| hybrid_5 | Lower | repdb:squat | Barbell Back Squat | سكوات بار خلفي | 3 | 6-10 | 180 |
| hybrid_5 | Lower | repdb:romanian-deadlift | Romanian Deadlift | ديدليفت روماني بالبار | 3 | 8-10 | 180 |
| hybrid_5 | Lower | repdb:leg-extension | Leg Extension | فرد الرجلين جهاز | 2 | 12-15 | 90 |
| hybrid_5 | Lower | repdb:leg-curl | Lying Leg Curl | رجل خلفي نايم جهاز | 2 | 12-15 | 90 |
| hybrid_5 | Lower | repdb:standing-calf-raise | Standing Calf Raise | رفعة سمانة واقف جهاز | 3 | 10-20 | 90 |
| hybrid_5 | Lower | repdb:cable-crunch | Cable Crunch | كرنش كابل | 2 | 10-20 | 60 |
| hybrid_5 | Push | repdb:incline-bench-press | Incline Barbell Bench Press | بنش بار مائل | 3 | 6-10 | 180 |
| hybrid_5 | Push | repdb:chest-press-machine | Machine Chest Press | ضغط صدر جهاز | 2 | 8-12 | 150 |
| hybrid_5 | Push | repdb:machine-shoulder-press | Machine Shoulder Press | ضغط كتف جهاز | 2 | 8-12 | 150 |
| hybrid_5 | Push | repdb:cable-lateral-raise | Cable Lateral Raise | رفرفة جانبي بالكابل | 3 | 12-20 | 90 |
| hybrid_5 | Push | repdb:cable-overhead-tricep-extension | Cable Overhead Tricep Extension | فرد الترايسبس بالكابل فوق الرأس | 2 | 12-15 | 90 |
| hybrid_5 | Pull | repdb:close-grip-lat-pulldown | Close Grip Lat Pulldown | سحب أمامي بقبضة ضيقة متوازية | 3 | 8-12 | 150 |
| hybrid_5 | Pull | repdb:chest-supported-db-row | Chest-Supported Dumbbell Row | تجديف دمبل مع إسناد الصدر | 3 | 8-12 | 150 |
| hybrid_5 | Pull | repdb:cable-reverse-fly | Cable Reverse Fly | تفتيح عكسي بالكابل للكتف الخلفي | 2 | 12-15 | 90 |
| hybrid_5 | Pull | repdb:incline-db-curl | Incline Dumbbell Curl | بايسبس دمبل على مقعد مائل | 2 | 10-15 | 90 |
| hybrid_5 | Legs | repdb:leg-press | Leg Press | ضغط الرجلين جهاز | 3 | 10-15 | 180 |
| hybrid_5 | Legs | repdb:hip-thrust | Barbell Hip Thrust | دفع الحوض بالبار | 2 | 8-12 | 150 |
| hybrid_5 | Legs | repdb:bulgarian-split-squat | Bulgarian Split Squat | سكوات بلغاري بالدمبل | 2 | 8-12 | 150 |
| hybrid_5 | Legs | repdb:seated-leg-curl | Seated Leg Curl | رجل خلفي جالس جهاز | 3 | 12-15 | 90 |
| hybrid_5 | Legs | repdb:seated-calf-raise | Seated Calf Raise | سمانة جالس جهاز | 3 | 12-20 | 90 |
| anterior_posterior_4 | Anterior A | repdb:bench-press | Barbell Bench Press | بنش بار مستوي | 3 | 6-10 | 180 |
| anterior_posterior_4 | Anterior A | repdb:squat | Barbell Back Squat | سكوات بار خلفي | 3 | 6-10 | 180 |
| anterior_posterior_4 | Anterior A | repdb:lateral-raise | Dumbbell Lateral Raise | رفرفة جانبي بالدمبل | 2 | 12-20 | 90 |
| anterior_posterior_4 | Anterior A | repdb:ez-bar-curl | EZ-Bar Curl | بايسبس ببار EZ | 2 | 10-15 | 90 |
| anterior_posterior_4 | Anterior A | repdb:leg-extension | Leg Extension | فرد الرجلين جهاز | 2 | 12-15 | 90 |
| anterior_posterior_4 | Anterior A | repdb:cable-crunch | Cable Crunch | كرنش كابل | 2 | 10-20 | 60 |
| anterior_posterior_4 | Posterior A | repdb:romanian-deadlift | Romanian Deadlift | ديدليفت روماني بالبار | 3 | 8-10 | 180 |
| anterior_posterior_4 | Posterior A | repdb:lat-pulldown | Lat Pulldown | سحب أمامي | 3 | 8-12 | 150 |
| anterior_posterior_4 | Posterior A | repdb:chest-supported-db-row | Chest-Supported Dumbbell Row | تجديف دمبل مع إسناد الصدر | 2 | 8-12 | 150 |
| anterior_posterior_4 | Posterior A | repdb:cable-reverse-fly | Cable Reverse Fly | تفتيح عكسي بالكابل للكتف الخلفي | 2 | 12-15 | 90 |
| anterior_posterior_4 | Posterior A | repdb:tricep-pushdown | Cable Tricep Pushdown | دفع بار الكابل لأسفل للترايسبس | 2 | 12-15 | 90 |
| anterior_posterior_4 | Posterior A | repdb:standing-calf-raise | Standing Calf Raise | رفعة سمانة واقف جهاز | 3 | 10-20 | 90 |
| anterior_posterior_4 | Anterior B | repdb:incline-db-press | Incline Dumbbell Press | بنش دمبل مائل | 3 | 8-12 | 150 |
| anterior_posterior_4 | Anterior B | repdb:leg-press | Leg Press | ضغط الرجلين جهاز | 3 | 10-15 | 180 |
| anterior_posterior_4 | Anterior B | repdb:dumbbell-shoulder-press | Dumbbell Shoulder Press | ضغط كتف بالدمبل | 2 | 8-12 | 150 |
| anterior_posterior_4 | Anterior B | repdb:incline-db-curl | Incline Dumbbell Curl | بايسبس دمبل على مقعد مائل | 2 | 10-15 | 90 |
| anterior_posterior_4 | Anterior B | repdb:cable-fly | Cable Fly | تفتيح صدر بالكابل | 2 | 12-15 | 90 |
| anterior_posterior_4 | Anterior B | repdb:reverse-crunches | Reverse Crunches | كرنش عكسي | 2 | 10-20 | 60 |
| anterior_posterior_4 | Posterior B | repdb:hip-thrust | Barbell Hip Thrust | دفع الحوض بالبار | 3 | 8-12 | 150 |
| anterior_posterior_4 | Posterior B | repdb:seated-leg-curl | Seated Leg Curl | رجل خلفي جالس جهاز | 3 | 12-15 | 90 |
| anterior_posterior_4 | Posterior B | repdb:close-grip-lat-pulldown | Close Grip Lat Pulldown | سحب أمامي بقبضة ضيقة متوازية | 3 | 8-12 | 150 |
| anterior_posterior_4 | Posterior B | repdb:seated-cable-row | Seated Cable Row | تجديف كابل جالس | 2 | 8-12 | 150 |
| anterior_posterior_4 | Posterior B | repdb:machine-reverse-fly | Machine Reverse Fly | فراشة عكسية جهاز للكتف الخلفي | 2 | 12-15 | 90 |
| anterior_posterior_4 | Posterior B | repdb:cable-overhead-tricep-extension | Cable Overhead Tricep Extension | فرد الترايسبس بالكابل فوق الرأس | 2 | 12-15 | 90 |
| anterior_posterior_4 | Posterior B | repdb:seated-calf-raise | Seated Calf Raise | سمانة جالس جهاز | 3 | 12-20 | 90 |

## Identity and preservation

New template assignments, saved days and immutable session snapshots keep the same canonical exercise ID and generated assignment ID across save/reopen/target editing/tracking/completion. Metadata and media use the existing catalog resolver, not translated-name matching. Existing logged sets and progress/PR services retain their current name-snapshot-based behavior; this task does not redesign analytics or add new identity fields to historical sets.

Existing saved workouts and history are not rewritten. Global legacy mappings remain 35 exact / 145 unmatched. The three old variations intentionally remain unmatched globally, and integrity validation still rejects unresolved references when creating a new copy. No cloud policy, Hive schema, user-data migration, Firebase, Gradle, signing, exercise catalog, image or video mapping changed.

The interrupted manual-replacement dialog, error-row behavior and unresolved-ID state were removed by restoring only the three affected files from the exact pre-interruption snapshot. That implementation and its obsolete tests are archived under `build/template-canonical-repdb-20261104/interrupted-implementation.zip`. All pre-existing work was retained.

## Files changed in this correction

- `lib/assets/data/standard_workout_templates.json`: all 214 references normalized; all other content preserved.
- `lib/features/workout/data/repositories/standard_workout_template_repository.dart`: require direct active-catalog references and reject duplicates/legacy aliases at load time.
- `tool/build_standard_workout_templates.py`: author with canonical RepDB slugs; read-only `--check`; preserve the detailed audit document.
- `test/features/workout/support/standard_template_fixtures.dart`: exercise real catalog validation, matching production dependency injection.
- `test/features/workout/standard_workout_templates_test.dart`: canonical-only IDs, bad/legacy/duplicate reference rejection and exact-alias save expectation.
- `test/features/workout/repdb_migration_test.dart`: explicitly seed legacy drafts instead of relying on broken built-in content.
- `test/features/workout/built_in_template_repdb_integration_test.dart`: 20 tests covering full source/media audit, all variants in EN/AR through persistence, editing, every workout day, completion, repeated-session progress, unchanged legacy data/mappings and refusal of invalid new copies.
- `test/features/workout/built_in_template_repdb_widget_test.dart`: 18 real navigation/save tests across every variant in EN/AR, including warning absence and canonical persisted IDs.
- `docs/standard-workout-template-mappings.md` and `docs/standard-workout-templates.md`: current source compatibility and authoring documentation.

Restored to exact pre-interruption bytes: the import service, draft cubit and draft screen. Removed only the obsolete interrupted test file after archiving it. No pre-existing files were deleted.

## Verification

- Dart format: six changed Dart files formatted successfully.
- `python tool/build_standard_workout_templates.py --check`: passed, exactly reproducing the bundled canonical JSON without writes.
- Focused `flutter test --no-pub`: **79 passed** across `built_in_template_repdb_integration_test.dart`, `built_in_template_repdb_widget_test.dart`, `standard_workout_templates_test.dart`, `standard_workout_templates_widget_test.dart`, `workout_template_navigation_test.dart`, `repdb_catalog_test.dart`, `repdb_migration_test.dart`, and `template_exercise_session_persistence_test.dart` (all under `test/features/workout/`).
- `flutter analyze --no-pub`: **no issues found**, exit 0 (112.7 seconds). An earlier run detected only the audit backup accidentally named `.dart`; the backup was preserved under `.dart.before.txt` and the complete rerun passed.
- Full `flutter test --no-pub`: **668 passed, 5 failed** (146 seconds). Every template regression passed. The failures are unchanged Exercise Picker tests whose exact-label finders expect `Filters` / its Arabic translation while the unchanged control renders a count, e.g. `Filters (0)`:
  - `exercise_picker_bundled_catalog_test.dart`: Back muscle filter keeps Lat Pulldown searchable and clears independently; muscle, equipment and Arabic search compose on real catalog; default filter chips are all unselected.
  - `exercise_picker_dialog_test.dart`: dark picker keeps selection and filters usable in RTL; muscle and equipment filters apply together.
- Those picker tests do not depend on the standard-template source/validator/fixture; the dialog test supplies a fake exercise catalog. The picker implementation and both test files predate this task and were not changed. Their existing selector mismatch remains outside this correction. Full-suite green status is therefore still outstanding; these failures must not be represented as passing.
- Preservation checks: catalog, global legacy mapping and Gradle SHA-256 values match the pre-change snapshot; the three interrupted production files match their pre-interruption bytes. Structural comparison confirms only 214 exercise IDs changed in the bundled JSON.

## Remaining first-release checks

All built-in template source references are compatible with RepDB, and all nine variants select/save without migration warnings in EN/AR widget tests. No unresolved built-in exercise references remain. Three template exercises retain English instruction fallback pending Arabic review; the 145 unmatched global legacy references remain intentionally preserved for existing records. Existing analytics continue to use logged-name snapshots, with canonical IDs retained in assignment/session snapshots; cross-language aggregation semantics were not changed. The five unrelated picker assertions and a fresh device walkthrough remain outstanding. This task does not certify whole-application release readiness.

Logs and pre-change snapshots: `build/template-canonical-repdb-20261104/`. No APK build or physical-device verification was performed for this change.
