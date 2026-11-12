# AE Coaching — Firebase Functions

**Status: Stages 1–2 — built and tested locally, NOT deployed.**
`firebase.json` now has a `functions` target (Stage 2), so a bare
`firebase deploy` WOULD deploy functions, rules and indexes. Never run it
without approval; always name targets (`--only ...`). Deploying requires the
Blaze plan (scheduled functions use Cloud Scheduler) and the checklist below.

## Rollout gates (delivery is OFF by default)

Nothing is sent unless ALL hold:

1. **Operator switch** `serverConfig/inactivityReminders.deliveryMode` is
   `all`, or `allowlist` with the uid in `allowlistUids` (≤ 100). A missing,
   invalid or unreadable document means `off`. Clients can neither read
   nor write it (rules). It is re-read before every page of a pass.
2. **Per-user readiness** `appSupportsServerReminders`: the user's app has
   written `users/{uid}/settings/notifications`. Only Stage 3+ builds do,
   and those no longer schedule the retired local reminder. Users still on
   an older build are tracked but never due.
3. **Per-device readiness:** only FCM tokens whose latest registration
   wrote `serverRemindersReadyAt` equal to `updatedAt` (current build) are
   sent to. Ownership still comes only from `fcmTokenOwners`.

When open, each pass sends at most `maxSendsPerPass` (gate document,
default 100), and reminders more than 6 h overdue are spread over the next
3 days' delivery windows instead of being sent in a burst.

Operations, the migration procedure and the staging plan are in
[`docs/inactivity-reminders-rollout.md`](../docs/inactivity-reminders-rollout.md).

## What it does

Workout inactivity push reminders, computed on the server from the workout
documents the app already uploads, plus FCM token ownership reconciliation.

| Function | Trigger |
| --- | --- |
| `onWorkoutSessionCreated` | create `users/{uid}/workout_sessions/{id}` |
| `onWorkoutSetCreated` | create `users/{uid}/exercise_sets/{id}` |
| `onReminderPreferencesWritten` | write `users/{uid}/settings/notifications` |
| `sendDueInactivityReminders` | every 60 minutes (UTC), `maxInstances: 1` |
| `onFcmTokenWritten` | write `users/{uid}/fcmTokens/{sha256(token)}` |

### Cadence

Reminder 1 is due 48 h after the latest qualifying activity, reminders 2–5
are due 72 h after the previous successful send, and reminder 6 onward 7 days
after it. A send happens at the first hourly run at or after the due time
that falls inside 10:00–21:00 in the user's time zone. New activity resets
the cycle. Example: workout Saturday 18:00 → Mon, Thu, Sun, Wed, Sat 18:00,
then weekly (each at 18:00).

**Re-enable grace period.** When a user turns reminders back on (stored off
→ on), nothing is sent for 48 h, even if the cadence is overdue. The next
reminder is due at `max(cadence due time, re-enable time + 48 h)`, then held
for quiet hours. Activity history and the reminder count are not reset.
Repeated deliveries of the same "on" do not extend it.

### Qualifying activity

Only the **creation** of a workout session or a set. Editing a set,
completing a session, deleting, opening the app or viewing screens do not
count. There is no throttling: every strictly newer activity is recorded
(about 1 read + 1 write per set; a duplicate or older event is 1 read, no
write).

