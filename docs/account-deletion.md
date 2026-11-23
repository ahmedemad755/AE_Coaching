# Account deletion (Firebase Spark plan)

## Summary

Deletion is **immediate and done by the app itself**, after the user
re-enters their password. No Cloud Functions and no Admin credentials are
involved. An operator tool remains for support cases and for a future move
to Blaze (see below).

## Why the app can delete everything on Spark

A client can only delete documents its rules allow, and deleting a document
does not delete its subcollections. Both are handled:

- every account document lives under `users/{uid}` in collections the app
  knows (`exercise_sets`, `workout_sessions`, `workout_templates`,
  `custom_exercises`, `workout_programs`, `body_measurements`, `fcmTokens`)
  plus `settings/notifications` and the profile document. The app deletes
  each one explicitly. Synced workout days and custom exercises (schema 2)
  can only be deleted as tombstones, so the app first writes a
  revision-checked tombstone for each live one (its own commit), then
  deletes the page. If another device changed one in between, the page is
  read again. `test/core/firestore_rules_consistency_test.dart` fails when
  the rules gain a collection this list doesn't delete;
- the server-owned documents (`users/{uid}/notificationState/*`,
  `fcmTokenOwners/*`) are written **only** by Cloud Functions. On Spark
  nothing is deployed, so they never exist. Their rules stay deny-all.

If the project moves to Blaze and the reminder functions are deployed,
those documents will exist and the client can no longer delete everything.
Deletion must then move to the server (an `auth.user().onDelete` trigger or
the operator tool) in the same release.

## What the app does

Settings → Danger zone → Delete account:

1. explains what is deleted and that it cannot be undone;
2. asks for the password and re-authenticates (`EmailAuthProvider`; the ID
   token is refreshed so the rules see a fresh `auth_time`);
3. requires an explicit confirmation checkbox;
4. records on the device that a deletion started (`accountDeletionInProgressUid`)
   and stops local reminders;
5. deletes, in this order, waiting for the **server** to confirm each step
   (pending offline writes are flushed first; reads come from the server,
   never the cache; a step that times out counts as offline):
   1. **locks** the account: stamps `deletionStartedAt` on the profile. From
      then on the rules refuse creating any new document for the account,
      so another device still holding a valid ID token (up to an hour)
      cannot bring data back, while everything left can still be read,
      updated and deleted. The lock is never removed (no cancel: the
      deletion can only be completed). A profile already gone (earlier
      attempt) is skipped;
   2. every document of the account's collections (paged, batches of 400);
   3. `settings/notifications`;
   4. the profile `users/{uid}`;
   5. the Firebase Auth account (**last**);
6. removes everything the device holds for that account (its Hive boxes,
   progress and profile photos, per-account preferences, the session, local
   reminders, the device push registration), signs out, and returns to the
   login screen with "Your account has been deleted." Firestore's offline
   cache is cleared at the next start, before Firestore is used. Other
   accounts on the same device are never touched.

Until a deletion is completed, the app keeps working on the phone; the
start-up notice says new changes are saved on this phone only (their cloud
writes are refused while the account is locked).

Rules: creating a document under `users/{uid}` requires the profile, without
the lock (`canCreateIn`, one extra read per create; every signed-in user has
a profile: the app confirms or recovers it at each sign-in and app start).
The lock itself: owner, right after re-authenticating, server time only,
never removable. The profile, `settings/notifications` and listing `fcmTokens` are
allowed only for the owner **and only within 10 minutes of signing in**
(`hasRecentSignIn()`, from `auth_time`). Another user can never read, list
or delete them. The collections were already owner-only.

## Interruptions

Every step is idempotent, so deletion can always be retried:

- **wrong password / too many attempts:** nothing is deleted;
- **offline, timeout or stale sign-in part-way:** some data may already be
  gone. The account still exists, so nothing is removed from the device and
  the user stays signed in. The screen shows "An earlier deletion didn't
  finish" and the user completes it with the password. At every app start
  the user sees the same reminder until it is finished;
- **app killed after the Auth account was deleted but before the local
  cleanup:** at the next start the app sees that the account is gone,
  finishes the local cleanup and signs out;
- **the deleting account is no longer signed in on the device:** its local
  data is removed at the next start, because the user asked for it;
- a failed local cleanup is retried at every start until it succeeds.

## Operator tool (support and Blaze only)

`functions/src/account` deletes accounts with the Admin SDK, including the
server-owned documents. On Spark it is needed only for support cases (for
example a user who cannot sign in anymore). It processes
`accountDeletionRequests/{uid}` documents, which **only an operator** creates
in the Firebase Console (`{uid, status: "pending", requestedAt}`); clients
can never read or write that collection.

Run from `functions/` on a trusted machine. Use credentials for exactly
that project, e.g. `gcloud auth application-default login`. Never use a
key file inside the repository or the app.

```
npm run build
# 1. dry run: what each pending request would delete (reads only)
npm run account:process-deletions -- --project <id> --allow-live
# 2. apply (the project id twice)
npm run account:process-deletions -- --project <id> --allow-live --apply --confirm-project <id>
# one account only:
npm run account:process-deletions -- --project <id> --allow-live --apply --confirm-project <id> --uid <uid>
```

For each valid request, in this order (every step is idempotent): mark it
`processing`; recursively delete `users/{uid}`; delete its `fcmTokenOwners`
records; delete the Auth account (**last**); remove the request. A failure
stops that account at the failed step and the next run resumes it. The
report lists pseudonymous references and counts only: no uid, email or
token.

## Store compliance (assessment, not a guarantee)

- **Google Play** requires in-app deletion **and** a web link to request
  deletion (Data safety form). In-app: provided (immediate). Web link: **not
  yet built**; it can be a simple page or form whose requests the operator
  processes with the tool above. Verify the current policy in Play Console
  Help before submitting.
- **Apple App Store** (guideline 5.1.1(v)) requires that users can delete
  their account in the app, not just deactivate it: provided. Review the
  current guideline text before submitting.

## Limitations

- The new rules must be **deployed** (`firebase deploy --only
  firestore:rules`, free on Spark) before this build is released; with the
  old rules the profile delete is refused and the deletion stays incomplete.
- Data written by another, still-signed-in device after the deletion can be
  recreated under `users/{uid}` (ID tokens stay valid up to 1 hour). The
  operator tool can remove such leftovers.
- iOS is not tested yet.
- After deletion, the same email can sign up again as a new, empty account
  (new uid).
