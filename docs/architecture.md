# Architecture

This document describes the app's startup flow, dependency wiring, storage
ownership, error handling, and workout feature layering as they exist after
the architecture cleanup (dependency-injection modularization, workout
feature-structure normalization, redundant use-case removal, and naming/
technical-debt cleanup).

## Startup / bootstrap flow

`main.dart` is a minimal entry point:

```dart
void main() async {
  await AppBootstrap.initialize();
  runApp(const MyApp());
}
```

`AppBootstrap.initialize()` (`lib/core/bootstrap/app_bootstrap.dart`) runs, in
this exact order:

1. `WidgetsFlutterBinding.ensureInitialized()` — first statement, before any
   `await`.
2. `_initializeFirebase()` — `Firebase.initializeApp()`, then
   `FirebaseAppCheck.instance.activate(...)`.
3. `_initializeDependencies()` — calls all 16 `init*()` dependency
   registration functions (see below), synchronously, in a fixed order.
4. `_initializeStorage()` — `Hive.initFlutter()`, then
   `registerHiveAdapters()` (6 guarded `Hive.registerAdapter` calls, one per
   typeId), then `await Hive.openBox('authBox')`.

Every DI registration is a deferred closure (`registerLazySingleton` /
`registerFactory`) — nothing is resolved during `_initializeDependencies()`
itself, so the fact that dependency registration runs *before* Hive is
initialized is not a bug: the first real resolution only happens once a
widget builds, well after `runApp()`.

## Authentication lifecycle

**Email-first since Stage 3B.** Firebase Auth Email/Password is the
identity. Verification is Firebase's email link, and password recovery is
Firebase's reset email. Phone/SMS authentication, its screens and the
(never deployed) SMS Cloud Functions were removed in Stage 3C.
`test/auth/auth_security_regression_test.dart` fails if phone-auth APIs
or `cloud_functions` reappear.

`AuthStatus` (`lib/auth/domain/entities/auth_status.dart`) is the single
answer to "what may this user do". The email flow produces it as an
`EmailSessionResolution` from `EmailAuthRemoteDataSourceImpl._resolve`,
and login, registration, startup and verification refresh all use that
same function:

| Status | Meaning | Reachable |
| --- | --- | --- |
| `unauthenticated` | no Firebase identity | Login, Register, Forgot Password |
| `pendingEmailVerification` | Email/Password account, email not verified | Verify Email only |
| `incompleteProfile` | verified, but `users/{uid}` missing and no name recoverable | Complete Profile only |
| `authenticated` | verified identity + profile | Home and features |
| `unsupportedLegacyAccount` | phone-era test account (`@ae-coaching.app` synthetic email) | signed out → Login |
| `profileUnavailable` | verified, but the profile can't be confirmed (offline, `permission-denied`, conflicting `uid`) | account check: real reason + Retry / Sign out |

Phone-era test accounts are left untouched in Firebase (Stage 3A decision
A): no Auth user, document or Hive box is modified or deleted. A device
with such a session is just signed out, and the reserved domain can't be
used to register or sign in.

**Registration.** `createUserWithEmailAndPassword`, then (best-effort,
never failing the call) the display name, a **create-only** profile, and
the verification email. Once the account exists a retry never calls
"create" again. A missing profile is rebuilt from the display name the
next time the session is resolved, and the user is asked for a name only
if none is usable.

**Profile integrity.** A verified account reaches `authenticated` only
when its profile is confirmed valid on the server (`assessProfile`:
`uid` matches and `name` passes the name rule). A missing or invalid
profile is created or repaired (`createOrRepair` fills only missing
fields and never overwrites `createdAt` or a valid name), then re-read
before entering. A conflicting `uid` is never written to. Every read or
write failure becomes `profileUnavailable` with its real reason.
`permission-denied` is never shown as success or as a generic error. The
remaining known gap: the offline Home fast path trusts the local marker,
which is written only after a confirmed profile, so a profile deleted
server-side later isn't re-checked on device. Server rules (3D) close
that.

**Profile** (`users/{uid}`, via `UserProfileStore`): `uid`, `name`,
`email`, `createdAt`, `updatedAt`. It is written in a transaction that
never touches an existing document. That fixes the phone-era
`set(merge: true)` that re-stamped `createdAt`. No password, token or
verification flag is ever stored, since Firebase Auth owns those.
`email` is re-synced after an email change.

