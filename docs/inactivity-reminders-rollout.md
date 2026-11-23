# Inactivity reminders — staging and rollout runbook

Status: everything below is prepared and tested locally. Nothing has been
deployed, no live project has been read or written, and the delivery gate
has not been opened anywhere.

## 1. What protects users during rollout

Delivery needs three independent gates. Activity and preference
tracking always run, so nothing is lost while they are closed.

| Gate | Who controls it | Default | Effect |
| --- | --- | --- | --- |
| `serverConfig/inactivityReminders` | operators only (Admin SDK / Console; rules deny all clients) | **off** (also when missing, malformed or unreadable) | `off`: no query, no send. `allowlist`: only listed uids (≤ 100). `all`: every eligible user. Re-read before each page, so switching off stops a running pass. |
| `appSupportsServerReminders` (per user, in the server-owned state) | set by the server when the user's app writes `users/{uid}/settings/notifications` | **false** | Until a Stage 3+ build has written preferences for that account, the user is never due. |
| Device readiness (per FCM token) | the app's registration write, checked by rules; ownership still comes from the server registry | **not ready** | Only tokens whose LATEST registration came from a build that confirms readiness receive reminders. |

The per-user gate works because builds before Stage 3 can't write that
document: older rules denied it, and their code kept the on/off choice in
Hive only. So a user still on such a build (which also schedules the local
3-day reminder) never receives server reminders, and an old-build user who
turned the local reminder off is never treated as "on". On first launch,
the Stage 3 app writes the document, carrying over that old choice.

Device readiness: the current build writes
`serverRemindersReadyAt = serverTimestamp()` in the same registration write
as `updatedAt = serverTimestamp()` (rules: equal to `request.time`, or
carried unchanged). A token is ready only while the two are equal. Older
builds never write the field, and their re-registration refreshes only
`updatedAt`, so a token registered last by an older build (including after
a downgrade) is not ready. Tokens registered before this build are not
ready until the next app start of the current build re-registers them.
Readiness is a capability of the device's app, never authentication or
ownership: the rules still allow only the verified owner to write, and
senders still require a confirmed owner in `fcmTokenOwners`. Not-ready
tokens are kept (never deleted); an account with only old-build devices
gets nothing (checked again daily, nothing counted).

Gate document shape:

```
serverConfig/inactivityReminders
  deliveryMode: "off" | "allowlist" | "all"
  allowlistUids: ["uid1", ...]      // only for "allowlist", 1–100 uids
  maxSendsPerPass: 100              // optional; integer 1–5000; default 100
```

An invalid `maxSendsPerPass` closes the gate (it never guesses).

### Backlog policy

Reminders that came due while delivery was impossible (gate closed,
scheduler outage, or an upgrade confirming a long-overdue user) must not go
out in one burst. Two rules, both deterministic:

1. **Spread:** a reminder more than **6 h** past its scheduled send time is
   not sent. It moves to a stable slot in **10:00–20:00 local on one of
   the next 3 days**, never today. The slot comes from a hash of uid +
   attempt id. 20:00 is the latest slot, so the hourly run that picks it up
   is still before 21:00. The reminder number, activity history and cadence
   anchors are unchanged. The next reminder is measured from the actual
   send (48 h / 72 h / weekly unchanged). Reported as `backlog_deferred` in
   the pass summary.
2. **Budget:** each hourly pass sends at most `maxSendsPerPass` reminders
   (exact, oldest due first). The rest wait for the next pass.

Normal lateness (hourly runs, quiet-hours postponement) stays far below 6 h,
so on-time reminders are unaffected: opening the gate sends the reminders
due right then normally and spreads only the backlog.

Trade-offs:
- Backlogged users wait 1–3 extra days for their overdue reminder. That's
  acceptable for a reminder that is already days late, and a burst is
  worse.
- A long outage also triggers spreading (intended: no catch-up storm).
- The budget delays everyone when a large cohort is due in one hour (e.g.
  after a holiday). Raise it explicitly with `maxSendsPerPass`.
- If more than `maxSendsPerPass` × passes are due, the overflow stays due
  and becomes backlog after 6 h, so it spreads too: the system degrades
  to "later", never to "burst".

Kill switch: set `deliveryMode` to `"off"` (or delete the document). It
takes effect at the next page of a running pass, or at the next hourly run.

## 2. Deployment prerequisites

