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

## Dependency registration modules

`lib/service_locator.dart` is a pure re-export barrel — it holds no
registration logic of its own. It exports:

| File | Owns |
|---|---|
| `lib/core/di/sl_instance.dart` | The single `final sl = GetIt.instance;` |
| `lib/core/di/core_dependencies.dart` | `SessionStorage`, `UserStorageManager` |
| `lib/core/di/auth_dependencies.dart` | The Auth feature: 11 use cases, `AuthRepository`, `AuthRemoteDataSource`, `AuthCubit` |
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
`authBox` and exposes 4 canonical keys (`isLoggedIn`, `currentUserUid`,
`currentUserName`, `currentUserPhone`) behind named methods
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