**Startup.** `resolveStartupDestination`
(`lib/core/bootstrap/startup_destination.dart`) works offline from
Firebase's persisted user:

- no Firebase user → Login;
- Firebase user + local marker for the same uid + verified (or
  federated) + not legacy → Home;
- anything else → `SessionReconciliationView`, which reloads the user from
  the server and routes by `AuthStatus`. A failed check (offline) offers
  Retry / Sign out and is never treated as signed out.

**Verify Email.** Resend has a 60s cooldown. "I've verified" reloads the
user and, once verified, force-refreshes the ID token so server rules see
`email_verified` immediately. The state is also re-checked silently when
the app returns to the foreground. "Change email" uses
`verifyBeforeUpdateEmail`, so the sign-in email changes only after the
new address is confirmed. Back (and Android back) confirms, then signs
out to Login.

**Only one place persists the session**: `AuthFlowNavigation.enterApp`,
which is reached only from `AuthSuccess` (status `authenticated`). A
structural test pins this across every auth screen.

### Client-side gating vs server-side authorization

Everything above is **client-side**. The router guard
(`AppRouter.guardedRouteName` / `canEnterProtectedRoute`) redirects any
non-auth route (Home, every feature route, any future route) to the
startup check unless Firebase's persisted user is signed in, verified
(when required) and not legacy. That stops navigation from bypassing
verification, whether through a stray `pushNamed`, the back stack or a
future deep link. It is **not authorization**: a modified client can skip
any on-device check.