| Item | Status |
| --- | --- |
| Functions runtime | **Verified locally:** Node.js 22 (`engines`). The installed firebase-tools 15.20.0 lists Node 20 as decommissioned on 2026-10-30, and Node 22 as GA until its 2027-04-30 deprecation. |
| SDKs | firebase-functions 5.1.1, firebase-admin 12.7.0. They work with this code; consider upgrading before production (needs network and review). |
| Project selection | No `.firebaserc`, so every command must pass `--project <id>`. The app is wired only to `ae-coaching-bcd69` (production). **A staging project does not exist in the repo.** |
| Billing | Blaze plan required: 2nd-gen functions, Eventarc Firestore triggers, Cloud Scheduler (`sendDueInactivityReminders`), Artifact Registry. **Needs approval per project.** |
| Region | Not set, so `us-central1`. Firestore triggers must run in a region compatible with the database location. **Firestore location must be verified** in the Console for each project. If it is not `nam5`/`us-central1`, set the region (e.g. `setGlobalOptions`) before deploying. |
| Rules | `firestore.rules`. It adds `settings/notifications` (verified owner, exact fields) and denies `notificationState`, `fcmTokenOwners` and `serverConfig` to clients. 71 emulator tests. **The rules live in production today are unknown** (docs describe older Console rules); diff them before deploying. |
| Indexes | `firestore.indexes.json`: a collection-group override on `notificationState.nextReminderAt`. **Merge with the project's existing indexes first** (`firebase firestore:indexes --project <id>` lists them; that is a live read, run it in Stage 4B). Wait until the index is built before opening the gate. |
| Functions | 5 exports: `onWorkoutSessionCreated`, `onWorkoutSetCreated` (create triggers), `onReminderPreferencesWritten`, `onFcmTokenWritten` (write triggers), `sendDueInactivityReminders` (every 60 min UTC, `maxInstances: 1`, 540 s, `retryCount: 0`). |
| Deploy safety | `predeploy` runs typecheck, unit tests and build. A bare `firebase deploy` would deploy rules, indexes **and** functions: always use `--only`. |
| Old app builds in the field | **Verify** which app versions users run and whether they register FCM tokens (builds since the auth integration do). The per-user gate makes either answer safe. |

## 3. Token ownership migration (backfill)

Senders use only tokens whose owner is confirmed in `fcmTokenOwners`.
Tokens registered before the registry existed get nothing until they are
backfilled or the app registers them again. Any app start of a signed-in,
verified Stage 3+ build does that.

Preconditions (all required):
1. Rules and functions are deployed (the write trigger is live, so new
   registrations are confirmed as they happen).
2. The delivery gate is `off` or `allowlist`.
3. A dry-run report has been reviewed and approved.
4. The operator runs from a trusted machine with Application Default
   Credentials for exactly that project.

Procedure:
```
cd functions && npm run build
# 1. dry run (reads only)
npm run migrate:token-owners -- --project <id> --allow-live
# 2. review: scannedCopies, assignable, alreadyOwned, ambiguousTokens, malformedCopies
# 3. apply (needs the project id twice)
npm run migrate:token-owners -- --project <id> --allow-live --apply --confirm-project <id>
# 4. dry run again: assignable must be 0
```

Ambiguous tokens (one token stored under several accounts, typically a
shared device whose logout cleanup failed) are **never assigned**. They are
listed only as pseudonymous references with holder counts. They become
usable when the account currently using the device opens the app (the
registration confirms it); the stale copies are then discarded at send
time. No manual resolution is needed. Malformed copies are ignored and
discarded at send time.

Safety and rollback:
- Apply only **creates** missing owner records, in transactions. It never
  overwrites an owner, never edits or deletes a user's token documents, and
  is idempotent (safe to rerun or to interrupt).
- Each backfilled record carries `source: "migration"`. A live
  registration rewrites the record without it.
- Rollback = delete the `fcmTokenOwners` documents whose `source` is
  `"migration"` (Console filter, or a reviewed Admin script). Those tokens
  return to "unconfirmed": no reminders until re-registration. This fails
  safe (fewer sends, never wrong-account sends). Records confirmed by live
  registrations are untouched.
- Emergency stop for delivery at any point: the gate (section 1).

## 4. Staging validation plan (Stage 4B)

Environment:
- A separate Firebase project (e.g. `ae-coaching-staging`) on Blaze, with
  Firestore in the chosen location, and Email/Password auth enabled.