Activity time = the client time (`startedAt`/`date`, Dart local time
without an offset, read in the user's time zone), but never later than the
server arrival time and trusted only up to 72 h late. Missing, invalid,
future or too-old client times use the arrival time. Activity recorded on a
device but **not yet synced is invisible to the server**: a user training
offline may get a reminder until the upload arrives.

### State

`users/{uid}/notificationState/inactivity` is server-owned (no client read
or write; enforced by firestore.rules and covered by the rules tests). It
holds the latest activity (effective, client and arrival times), `cycleId`,
`remindersSentInCycle`, `nextReminderAt` (the only queried field;
collection-group index in `firestore.indexes.json`), preferences, the
re-enable grace period, the lease and the last attempt with its status and
per-device counts.

### Delivery, crash recovery and retries

Claim (transaction, 15 min lease) → resolve devices → mark `sending`
(transaction; aborts on new activity, disabled reminders, a lost lease or an
attempt record that is not the claimed one) → FCM → record the result
(transaction).

A reminder advances the sequence only once it may have reached FCM. A claim
alone never counts.

| Outcome | Attempt status | Counted | Next step |
| --- | --- | --- | --- |
| FCM accepted ≥ 1 device | `accepted` | yes | cadence from now |
| no answer for a device (timeout/network) and none accepted | `outcome_unknown` | yes | cadence from now; never re-sent |
| every device rejected (retryable or not) | `retryable_failure` | no | same attempt id after 1, 2, 4, 8, then 24 h |
| no deliverable device | `no_deliverable_device` | no | check again in 24 h |
| provider call rejected before sending | `retryable_failure` | no | as above |
| crash after claim, before `sending` | stays `claimed` | no | same attempt id once the lease expires |
| crash after `sending` | `outcome_unknown` (recovered) | yes | cadence from when sending started |
| new activity during the attempt | `superseded` (or `outcome_unknown` if it crashed while sending) | no | new cycle |
| reminders turned off before sending | `cancelled` | no | nothing |

Attempt ids are deterministic (`cycleId:rN`). Retries and recovery are
deterministic functions of the stored state and the clock. The function
timeout (540 s) is shorter than the lease (15 min), so a live sender can never
lose its claim to a second sender (tested). FCM acceptance is not device
delivery, and exactly-once delivery is not claimed. The server never re-sends
an attempt that may have reached FCM. A rare `outcome_unknown` may mean one
lost reminder. The opaque collapse key per attempt makes a device replace,
not stack, any duplicate display.

The payload has the localized copy and `data.type = inactivity_reminder`
only, and an opaque collapse key. It carries no uid, workout data or times.

### Token ownership

`fcmTokenOwners/{tokenId}` = `{uid, registeredAt}` (no raw token,
server-only). The most recent registration owns a token. **Only tokens whose
owner is confirmed in the registry receive notifications.** Foreign-owned
and malformed copies are deleted at send time. Copies without an owner
record are kept but not used.

`onFcmTokenWritten` treats every create or update as a registration (the app
rewrites `updatedAt = request.time` on each app start of a signed-in,
verified user, on account switches and on token refresh) and every delete as
a release. Deleting the previous owner's copy, or a copy whose event
arrived late, is conditional: a copy re-registered after the event is never
deleted.

### Legacy token migration

Tokens stored before the registry existed have no owner and therefore
receive nothing until either:

1. the backfill assigns them: a token held by exactly ONE account is
   assigned to it, while a token held by several accounts (a shared device
   whose logout cleanup did not run) is ambiguous and is never assigned; or
2. the app registers the token again (next app start of the signed-in
   account). This is the only way an ambiguous token becomes eligible, and
   it goes to the account that actually uses the device.

```
npm run build
# emulator (no flags needed beyond the project):
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run migrate:token-owners -- --project demo-ae-coaching
# live project (only after approval): dry run first, then apply
npm run migrate:token-owners -- --project <id> --allow-live
npm run migrate:token-owners -- --project <id> --allow-live --apply --confirm-project <id>
```

The dry run reads only. An apply only creates missing owner records
(transactionally, never overwriting), marked `source: "migration"` so they
can be rolled back precisely. It never deletes or edits user token
documents and is idempotent. The report lists counts and pseudonymous
references for ambiguous tokens, with no uid or token.

## Deployment

Not done; every step needs approval. Prerequisites, order and rollback are
in [`docs/inactivity-reminders-rollout.md`](../docs/inactivity-reminders-rollout.md).

## Layout

```
src/
  index.ts                 Admin SDK init + exports
  compositionRoot.ts       dependency wiring (lazy, once per instance)
  shared/                  time zones, clock/ids/logger ports and adapters
  inactivity/
    domain/                policy, cadence, activity time, state machine, messages
    application/           use cases + ports
    infrastructure/        Firestore and FCM adapters
    entrypoints/           triggers and the scheduler
  tokens/
    domain/                token validation, ownership decision, migration plan
    application/           reconciliation, deliverable directory, migration
    infrastructure/        Firestore registry, user tokens, inventory
    entrypoints/           write trigger, migration CLI (operator tool)
test/
  support/                 in-memory fakes and the harness
  unit/                    domain, use cases, concurrency, adapters, config
  emulator/                Firestore adapters and migration against the emulator
```

## Running checks locally

```
npm install
npm run typecheck
npm run build
npm run test:unit            # no Firebase project or emulator needed
npm run test:emulator:exec   # starts the Firestore emulator (Java 21), demo project
cd ../firestore-tests && npm test   # security rules
```

FCM is always mocked. The emulator tests refuse to run without
`FIRESTORE_EMULATOR_HOST` and use the `demo-ae-coaching` project only.