Server-side enforcement is `firestore.rules` (Stage 3D, **written and
emulator-tested, not yet deployed**). The rules authorize from the ID
token, so the app refreshes the token whenever its `email_verified` or
`email` claim is stale (`_ensureTokenIsCurrent`, and after "I've
verified"). Until the new rules are deployed, production still runs the
older Console rules: owner-only, with no verification or field checks.

### Firestore security rules (Stage 3D)

Access inventory, taken from the code. There are no root collections, no
FCM tokens, no settings documents, and no Firebase Storage: progress photos
are local Hive only.

| Path | Used by | Operations | Auth required |
| --- | --- | --- | --- |
| `users/{uid}` | `FirestoreUserProfileStore` | get; transactional create/repair; update (email sync) | owner. get/create allowed unverified (registration); update needs verified |
| `users/{uid}/exercise_sets/{id}` | `WorkoutRemoteDataSourceImpl` | set, delete, batch delete, list `orderBy(date)` | verified owner |
| `users/{uid}/body_measurements/{id}` | `MeasurementRemoteDataSourceImpl` | set, delete, list `orderBy(date)` | verified owner |
| `users/{uid}/workout_programs/{id}` | `WorkoutProgramRemoteDataSourceImpl` | set, delete, list `orderBy(createdAt)` | verified owner |
| `users/{uid}/workout_templates/{id}` | `WorkoutTemplateRemoteDataSourceImpl` | set, delete, list `orderBy(createdAt)` | verified owner |
| `users/{uid}/workout_sessions/{id}` | `WorkoutSessionRemoteDataSourceImpl` | set, delete, list `orderBy(date)` | verified owner |

Policy:

- **Deny by default.** There is no recursive `{document=**}` wildcard, so
  any unknown path or subcollection is denied.
- **Profile create:** owner, verified or not; exactly `uid, name, email,
  createdAt, updatedAt`; `uid` equals the path; the name passes the app's
  name rule; `email` equals the caller's token email (lower-cased); both
  timestamps equal `request.time`.
- **Profile update:** verified owner. Only profile fields may change, so
  legacy fields such as `phoneNumber` can't. `uid` stays the owner, so a
  conflicting document can't be taken over. An existing `createdAt` is
  immutable. `name` and `email` are validated only when they change.
  `updatedAt` must be `request.time`.
- **Profile list and delete:** denied.
- **Workout and progress data:** verified owner only. Writes must contain
  exactly the keys their model's `toJson()` writes, with matching types,
  and the query's ordering field is required.

Tests: `firestore-tests/` (49 emulator tests: `npm test`, which needs Java
21+). Rules are mutation-checked: removing the verification requirement,
the `createdAt` immutability or the `uid` check each makes tests fail.
`test/core/firestore_rules_source_test.dart` keeps the file wired into
`firebase.json` and free of recursive wildcards and blanket allows.

**Deploying** (manual, never done by the app or its tooling):

1. Back up: copy the live rules from Firebase Console → Firestore → Rules
   into a dated file. The Console also keeps rule history for rollback.
2. Ship the app build containing the token-refresh change first, or at
   the same time. Older builds don't refresh a stale `email_verified`
   claim, so for up to an hour after verifying, their writes would be
   denied.
3. Run `cd firestore-tests && npm test` and confirm 49/49.
4. Optionally paste the rules into the Console Rules Playground and spot
   check a verified and an unverified request.
5. `firebase deploy --only firestore:rules` (rules only, nothing else).
6. Smoke test on a device: register, verify, log a set, add a measurement,
   restart offline.
7. Rollback: republish the backed-up rules from Console history.

### Registration input rules (Stage 2)

`AuthInputRules` (`lib/auth/domain/validation/auth_input_rules.dart`) is the
single policy. The UI uses it for localized feedback, and the use cases
re-check it through `AuthInputGuard` before Firebase is called (in
`email_auth_usecases.dart`: register checks name, email and password;
login, password reset and email change check the email; Complete Profile
checks the name). Firebase Auth remains the real enforcement.

- **Password:** min 6 characters (Firebase Auth's default; keep it equal
  to the Console password policy), max 128, and no leading/trailing
  whitespace.
  New passwords are **rejected, not trimmed**, and sent exactly as typed.
  Login still trims (`passwordForSignIn`): every historical write path
  trimmed, so no stored password has edge whitespace, and autofill can
  append a trailing space. Don't remove that trim.
- **Name:** trimmed with whitespace collapsed. Any script, single letters
  OK. It only needs a letter and at most 60 characters.
- **Email (Stage 3B):** trimmed and lower-cased, deliberately loose shape
  check, max 254 characters. The phone-era domain `ae-coaching.app` is
  reserved.
- **Errors:** `localizeAuthError` translates the fixed set of client
  error strings. `test/core/localization/auth_message_localizer_test.dart`
  extracts them from source and fails if one is untranslated. It also
  rejects duplicate ARB keys.

## Dependency registration modules

`lib/service_locator.dart` is a pure re-export barrel — it holds no
registration logic of its own. It exports:

| File | Owns |
|---|---|
| `lib/core/di/sl_instance.dart` | The single `final sl = GetIt.instance;` |
| `lib/core/di/core_dependencies.dart` | `SessionStorage`, `UserStorageManager` |
| `lib/core/di/auth_dependencies.dart` | The Auth feature: `EmailAuthRemoteDataSource`, `EmailAuthRepository`, `EmailAuthUseCases` (input-guarded at the domain boundary), `AuthCubit` |
| `lib/core/di/workout_dependencies.dart` | The legacy, flat `sets_$uid` stack: `WorkoutRepository`, `WorkoutRemoteDataSource`, `WorkoutCubit` |
| `lib/core/di/measurements_dependencies.dart` | Body Measurements feature |
| `lib/core/di/progress_photos_dependencies.dart` | Progress Photos feature (local-only, no remote data source) |
| `lib/core/di/workout_programs_dependencies.dart` | The Program/Template/Session/SessionExercise stack — 11 registrations kept in one file because they cross-reference each other's repositories extensively; splitting further would only add cross-file coupling with no real ownership boundary to show for it |

Every `init*()` function is still reachable by its original bare name via
`import 'package:ae_coaching/service_locator.dart';` — `AppBootstrap` and
every UI composition call site (the router, `hom.dart`, auth views,
`measurements_screen.dart`) are unchanged.

**Lifetimes**: 26 lazy singletons, 13 factories. The one deliberate exception
is `WorkoutSessionCubit`, registered as a lazy singleton (not a factory) —
"is a workout currently active" is a cross-cutting, app-wide concern that the
Programs hub, Workout Days screen, and the active-session screen must all
observe as the exact same instance.

**Composition boundary discipline**: `sl<T>()` is only ever called from UI
composition code (the router, `hom.dart`, auth views for
`SessionStorage.persistLoggedInSession`) and from `AppBootstrap` itself.
No repository, Cubit constructor body, or core storage class resolves
anything from GetIt — every dependency arrives through the constructor.

## SessionStorage

`lib/core/session/session_storage.dart` wraps the already-open global
`authBox` and exposes its canonical keys (`isLoggedIn`, `currentUserUid`,
`currentUserName`, `currentUserEmail`; the phone-era `currentUserPhone` is
only ever deleted) behind named methods
(`persistLoggedInSession`, `clearSession`, `markLoggedOut`,
`updateCurrentUserUid`), replacing what used to be duplicated raw
`Hive.box('authBox').put(...)` call sites across 6+ auth views and
`WorkoutCubit`.

`LocaleCubit` (`lib/core/localization/locale_cubit.dart`) independently owns
one more key (`appLocale`) in that same `authBox`. This is a deliberate,
disjoint-key overlap, not a bug — a Hive box is just a key-value map, and two
owners writing to different keys in it is safe. Neither class reads or
writes the other's key. Each class's doc comment cross-references the other
so this is discoverable without archaeology.

## UserStorageManager ownership/lifecycle

`lib/core/storage/user_storage_manager.dart` is the single production
lifecycle owner for every per-user Hive box (`sets_$uid`,
`workout_programs_$uid`, `workout_templates_$uid`, `workout_sessions_$uid`,
`measurements_$uid`, `progress_photos_$uid`). It is deliberately **not** a
static/shared singleton on the class itself — `initCore()` registers exactly
one instance as a GetIt lazy singleton, and every repository/Cubit that needs
it receives it by constructor injection, never by calling GetIt itself.

Guarantees:

- `getUserBox<T>(prefix, uid)` validates prefix, `T`, and a non-empty `uid`
  deterministically, before ever touching Hive.
- Concurrent opens for the same box dedupe to a single underlying
  `Hive.openBox` call.
- `closeForUser(uid)` closes all of that uid's owned boxes; a new open for a
  uid mid-close is rejected (`StateError`), not queued.
- Close failures are aggregated — one box failing to close doesn't stop the
  others from being attempted — and re-thrown as `UserStorageCloseException`
  so a logout doesn't silently report success.

Residual limitation: the manager returns raw `Box<T>` references, so it
cannot retroactively cancel an operation that already obtained a box before
`closeForUser` began — that box's behavior during a concurrent logout is
governed by Hive's own close/write semantics, not by the manager.

## Error mapping and domain-exception precedence

`lib/core/errors/exception_message_mapper.dart` provides one shared
function:

```dart
String mapGenericExceptionToMessage(Object error)
```

It trusts exactly one shape: a plain `Exception('...')` whose `toString()`
starts with `'Exception: '` — that prefix is stripped and the remainder
returned verbatim. Everything else (`ArgumentError`, `StateError`, any
`Error` subtype, or a custom class that merely `implements Exception`
without that exact prefix) maps to a stable generic fallback
(`'Something went wrong. Please try again.'`), so no raw Dart/Hive/Firestore
technical text can reach a SnackBar or inline error `Text`.

13 Cubits/blocs use this shared mapper in their generic `catch` blocks. Where
a domain exception carries its own pre-crafted, user-safe message —
`InvalidWorkoutSessionStateException` (`WorkoutSessionCubit`'s
`cancelWorkout`/`finishWorkout`) — it is caught in an explicit
`on SomeException catch (e)` branch **ahead of** the generic catch, and its
`e.toString()` is used directly, never passed through the generic mapper.
`ActiveWorkoutSessionExistsException` similarly short-circuits to a distinct
state (`WorkoutSessionConflict`) before the generic catch is ever reached.
This precedence — domain-specific handling first, generic mapper last — is
the rule for any future exception type that carries its own safe message.

Auth's `_mapFirebaseAuthException` / `_mapFunctionsException`
(`lib/auth/data/datasources/auth_remote_data_source.dart`) are separate,
unrelated mappers and were not touched: one is a closed `FirebaseAuthException`
code table, the other trusts backend-authored `FirebaseFunctionsException`
messages by design. Both remain exactly where they are.

## Workout feature layers

`lib/features/workout/` contains **two parallel stacks**:

- **Legacy** (`data/repositories/workout_repository_impl.dart`,
  `presentation/bloc/workout_cubit.dart`): the original flat
  `sets_$uid` `ExerciseSet` box. `WorkoutCubit` injects `WorkoutRepository`
  directly (its four use-case wrappers were removed — each was a pure
  single-repository-method pass-through, and unlike Auth's use cases, they
  were the only place left in the Workout feature still using that
  indirection).
- **Programs domain** (Program/Template/Session/SessionExercise, plus the
  read-only analytics/history/overview/consistency Cubits and
  `WorkoutCascadeDeletionService`): every Cubit injects its repository
  directly — there is no use-case layer here, by original design, and this
  was the majority precedent that justified removing the legacy stack's
  wrappers too.

Layout, by layer:

- `data/models/` — Hive-backed models (`exercise_set.dart` and its generated
  `.g.dart` part now live here, alongside `workout_program.dart`,
  `workout_template.dart`, `workout_session.dart` — previously
  `exercise_set.dart` incorrectly lived under `lib/auth/data/models/`).
- `data/datasources/` — one Firestore-backed remote data source per model.
- `data/repositories/` — one repository per model, each taking
  `UserStorageManager` (required) and an optional `remoteDataSource`
  (defaults to a real `XxxRemoteDataSourceImpl()` — production `service_locator`
  registrations rely on this default for the Program/Template/Session/
  SessionExercise repositories; only Auth's and the legacy Workout's remote
  data sources are separately registered and explicitly injected).
- `domain/repositories/`, `domain/services/`, `domain/usecases/` — pure
  domain logic; the legacy stack's `domain/usecases/` is now empty (kept as
  a directory placeholder is unnecessary — it no longer exists on disk).
