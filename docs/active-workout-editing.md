# Active workout exercise editing

## Root cause

The workout day and active workout intentionally have separate exercise lists. Starting a workout captures `templateExerciseAssignmentsSnapshot`. Day-editor mutations change `WorkoutTemplate.exerciseAssignments`; they do not update that snapshot. The active screen's old permanent-change branch wrote only to the day repository and returned a future-workouts-only message. Its target summary also read the immutable route argument even when `SessionExerciseCubit` had reloaded persisted rows. Repainting that screen could not synchronize the two records.

The original session add/replace/remove paths used name lists and hidden names separately from the assignment snapshot. They could hide an exercise with logged sets, leaving its recorded data included in completion calculations but invisible while training. Reordering only changed the session, and active target editing was unavailable.

## Behavior

The prominent Add Exercise button is in the active screen's top bar. Each exercise's contextual menu supports Replace, Remove, Move up/down and Edit sets, reps & rest; drag reordering remains available. Session notes and Apply program exercises are in the top-bar overflow menu. Finish and Cancel occupy the scaffold's bottom action area. This removes the original floating button's overlap with Cancel and prevents it from covering exercise actions. All mutations offer **This Session Only** (selected by default) and **This Session + Program** in English and Arabic. Cancelling the scope, picker or target dialog writes nothing.

The active screen renders the current persisted session exposed by `SessionExerciseLoaded`, including each row's assignment/targets. The route argument supplies initial identity only. Hive session/set subscriptions keep mounted views synchronized, including when another screen instance writes; subscriptions are cancelled on disposal and recreated after box reopen. Updates refresh rows without a loading-screen replacement, preserve row keys for unchanged exercises and retain list position with PageStorage. Session lifecycle/navigation remains owned by the existing app-wide `WorkoutSessionCubit`; it is not a second exercise editor.

Scope behavior:

- Session Only changes the active session's local assignment snapshot, optional session-only names, hidden-name exclusions and explicit order. It never writes the day.
- Session + Program coordinates that same session edit with the corresponding source-day assignment edit. It modifies the affected exercises only. Reordering updates the relative order of program-assigned rows while retaining unrelated day entries and session-only rows in their respective scopes.
- A session-only addition can later be saved to the day by editing its targets or replacing it with Session + Program. Removing such a row does not remove unrelated source-day exercises.
- Assignment IDs and targets survive replacement. Existing catalog IDs and exercise definitions remain unchanged. Legacy name-only rows get explicit local manual references when materialized; they are not added to the bundled catalog.
- Planned sets/reps/rest stay guidance. They do not create sets, start timers or contribute to volume, personal records or analytics.

Program edits elsewhere affect future workouts. They never overwrite the active snapshot automatically. **Apply program exercises** in the active app bar offers a confirmation before replacing today's exercise layout/targets with the current day. It refuses to drop any exercise with logged sets. Normal Session + Program edits also refuse to overwrite a source assignment that changed or was removed elsewhere; users can choose Session Only or explicitly apply the day first.

## Logged-set safety

Remove and Replace are blocked for any exercise with recorded sets, both in the UI and coordinator. The localized explanation directs users to keep the recorded exercise and add another. Order and planning targets remain editable. No sets are silently deleted or reassigned. Legacy hidden logged rows are shown again so recorded data stays visible. Existing explicit individual-set deletion retains its confirmation flow.

## Persistence, failure and recovery

`ActiveWorkoutEditService` reads the current records under the session and day repositories' existing mutation queues. It validates active status, owner-box identity, current signed-in user, duplicate IDs/names, order and targets before writing. Repeated actions are guarded in the screen/Cubit and serialized in the service. Existing duplicate-exercise rules are retained.

Session, note and terminal lifecycle writes share the session queue. New set logging also checks the persisted active session under that queue. Finishing/cancelling is blocked while a program edit is unresolved. A failed initial session write publishes no success and changes neither scope.

Hive cannot atomically write two different boxes. The session model therefore adds **nullable Hive field 15**, `pendingProgramExerciseEdit`, with the existing type ID 5 and existing fields unchanged. It holds the expected and desired source-day assignments as local JSON. Old fifteen-field records read null; no migration, clearing, box rename or adapter-ID change occurs.

For Session + Program, the session layout and intent are written together first, then the day, then the intent is cleared. If the second write or final acknowledgement fails, the UI reports a saved session with an unfinished program update and blocks further edits/finish until resolved. It never reports both scopes saved. Retry applies the intent only if the day still matches the expected version; if already applied it only clears the intent. Later conflicting day edits are never overwritten. Reopening the workout attempts this recovery. Users can also stop retrying, retaining their session and any day write already completed; that action does not claim to undo a previously written program change.