- A staging app build: register Android/iOS apps in the staging project
  (`flutterfire configure --project=<staging>`). This creates staging
  `firebase_options.dart` / `google-services.json`, which must never
  replace the production files in a release build. **This needs a decision
  on build flavors.**
- Deploy rules, indexes and functions to staging only. Gate `allowlist`
  with the test uids.

Test accounts and devices:
- A: a verified account on the new build (primary).
- B: a second verified account for account switching on the same device.
- C: a verified account that only ever used an old build (no preferences
  document), to prove the per-user gate.
- D: an unverified account, to prove it can't write preferences or receive
  reminders.
- At least one Android 13+ device or emulator image with Google Play
  services. FCM needs real tokens: emulator images with Play services work
  for background/terminated delivery.

Checks (expected result in brackets):
1. **Preferences:** toggle on/off online [server document updated; "saved"
   only after confirmation]. Toggle offline [shown as waiting to sync, then
   converges]. Change the app language [document `language` follows].
   Change the device time zone, then restart [document `timeZone`
   follows]. Account D [read and write denied; switch disabled].
2. **Per-user gate:** account C logs workouts [state tracked,
   `nextReminderAt` null, no push]. C upgrades and opens the app [document
   written, flag true, cadence resumes].
3. **Cadence with controlled time:** don't wait days. Use a staging-only
   copy of the policy with minutes instead of hours (for example 2 min /
   3 min / 7 min) via a test deploy, OR edit `nextReminderAt` /
   `lastActivityAt` of a test user's state in the staging Console, then
   wait for the hourly run (or trigger the scheduler job manually in Cloud
   Scheduler). [Reminder 1, then 2–5, then weekly; activity resets.]
4. **Quiet hours:** a due time set to 22:00 local [postponed to 10:00];
   time zones on both sides of UTC.
5. **Delivery states:** app in background and app terminated [shown in the
   "Inactivity reminders" channel; tap opens Home]. Foreground [not
   shown]. Tap while signed out [startup check, not Home].
6. **Tokens and switching:** A signs out, B signs in on the same device
   [token moves to B; A's reminders don't reach this device]. Reinstall /
   token refresh [old token removed, new one confirmed]. Run the migration
   dry run, then apply, on staging data with an ambiguous token
   [unassigned, and resolved by re-registration].
7. **Duplicates:** two scheduler runs overlapping (trigger manually twice)
   [one push]. Account A with a new-build phone and an old-build tablet
   [push only to the phone; the tablet keeps its own local reminder]. A
   device that had a legacy local reminder scheduled, then updated [no
   local reminder fires]. Downgrade a device to an old build [its token
   becomes not ready].
8. **Gate:** `off` [no push, no query]. `allowlist` [only listed]. Switch
   to `off` during a run [stops at the next page]. A small
   `maxSendsPerPass` [exactly that many per run]. Close the gate for over
   a day, then reopen [backlog spread over the next 3 days, in the window;
   reminders due right now sent normally].
9. **Observability:** Cloud Logging shows `inactivity_reminder_pass`
   summaries (gate, examined, sent, retry, unknown) and per-delivery
   results with pseudonymous ids only (no uid, token or attempt id).
   Suggested alerts: `error` > 0 per pass, `outcome_unknown` /
   `retry_scheduled` spikes, `inactivity_delivery_gate_unreadable`,
   function errors and timeouts.

## 5. Production rollout sequence (after staging sign-off)

1. Deploy rules + indexes (`--only firestore:rules,firestore:indexes`).
   Wait for the index.
2. Deploy functions (`--only functions`). The gate document does not exist
   yet, so nothing is sent; tracking starts.
3. Ship the Stage 3 app build; users confirm as they update.
4. Run the token migration (section 3).
5. Gate `allowlist` with internal accounts. Observe a full cadence cycle.
6. Gate `all`. Watch the first passes. If needed, switch back to `off`.

## 6. Remaining risks

- **Old-build devices of eligible users** receive no server reminders (by
  design); they keep their own local reminder until updated.
- **Backlog delay:** reminders overdue by more than 6 h arrive 1–3 days
  later than without the policy (see "Backlog policy").
- Offline-only workouts are invisible to the server until uploaded.
- Exactly-once delivery is not claimed. A rare `outcome_unknown` may mean
  one reminder is lost, never duplicated.