- `presentation/bloc/` + `presentation/cubit/` — one Cubit per screen
  concern; `WorkoutSessionCubit` is the sole app-wide singleton.
- `presentation/screens/` + `presentation/widgets/` — UI.

`Auth`'s use cases (11 of them) were audited under the same "is this a
zero-value pass-through" criteria and **kept**: every one of them wraps
exactly one repository method with no added logic, but they are a uniform,
deliberate convention spanning **100%** of the Auth feature's operations
(unlike the legacy Workout stack, where they were an inconsistent leftover)
— removing them would gain nothing behaviorally and would require rewriting
`AuthCubit`'s constructor and its large existing regression test suite for
no benefit.

## Testing strategy

- **Real, non-Firebase unit/widget tests** are the default: Hive-backed
  repositories and Cubits are tested against a real temporary Hive directory
  (`Directory.systemTemp.createTemp(...)` + `Hive.init(...)`), never mocked,
  and hand-rolled fake remote data sources (implementing the abstract
  `XxxRemoteDataSource` interface, doing nothing) stand in for Firestore.
- **Source-regression tests** (reading a `.dart` file's text and asserting on
  structure) are used only where real execution is impossible in this
  environment — chiefly anything requiring `Firebase.initializeApp()` (no
  platform channel here), such as `AppBootstrap.initialize()` itself, or
  proving Auth's FirebaseAuthException code-table mapping without a live
  Firebase project.