Session state is re-read after navigation and background/resume. Disk close/reopen tests cover persisted layout/targets and interrupted two-box writes. The pending field is preserved by note updates and local/remote merges, and excluded from Firestore JSON. Assignments/targets retain the existing local-only synchronization policy. No new backend, remote collection, Firebase configuration, API or dependency was added.

## Files

Created:

- `lib/features/workout/data/repositories/active_workout_edit_service.dart`
- `test/features/workout/active_workout_edit_service_test.dart`
- `test/features/workout/active_workout_edit_widget_test.dart`
- `docs/active-workout-editing.md`

Modified:

- `lib/features/workout/data/models/workout_session.dart` and `.g.dart`: additive nullable local recovery field.
- `lib/features/workout/data/repositories/workout_session_repository.dart`: shared queue, owner accessor, pending lifecycle guards/preservation.
- `lib/features/workout/data/repositories/workout_template_repository.dart`: expose its existing assignment mutation queue for coordinated writes.
- `lib/features/workout/presentation/cubit/session_exercise_cubit.dart` and `_state.dart`: authoritative persisted session/assignment rows, coordinated mutations/recovery, stale-load protection and logged-row safety.
- `lib/features/workout/presentation/screens/active_workout_session_screen.dart`: scoped editing, current target display, program apply/recovery UI, lifecycle refresh and action guards.
- `lib/features/workout/presentation/widgets/exercise_picker_dialog.dart`: optional localized save-error formatter; existing callers keep their behavior.
- `lib/core/di/workout_programs_dependencies.dart`: inject the shared edit service.
- `lib/l10n/app_en.arb`, `app_ar.arb`, and their three generated localization files.
- `test/features/workout/session_exercise_test.dart`: update removal expectations to the safer logged-set policy; replacement regression uses an unlogged exercise and preserves another exercise's recorded sets.

## Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Initial feature, snapshot, template, lifecycle and history focused tests | 122 passed, 14 seconds | Initial active-workout validation |
| Final shared navigation/active-edit focused regressions | 41 passed, 18 seconds | `build/workout-navigation-focused.log` |
| Final analyzer: `flutter analyze --no-pub` | No issues found, 17.4 seconds | `build/workout-navigation-analyze.log` |
| Existing exercise-media validator | Passed: original 180 IDs, 144 illustrations, 106 links | `python tool/report_exercise_media.py --check` |
| Final full Flutter suite | 591 passed, 84 seconds | `build/workout-navigation-full-tests.log` |
| Debug APK and package inspection | Passed: fresh compiled kernel, template data and unchanged bundled media verified | `build/workout-navigation-apk.log`, `build/workout-navigation-package-result.json`, `build/workout-navigation-package-verification.log` |

Initial feature-focused command: `flutter test --no-pub --reporter expanded` with these paths:

- `test/features/workout/active_workout_edit_service_test.dart`
- `test/features/workout/active_workout_edit_widget_test.dart`
- `test/features/workout/session_exercise_test.dart`
- `test/features/workout/workout_session_repository_test.dart`
- `test/features/workout/workout_session_cubit_test.dart`
- `test/features/workout/template_exercise_session_persistence_test.dart`
- `test/features/workout/workout_template_repository_test.dart`
- `test/features/workout/workout_finish_experience_test.dart`
- `test/features/workout/standard_workout_templates_test.dart`

The new service tests cover all five operations in both scopes, recorded-set/history preservation, real old fifteen-field Hive bytes, legacy hidden logged rows, two mounted views observing the same persisted layout/sets, initial/second/final write failures, retry, disk close/reopen, concurrent repeated requests, later source conflicts, session-only promotion and account isolation. Widget tests cover English/dark/LTR and Arabic/light/RTL, scope defaults, the real shared exercise picker, live targets despite a stale route argument, navigation, legal background/resume transitions, logged-row protection and failed-write retry. Hive timestamp compatibility is checked at its existing millisecond precision.

Follow-up validation includes phone-sized 360 x 780 editing and a check that Add Exercise cannot overlap Cancel Workout. Mutation queues initialize on their first operation so queued lifecycle writes also work across Flutter tests' real/fake async boundary. The final 591-test run includes the existing light/dark analytics and history tests. The separate [navigation report](workout-template-navigation.md) records the typed named-route regression and exact final focused paths.

Physical-device verification is separate from widget and Hive tests. No app data is cleared or app uninstalled. All tests use temporary Hive directories and fake remotes, without production Firestore access. Exercise illustrations, MuscleWiki mappings, existing programs/history, catalog definitions and Firebase configuration are outside this change.
