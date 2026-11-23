# Cardio training

Built in stages (see the approved plan). This file describes what exists.

## Stage 3: Add activity and the cardio library

- **Add activity** (day card button, `TemplateExerciseManager`) opens a sheet
  (`add_activity_sheet.dart`) with three choices:
  - **Strength exercise:** the existing exercise library, unchanged.
  - **Cardio:** the cardio library.
  - **My library:** the user's own exercises (strength and cardio).

  **Timed exercise** is not offered until its settings screen exists.
- **Cardio library** (`cardio_library_screen.dart`): search in Arabic or
  English, category chips (machines and equipment, bodyweight, outdoor, my
  cardio), creating a custom cardio activity. Bundled data only, no
  network.
- **Data** (`domain/cardio_library.dart`): a curated list that reuses the
  bundled RepDB catalog. Its ids, both names and its picture are kept as
  they are. Three activities RepDB lacks are app-defined, with `cardio:` ids
  and names from the translations: Shadow Boxing / ملاكمة الظل,
  Hiking / المشي الجبلي, Swimming / السباحة. Air Bike and Assault Bike are
  one activity, found by both names. `CardioLibraryCatalog` resolves the
  list (a missing RepDB id is left out, never invented).
- **Adding:** `WorkoutTemplateRepository.addExerciseAssignment(cardio:)`
  stores a cardio activity with the default plan (countdown, 20 minutes;
  configurable in Stage 4; no timer runs). It goes through the existing
  path: unique assignment id, the 40-activity limit, the same exercise only
  once per day, revision-protected sync.
- **Custom cardio:** `CustomExerciseRepository.createExercise(activityType:)`.
  Strength customs are stored exactly as before (no type). The strength
  picker never shows custom cardio.
- **Day row:** a cardio activity shows its icon and "Cardio · Countdown ·
  20 min". Its menu offers replace (another cardio activity; the plan is
  kept) and remove; sets/reps editing is strength only.

## Stage 4: cardio settings and the day estimate

- **Cardio settings** (`cardio_config_sheet.dart`): opened by tapping a
  cardio activity or from its menu, and automatically right after a cardio
  activity is added. In that case it is already saved with the default
  plan, and Cancel (or closing the sheet) keeps it as it is. Saving goes
  through `WorkoutTemplateRepository.updateCardioPlan`, which validates and
  keeps settings it doesn't know.
- **Removing an activity** happens at once, with **Undo**
  (`restoreExerciseAssignment`: the same entry back at its place, saved and
  synced like any change; refused if the day is full or the exercise was
  added again meanwhile).
- **Estimated duration** (`WorkoutDurationEstimator`, shown on every day
  card, release builds included, labelled as an estimate):
  - Strength: sets × average reps × 3 s + the rest between sets (none after
    the last).
  - Cardio and timed activities: their planned time.
  - Missing values leave an activity out, or count rest as none. The label
    then says "at least".
  - **Not included:** the time between activities (moving, setting up) and
    any general warm-up not planned as an activity.
  - Never the time a workout actually took: session history is not used.

## Stage 6: running cardio in a workout

- In the active workout, a cardio activity is a card in the day's saved
  order: its plan, where its timer is (not started, in progress, paused,
  done, ended early, skipped) and a button that opens its timer. No sets
  are logged for it; strength exercises are unchanged.
- The timer screen (`CardioSessionScreen`): the workout's name, the
  activity, a large timer with a progress ring, the plan, Start / Pause /
  Resume / Finish / Skip, and the next activity. Nothing runs until Start.
- Intervals: warm-up, then work and rest for each round (no rest after the
  last round), then cool-down. Each phase is named with an icon and a word
  as well as a colour, with the round and the next phase. Phases change by
  themselves.
- Results: finishing before the plan (or a stopwatch's target) is **ended
  early**, with the time done; a skipped activity is **skipped**, never
  done. A workout of cardio only is finished and kept; a workout whose
  only cardio was skipped is still "empty". A timer left open when the
  workout is finished is closed with the time it had. The completion
  summary lists each cardio result with its plan.
- Storage: the timer is saved with the session (`WorkoutSession.activityRuns`,
  Hive field 16) at each start, pause, resume, finish and skip, as
  wall-clock timestamps. **Local only for now**: like the session's other
  layout fields, it is not part of the cloud payload (cloud sync and
  progress are Stage 8, with a rules change to approve). Older sessions
  read it as empty.

### Background behaviour (what is and isn't supported)

- The time keeps counting while the phone sleeps, while the app is in the
  background, and after the app is closed or killed: it is computed from
  the saved start time, not from UI ticks. Coming back shows the right
  time and phase at once; a countdown or interval plan that ran out
  meanwhile is shown as done, at its planned time.
- While a timer runs on screen, the screen is kept on (Android).
- Sounds and vibration at phase changes, at a stopwatch's target and at the
  end play **only while the timer screen is open**. They follow the phone's
  sound mode and touch-feedback setting, and can be turned off on the
  screen. There are no background notifications for phase changes (that
  would need exact alarms or a foreground service: not built).
- The device clock moved back never makes the timer run backwards; a clock
  moved forward by hand does advance it (it can't be told apart from the
  phone sleeping). A timer left running stops counting at 6 hours.

## Feature flag

`WorkoutFeatures.cardioActivities`: on in debug and profile builds, **off
in release builds** until cardio is approved for release. Off, the button
is "Add exercise" and opens the exercise library directly, and a cardio
activity in a workout is shown as before (no timer). Saved cardio
activities (e.g. synced from a development build) are always read and
shown safely, with or without the flag.

## Trying a debug build on a phone without the real project

`--dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1` (debug and profile builds;
ignored in release) points Auth and Firestore at the local Firebase
Emulator. For judging smoothness use a profile build (`flutter run
--profile`): debug builds run unoptimised code and stutter on phones. With the phone
on USB: `adb reverse tcp:8080 tcp:8080` and `adb reverse tcp:9099
tcp:9099`, then `firebase emulators:start --only auth,firestore --project
demo-ae-coaching`. The emulator applies the local `firestore.rules`. A
sign-in kept from the real project is signed out at start (nothing on the
phone is deleted), App Check and push registration are skipped.

## Known gaps until later stages

- Cardio results are not synced to the cloud yet (Stage 8).
- The activity icons are bundled Material icons, an approximation of the
  design's icons.