- **DI registration tests**
  (`test/core/di/service_locator_split_test.dart`) run the same 16
  `init*()` functions AppBootstrap calls, against a disposable GetIt
  instance, and prove every registered type's lifetime (identical instance
  for lazy singletons, distinct instances for factories) for the subset that
  doesn't transitively require Firebase, plus `isRegistered<T>()` presence
  checks for everything else.
- A recurring pitfall worth knowing: a source-regression test that does a
  bare substring search against a file's own text can be false-failed by
  that file's own explanatory doc comment mentioning the searched string in
  prose. When writing this kind of test, check for an actual `import`
  statement or code pattern, not a loose substring.

## Known limitations

- **Real disk I/O and widget tests don't mix by default.** Flutter's default
  `testWidgets` runs inside a fake-async zone, where a genuine `Hive.openBox`
  or `box.put` can never complete. Anything a widget's `initState()` opens
  must be pre-opened in `setUp()` (a plain zone) so the widget hits
  `UserStorageManager`'s already-open fast path, and any test-body seeding
  that writes to Hive must go through `tester.runAsync`. See
  `test/features/workout/workout_programs_screen_test.dart`; awaiting real
  I/O directly in a `testWidgets` body hangs rather than fails.
- `docs/architecture.md` (this file) is a snapshot as of the cleanup
  described above — treat it as a starting map, not a substitute for reading
  the code for any area under active change.
