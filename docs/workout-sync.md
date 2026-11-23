# Workout days and custom exercises: cloud sync (Stage 2)

Workout days (`users/{uid}/workout_templates`) and custom exercises
(`users/{uid}/custom_exercises`) sync through `RevisionSyncEngine`
(`lib/core/sync/`). The local Hive box is what the app reads; the cloud is a
revision-protected copy. Firebase Spark only: no Cloud Functions.

## Guarantees

- **No silent overwrite.** Every write states the revision it is based on.
  `firestore.rules` accepts it only if that is still the stored revision
  (compare-and-set). A write queued offline is checked when it arrives.
- **No silent loss.** A conflict keeps a full copy of this device's version
  (`sync_conflicts` box) until the user deletes it. Deletions are
  revision-checked tombstones.
- **Crash safety.** Every state change is one Hive `put` + `flush`; every
  multi-step change is ordered and idempotent.

## When the server is read (Spark quotas)

| Moment | Reads |
| --- | --- |
| A local edit (`requestPush`) | none; if the server refuses the write, that one document |
| Loading the programs screen (`syncAll`) | only documents changed since the last pull (`serverUpdatedAt >= cursor - 2 min`); an empty result costs 1 read |
| First sync on a device, then at most once every 24 h | the whole collection: also finds old-format days written by older builds and documents deleted outright |
| A record with an unconfirmed write, or never matched with the cloud | that one document |
| Until the migration marker is written (once per account per device) | one extra full read to verify |

The pull position is kept per collection in the account's `sync_state` box
(`pull.template`, `pull.customExercise`).

## Activity limit

`WorkoutLimits.maxActivitiesPerDay` (40) is enforced by the rules, by the
repository (`addExerciseAssignment(s)`), by adding exercises to the program
day during a workout, and by the new-program draft.

Nothing is ever cut:

- **Restoring old exercises** keeps all of them. Beyond 40, the rest go,
  in order, into new days of the same program (`Legs (2)`, …). The preview
  says so before the user confirms.
- **A day already over the limit** (from an older version of the app) is
  never sent: it is flagged (`blockedReason = local:tooManyActivities`) and
  the day card offers **Split day**, with a confirmation.

A split writes the new days first, with ids derived from the content being
split, then the day itself. An interrupted split simply runs again with no
duplicates.

## Errors

`FirestoreRevisionCloud` maps a refused write to `CloudWriteRejected` (the
server state then decides what happens) and a refused read to
`CloudReadDenied`. A refused read means the rules aren't deployed yet, or
the email isn't verified. It's handled like being offline: everything is
kept and retried. Sync failures never turn a loaded screen into an error.

## Tests

- Unit tests with a fake server that applies the same rules:
  `test/core/sync/` and `test/features/workout/workout_cloud_sync_repository_test.dart`.
- Rules on the Firestore emulator: `firestore-tests/` (`npm test`).
- The real SDK, rules, sync engine and account deletion on Android against
  the emulators: `integration_test/firebase_emulator_test.dart`. Start an
  Android emulator, then from the repository root:

  ```
  firebase emulators:exec --only firestore,auth --project demo-ae-coaching \
    "flutter test integration_test/firebase_emulator_test.dart -d emulator-5554"
  ```

  It only uses a `demo-` Firebase app pointed at `10.0.2.2` (the emulators).
  Debug builds allow plain HTTP to the emulator hosts only
  (`android/app/src/debug/res/xml/network_security_config.xml`).
