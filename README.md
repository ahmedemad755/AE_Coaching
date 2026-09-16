# AE Coaching

A Flutter fitness-coaching companion app for tracking structured workout programs, body measurements, and visual progress over time — backed by Firebase and available in Arabic and English.

## Features

### 🏋️ Workout Programs (Program → Workout Day → Session)

The core of the app is a three-level structure: a **Program** (e.g. "Push Pull Legs") contains reusable **Workout Days** (e.g. "Push", "Pull", "Legs"), and each time you actually train one, that's a **Session** — a dated record of exactly what you did.

- **Programs**: create, rename, set one as active, archive, or permanently delete (with a cascading, explicit confirmation that removes every workout day/session/set under it).
- **Workout Days**: create and reorder them within a program, rename, archive, restore from the dedicated **Archived Workout Days** screen, or permanently delete (cascades to that day's sessions/sets only).
- **Start / Resume / Finish / Cancel a workout**: starting a workout always creates a real session; the app never lets two sessions run at once — if one is already in progress, you're offered to resume it instead of silently starting a second one.
- **Auto-loaded structure & previous performance**: opening a workout day suggests the exercises you logged last time (Push is never compared to Pull), and shows what you lifted for each exercise last time, right next to where you're logging it now.
- **Workout Completion Summary**: after finishing, see total volume vs. last time, a per-exercise "improved / maintained / declined" comparison, and any new personal records — a heaviest-weight or best-single-set PR is tracked per exercise across your whole account, independent of which program or day it happened in.
- **Optional rest timer**: a manual, count-up stopwatch you start and stop yourself — never an automatic countdown.
- **Session & exercise notes**: a free-text note per session, and an optional note per logged set.
- **Workout day history**: every session ever logged for one workout day, newest first, with duration and total volume.
- **Program analytics**: an all-time Program → Day → Exercise breakdown (best weight, latest volume, trend), plus a real consistency view — current/longest weekly streak, average sessions per week, days since your last session. No fabricated "adherence %" — every number is a real, counted fact.
- **This Week card**: a plain count of completed sessions per workout day this calendar week (Monday–Sunday).

### 🏠 Home — Workout Overview

The home screen is a prepared, read-only dashboard (no business logic lives in the screen itself):

- A prominent **Workout in Progress** card if a session is active, with one tap to resume it.
- Your **active program** and how many workouts you've completed this week, with one tap into its Workout Days.
- Your most recent completed sessions across every program, as expandable session cards (exercise/set counts, total volume, an optional exercise-name preview) — never a flat list of individual exercises.
- Every workout is now logged through a real session (Start Workout from a program's Workout Days screen); there is no separate one-off/manual exercise entry anymore.

### 📜 Legacy Workout Data

Exercise sets logged before the Program/Session architecture existed are preserved exactly as they were — nothing is migrated, guessed, or reassigned to a program. That historical data still feeds the original **Today's Volume** stat and **Progress Analysis** trend view on the home screen's legacy panel.

### 📏 Body Measurements
- Track 11 body measurements per check-in (chest, waist, hips, shoulders, neck, arms, thighs, calves) — every field is optional.
- Full history with edit/delete.
- Analytics comparing **Since Previous Check-in** and **Overall Progress** (first vs. latest) per body part, computed independently for each measurement so a missing value never breaks another field's comparison.
- Synced to Firestore per user, so check-ins survive logout, app kill, or a full reinstall.

### 📸 Progress Photos
- Attach a before/after photo to your transformation timeline, optionally right after saving a measurement check-in.
- Automatic **Since Latest Photo** and **Overall Progress** before/after comparisons, paired by date.
- Stored locally on-device (not uploaded to the cloud).

### 🔐 Authentication
- Phone number + password login via Firebase Auth.
- Registration with SMS OTP verification.

### 🌐 Localization
- Arabic (default) and English, with a language toggle available from the login screen and the home screen.
- Full RTL layout support when Arabic is active.

## Tech Stack

- **Flutter** (SDK `^3.9.2`) with Material 3
- **State management**: `flutter_bloc` (Cubit) — the sole state-management approach across every feature
- **Dependency injection**: `get_it`
- **Local storage**: `hive` / `hive_flutter` (per-user boxes, offline-first)
- **Backend**: Firebase — `firebase_auth`, `cloud_firestore`, `firebase_core`
- **Localization**: `flutter_localizations` + generated `AppLocalizations` (ARB-based)
- **Dates**: `intl`
- **Media**: `image_picker`, `path_provider`, `screenshot`, `share_plus`

## Project Structure

```
lib/
├── auth/                      # Login, registration, OTP, auth models
├── core/
│   ├── localization/          # LocaleCubit, auth message localizer
│   └── routes/                # AppNavigator / AppRouter
├── features/
│   ├── workout/
│   │   ├── data/
│   │   │   ├── models/            # WorkoutProgram, WorkoutTemplate, WorkoutSession, ExerciseSet
│   │   │   ├── datasources/       # Firestore per-collection sync for each model above
│   │   │   ├── repositories/      # Offline-first Hive+Firestore repositories, cascade delete service
│   │   │   └── workout_id_generator.dart
│   │   ├── domain/
│   │   │   ├── services/          # Pure comparison/analytics/consistency/home-overview services
│   │   │   └── usecases/          # Legacy Workout Tracker use cases
│   │   └── presentation/
│   │       ├── cubit/             # One Cubit per screen/section (Programs, Days, Session, Analytics, ...)
│   │       ├── screens/           # Programs, Workout Days, Active Session, Summary, History, Analytics, Archive
│   │       ├── widgets/           # Dialogs, Home overview section, rest timer, log-set dialog
│   │       └── bloc/              # Legacy WorkoutCubit (Today's Volume / Progress Analysis)
│   ├── analytics/               # Legacy workout progress share screen
│   ├── measurements/            # Body Measurements feature (data/presentation)
│   ├── progress_photos/         # Progress Photos feature (data/presentation)
│   └── views/hom.dart           # Home screen (redesigned workout overview + legacy panel)
├── l10n/                      # ARB source files + generated AppLocalizations
├── firebase_options.dart      # FlutterFire-generated config
├── service_locator.dart       # GetIt registrations
└── main.dart                  # App entry point, Hive/adapters bootstrap
```

Each feature (`workout`, `measurements`, `progress_photos`) is self-contained: its own Hive box(es), Cubit(s), and screens, so they never interfere with one another. Within `workout`, every new Hive field was added additively (never renumbered or repurposed) so pre-existing exercise history keeps loading exactly as it always did.

## Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.9+ recommended)
- A Firebase project with Auth (Phone) and Firestore enabled
- Android Studio / Xcode for mobile builds

### Setup

```bash
# 1. Clone
git clone https://github.com/ahmedemad755/AE_Coaching.git
cd AE_Coaching

# 2. Install dependencies
flutter pub get

# 3. Run
flutter run
```

### Rebuilding after a change

```bash
# After changing a Hive model (@HiveType/@HiveField):
flutter pub run build_runner build --delete-conflicting-outputs

# After editing lib/l10n/*.arb:
flutter gen-l10n

# Before committing / opening a PR:
flutter analyze
flutter test
```

Firebase is already wired up via `lib/firebase_options.dart` (generated with the FlutterFire CLI) and `android/app/google-services.json`. If you fork this project for your own Firebase project, re-run:

```bash
flutterfire configure
```

## Platform Status

| Platform | Status |
|---|---|
| Android | ✅ Builds and installs successfully |
| iOS | ⚠️ Needs a macOS/Xcode environment to build and verify — `GoogleService-Info.plist` is not yet present in `ios/Runner/` (Firebase falls back to the config in `firebase_options.dart`, but this hasn't been confirmed on a real device) |
| Windows | ✅ Desktop support enabled |
| Web | ❌ Not supported — several features (photo storage, screenshot sharing) rely on `dart:io`, which Flutter Web doesn't support |

**Before publishing to app stores:** the Android `applicationId` (`com.example.ae_coaching`) and iOS bundle identifier (`com.example.aeCoaching`) are still Flutter's default placeholders and must be changed to a real, unique identifier registered in your Play Console / Apple Developer account.

## Data & Privacy

- Workout programs/days/sessions/sets and body measurements are stored locally (Hive) and synced to Firestore under `users/{uid}/...`, scoped per authenticated user.
- Progress photos are stored **locally only** — they are not uploaded anywhere and will be lost if the app is uninstalled.
- Deleting a program or a workout day is permanent and cascades to everything under it; archiving either one is the safe, reversible alternative and is what the UI defaults to.

## Testing

The workout feature has a large automated test suite (repositories, Cubits, and pure domain services) — no mocking package, hand-rolled fakes, real Hive boxes in a temp directory per test. Run it with:

```bash
flutter test
```

One widget-test file targets a real device/emulator render pipeline and is environment-dependent; the logic it would exercise is already covered by the Cubit-level tests above it.

## License

No license file is currently included in this repository.
