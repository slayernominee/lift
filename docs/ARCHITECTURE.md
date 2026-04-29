# Architecture Documentation

**Lift** — Modern, offline-first fitness tracker built with Flutter.

> **Version:** 1.9.0
> **License:** AGPL-3.0

---

## Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Architecture Layers](#architecture-layers)
- [Data Models](#data-models)
- [State Management](#state-management)
- [Persistence Layer](#persistence-layer)
- [Screens & Navigation](#screens--navigation)
- [Reusable Widgets](#reusable-widgets)
- [Asset Pipeline](#asset-pipeline)
- [Data Flow](#data-flow)
- [Export / Import System](#export--import-system)
- [Timer System](#timer-system)
- [Theme & UI Design](#theme--ui-design)
- [Testing](#testing)
- [Database Migration](#database-migration)
- [Key Design Decisions](#key-design-decisions)

---

## Overview

Lift is a privacy-first, 100% offline gym workout tracker. Users manage **workouts** (ordered lists of exercises), log sets during training sessions, track body weight over time, and review statistics. No accounts, no cloud, no analytics — all data stays on-device.

### Core User Flows

1. **Workout Management** — Create workouts, add/reorder/remove exercises, set target set counts.
2. **Exercise Logging** — During a workout, swipe through exercises in a pager, log weight/reps per set. Previous session values auto-populate as placeholders.
3. **Statistics** — Monthly view of completed workouts, exercises, total sets, and a training day calendar heatmap.
4. **Weight Tracking** — Log body weight with date/time stamps and view trends on a timeline chart.
5. **Data Portability** — Export/import workouts as JSON; export logs as CSV.

---

## Tech Stack

| Concern           | Package / Technology                                                               |
| ----------------- | ---------------------------------------------------------------------------------- |
| Framework         | Flutter (SDK `^3.10.4`)                                                            |
| Language          | Dart (SDK `^3.10.4`)                                                               |
| State Management  | `provider` (`^6.0.5`)                                                              |
| Local Persistence | `hive` + `hive_flutter` (`^2.2.3`) for entities, `sqflite` (`^2.4.2`) for set logs |
| Charts            | `fl_chart` (`^0.63.0`)                                                             |
| UUID Generation   | `uuid` (`^4.2.1`)                                                                  |
| Value Equality    | `equatable` (`^2.0.5`)                                                             |
| Date Formatting   | `intl` (`^0.18.1`)                                                                 |
| File Picker       | `file_picker` (`^8.1.6`)                                                           |
| Icons             | `font_awesome_flutter` (`^10.6.0`), built-in Material Icons                        |
| Calendar          | `table_calendar` (`^3.0.9`)                                                        |
| URL Launching     | `url_launcher` (`^6.2.1`)                                                          |
| Code Generation   | `build_runner`, `hive_generator`                                                   |

---

## Project Structure

```
lib/
├── main.dart                          # App entry point, Hive init, migration, theme
├── models/
│   ├── exercise.dart                  # Exercise entity (Hive TypeId: 0)
│   ├── exercise.g.dart                # Generated Hive adapter
│   ├── workout.dart                   # Workout (TypeId: 1) + WorkoutExercise (TypeId: 2)
│   ├── workout.g.dart                 # Generated Hive adapter
│   ├── log.dart                       # ExerciseLog + ExerciseSet (in-memory only)
│   ├── weight.dart                    # WeightEntry (TypeId: 5)
│   └── weight.g.dart                  # Generated Hive adapter
├── providers/
│   └── workout_provider.dart          # Single ChangeNotifier for all app state
├── screens/
│   ├── home_screen.dart               # Bottom navigation shell (5 tabs)
│   ├── workouts_screen.dart           # Workout list with reorder/delete
│   ├── workout_detail_screen.dart     # Single workout: exercises, reorder, export, duplicate
│   ├── exercises_screen.dart          # Exercise browser/search with filters
│   ├── exercise_pager.dart            # Vertical PageView for exercise tracking
│   ├── exercise_tracking_screen.dart  # Set logging UI per exercise
│   ├── stats_screen.dart              # Monthly statistics dashboard
│   ├── weight_screen.dart             # Body weight log + chart
│   └── settings_screen.dart           # Timer config, data management, about
├── widgets/
│   ├── exercise_timer.dart            # Rest timer (start/stop, countdown display)
│   ├── timeline_chart.dart            # Reusable fl_chart line chart with range controls
│   └── multi_select_widgets.dart      # Multi-select dialog & chip field for exercise metadata
└── database/
    └── database_helper.dart           # SQLite singleton for set_logs table

assets/
├── exercises/
│   ├── exercises.json                 # Full exercise database (~hundreds of entries)
│   ├── muscles.json                   # Muscle name catalog
│   ├── bodyparts.json                 # Body part catalog
│   ├── equipments.json                # Equipment catalog
│   ├── media/                         # Exercise GIF animations
│   ├── LICENSE                        # ExerciseDB license (AGPL-3.0)
│   ├── NOTE.md                        # Attribution note
│   └── README.md                      # ExerciseDB readme
└── images/
    └── logo.png                       # App icon

test/
├── logic/
│   └── stats_logic_test.dart          # Stats calculation tests
└── providers/
    └── workout_provider_test.dart     # Provider unit tests (serialization, import/export)
```

---

## Architecture Layers

Lift follows a straightforward layered architecture without routing packages or dependency injection frameworks. State flows top-down; events flow bottom-up via `Provider`.

```
┌──────────────────────────────────────────────────┐
│                   Screens                        │
│  (Stateful/Stateless widgets, Navigator.push)    │
├──────────────────────────────────────────────────┤
│                 Widgets                          │
│  (Reusable UI components: charts, timer, etc.)   │
├──────────────────────────────────────────────────┤
│              WorkoutProvider                     │
│  (Single ChangeNotifier – all business logic)    │
├──────────────────────────┬───────────────────────┤
│       Hive Boxes         │      SQLite DB        │
│  exercises | workouts    │     set_logs          │
│  weights   | settings    │                       │
└──────────────────────────┴───────────────────────┘
```

There is **one** provider (`WorkoutProvider`) that serves as the single source of truth. Screens read state via `Consumer<WorkoutProvider>` or `context.read<WorkoutProvider>()` for mutations.

---

## Data Models

### Exercise (`lib/models/exercise.dart`)

Stored in Hive box `exercises`. TypeId: `0`.

| Field              | Type           | HiveField | Description                                                    |
| ------------------ | -------------- | --------- | -------------------------------------------------------------- |
| `id`               | `String`       | 0         | UUID, also matches asset filename                              |
| `name`             | `String`       | 1         | Display name                                                   |
| `description`      | `String?`      | 2         | Optional description                                           |
| `targetMuscles`    | `List<String>` | 3         | Primary target muscle groups                                   |
| `equipment`        | `List<String>` | 4         | Required equipment                                             |
| `bodyParts`        | `List<String>` | 5         | Body part categories                                           |
| `secondaryMuscles` | `List<String>` | 6         | Secondary muscles worked                                       |
| `instructions`     | `List<String>` | 7         | Step-by-step instructions                                      |
| `gifAsset`         | `String?`      | 8         | Path to GIF in assets (e.g. `assets/exercises/media/<id>.gif`) |
| `notes`            | `String?`      | 9         | User-editable notes                                            |

Key factory: `Exercise.create(...)` generates a new UUID. `Exercise.fromJson(...)` handles both internal keys (`id`) and external ExerciseDB keys (`exerciseId`). Includes `toJson()` for export.

### Workout (`lib/models/workout.dart`)

Stored in Hive box `workouts`. TypeId: `1`.

| Field       | Type                    | HiveField | Description                         |
| ----------- | ----------------------- | --------- | ----------------------------------- |
| `id`        | `String`                | 0         | UUID                                |
| `name`      | `String`                | 1         | User-defined workout name           |
| `exercises` | `List<WorkoutExercise>` | 2         | Ordered list of exercise references |

### WorkoutExercise (`lib/models/workout.dart`)

Embedded within `Workout`. TypeId: `2`.

| Field        | Type     | HiveField | Description                         |
| ------------ | -------- | --------- | ----------------------------------- |
| `id`         | `String` | 0         | UUID for this workout-exercise link |
| `exerciseId` | `String` | 1         | Foreign key to `Exercise.id`        |
| `targetSets` | `int`    | 2         | Goal number of sets (default: 3)    |

`WorkoutExercise.create(exerciseId:)` factory for convenience.

### ExerciseLog (`lib/models/log.dart`)

**Not persisted in Hive.** Stored in SQLite via `DatabaseHelper`. Kept in-memory as a list on `WorkoutProvider._logs`.

| Field        | Type                | Description                  |
| ------------ | ------------------- | ---------------------------- |
| `id`         | `String`            | UUID                         |
| `exerciseId` | `String`            | Foreign key to `Exercise.id` |
| `workoutId`  | `String`            | Foreign key to `Workout.id`  |
| `date`       | `DateTime`          | Timestamp for the log entry  |
| `sets`       | `List<ExerciseSet>` | Actual sets performed        |

### ExerciseSet (`lib/models/log.dart`)

Embedded within `ExerciseLog`.

| Field       | Type     | Default | Description              |
| ----------- | -------- | ------- | ------------------------ |
| `weight`    | `double` | —       | Weight used (kg)         |
| `reps`      | `int`    | —       | Repetitions completed    |
| `completed` | `bool`   | `false` | Explicit completion flag |

`isValid` getter: `true` when `reps > 0 || weight > 0 || completed`.

### WeightEntry (`lib/models/weight.dart`)

Stored in Hive box `weights`. TypeId: `5`.

| Field    | Type       | HiveField | Description              |
| -------- | ---------- | --------- | ------------------------ |
| `id`     | `String`   | 0         | UUID                     |
| `date`   | `DateTime` | 1         | Date/time of measurement |
| `weight` | `double`   | 2         | Body weight in kg        |
| `note`   | `String?`  | 3         | Optional note            |

---

## State Management

### WorkoutProvider (`lib/providers/workout_provider.dart`)

A single `ChangeNotifier` that holds **all** application state:

```
WorkoutProvider
├── Hive Boxes (injected at construction)
│   ├── _exerciseBox: Box<Exercise>
│   ├── _workoutBox: Box<Workout>
│   └── _weightBox: Box<WeightEntry>
├── In-Memory State
│   ├── _logs: List<ExerciseLog>          (loaded from SQLite)
│   ├── _muscles: List<String>            (from assets)
│   ├── _bodyParts: List<String>          (from assets)
│   ├── _equipment: List<String>          (from assets)
│   ├── _timer: Timer?
│   ├── _secondsRemaining: int
│   └── _isTimerActive: bool
└── Settings (Hive 'settings' box)
    ├── workout_order: List<String>
    ├── timer_duration: int (seconds)
    ├── timer_end_time: int (millis)
    └── db_version: String
```

#### Initialization Flow

1. **Constructor** calls `_initDefaults()` → loads exercises from assets if box is empty, creates sample workouts.
2. `_initDatabase()` → loads all `set_logs` rows from SQLite, groups by `log_id` into `ExerciseLog` objects.
3. `_loadMetadata()` → reads `muscles.json`, `bodyparts.json`, `equipments.json` from assets.
4. `_checkActiveTimer()` → resumes any in-progress rest timer from persisted end time.

#### Key Getters

| Getter             | Returns             | Notes                               |
| ------------------ | ------------------- | ----------------------------------- |
| `exercises`        | `List<Exercise>`    | All values from Hive exercise box   |
| `workouts`         | `List<Workout>`     | Sorted by persisted `workout_order` |
| `logs`             | `List<ExerciseLog>` | In-memory list from SQLite          |
| `weightEntries`    | `List<WeightEntry>` | Sorted newest-first                 |
| `muscles`          | `List<String>`      | Muscle catalog for filters          |
| `bodyParts`        | `List<String>`      | Body part catalog for filters       |
| `equipment`        | `List<String>`      | Equipment catalog for filters       |
| `timerDuration`    | `int`               | Default rest timer in seconds (120) |
| `secondsRemaining` | `int`               | Countdown seconds for active timer  |
| `isTimerActive`    | `bool`              | Whether rest timer is running       |

#### Key Methods

| Method                                | Purpose                                                    |
| ------------------------------------- | ---------------------------------------------------------- |
| `addExercise(Exercise)`               | Persist a new exercise to Hive                             |
| `getExerciseById(String)`             | Lookup exercise by ID                                      |
| `addWorkout(Workout)`                 | Persist workout + append to order                          |
| `updateWorkout(Workout)`              | Call `save()` on Hive object + notify                      |
| `deleteWorkout(String)`               | Remove from Hive box + order list                          |
| `reorderWorkoutExercise(...)`         | Move exercise within workout's exercise list               |
| `saveLog(ExerciseLog)`                | Upsert log to in-memory list + SQLite batch insert         |
| `getLog(exerciseId, workoutId, date)` | Find existing log for specific day                         |
| `getLogsForExercise(...)`             | All logs for an exercise within a workout, newest-first    |
| `getLastLog(...)`                     | Most recent log (used for smart placeholders)              |
| `isWorkoutCompleted(...)`             | Checks all workout exercises have valid sets >= targetSets |
| `addWeightEntry(...)`                 | Persist weight entry                                       |
| `deleteWeightEntry(String)`           | Remove weight entry                                        |
| `startTimer()`                        | Begin rest countdown, persist end time                     |
| `stopTimer()`                         | Cancel timer, clear persisted end time                     |
| `exportWorkouts()`                    | Export all workouts + exercises to JSON file               |
| `importWorkouts()`                    | Import from JSON, auto-create missing exercises            |
| `exportWorkout(Workout)`              | Export single workout to JSON                              |
| `exportLogs()`                        | Export all logs to CSV                                     |
| `resetAllData()`                      | Clear all boxes + SQLite + re-init defaults                |

---

## Persistence Layer

Lift uses a **dual-database** strategy:

### Hive (NoSQL)

Used for entity storage where key-based access and code generation adapters are convenient.

| Box         | Key Type  | Value Type    | Purpose                           |
| ----------- | --------- | ------------- | --------------------------------- |
| `exercises` | `String`  | `Exercise`    | Exercise definitions              |
| `workouts`  | `String`  | `Workout`     | Workout configurations            |
| `weights`   | `String`  | `WeightEntry` | Body weight entries               |
| `settings`  | `dynamic` | `dynamic`     | App settings (order, timer, etc.) |

All Hive boxes are opened in `main.dart` before `runApp()`. Adapters are registered in order:

```dart
Hive.registerAdapter(ExerciseAdapter());       // typeId: 0
Hive.registerAdapter(WorkoutAdapter());        // typeId: 1
Hive.registerAdapter(WorkoutExerciseAdapter()); // typeId: 2
Hive.registerAdapter(WeightEntryAdapter());    // typeId: 5
```

### SQLite (sqflite)

Used for **set logs** because they require relational querying for statistics and CSV export.

Database: `lift.db`, version `1`.

**Table: `set_logs`**

| Column          | Type    | Description                        |
| --------------- | ------- | ---------------------------------- |
| `id`            | INTEGER | Auto-increment PK                  |
| `log_id`        | TEXT    | Groups sets into one ExerciseLog   |
| `workout_uuid`  | TEXT    | FK to Workout                      |
| `exercise_uuid` | TEXT    | FK to Exercise                     |
| `timestamp`     | INTEGER | Milliseconds since epoch           |
| `set_index`     | INTEGER | Position of the set within the log |
| `reps`          | INTEGER | Repetitions                        |
| `weight`        | REAL    | Weight in kg                       |
| `completed`     | INTEGER | 0 or 1 boolean                     |

`DatabaseHelper` is a singleton (`DatabaseHelper.instance`) that lazily initializes the database.

---

## Screens & Navigation

Navigation is entirely manual — no named routes or routing packages. Screens use `Navigator.push(MaterialPageRoute(...))`.

### HomeScreen

Bottom navigation bar with 5 tabs using `IndexedStack` (all screens stay in memory):

| Index | Label     | Screen            |
| ----- | --------- | ----------------- |
| 0     | Workouts  | `WorkoutsScreen`  |
| 1     | Exercises | `ExercisesScreen` |
| 2     | Stats     | `StatsScreen`     |
| 3     | Weight    | `WeightScreen`    |
| 4     | Settings  | `SettingsScreen`  |

### Navigation Map

```
HomeScreen
├── WorkoutsScreen
│   └── WorkoutDetailScreen
│       ├── ExercisesScreen (for adding exercises, with onSelect callback)
│       └── ExercisePager
│           └── ExerciseTrackingScreen (one per exercise in workout)
├── ExercisesScreen
│   └── (inline add/edit dialogs)
├── StatsScreen
├── WeightScreen
└── SettingsScreen
```

### Screen Details

#### WorkoutsScreen

- Lists all workouts with completion indicators (green checkmark if all exercises logged today).
- Swipe-to-delete with confirmation dialog.
- Reorder mode via toggle button in app bar.
- FAB to create new workout via dialog.
- Tap workout → navigates to `WorkoutDetailScreen`.

#### WorkoutDetailScreen

- Displays all exercises in the workout with circular progress indicators showing completed/target sets.
- **Reorder mode** — drag-and-drop to reorder exercises.
- Tap the progress circle to edit target sets.
- Swipe-to-delete to remove an exercise.
- Tap exercise card → navigates to `ExercisePager`.
- Overflow menu: **Export Workout** (JSON), **Duplicate Workout**.
- Tap title to rename workout.
- `+` button adds exercises from `ExercisesScreen` (passed a `onSelect` callback).

#### ExercisesScreen

- Full exercise database browser with search bar and filter chips (body part, equipment, muscle).
- Each exercise card shows name, target muscles, and description.
- FAB to add custom exercises via a multi-field dialog (name, description, muscles, equipment, body parts, secondary muscles, instructions, notes).
- Long-press or edit icon to edit custom exercises.
- Can be opened in **selection mode** (`onSelect` callback) for adding exercises to workouts.

#### ExercisePager

- Wraps exercises in a vertical `PageView` with `NeverScrollableScrollPhysics`.
- Navigation via explicit previous/next callbacks from `ExerciseTrackingScreen` overscroll detection.
- Shows one `ExerciseTrackingScreen` at a time.
- Black background for focused workout experience.

#### ExerciseTrackingScreen

- **The core logging screen** — full-screen UI for logging one exercise.
- Date switcher at top (previous/next day with date picker).
- Exercise name, description, target muscles.
- Expandable details section (instructions, GIF, muscles, equipment).
- Set rows: each has weight input, reps input, and delete button.
- Smart placeholders: pre-fills weight/reps from `getLastLog()`.
- Rest timer integration.
- Add set button.
- History chart at bottom showing reps and volume over time via `TimelineChart`.
- Notes field per exercise per workout.

#### StatsScreen

- Monthly statistics dashboard.
- Month switcher (previous/next arrows + date picker).
- Calendar heatmap showing training days.
- Stat cards: **Finished Workouts**, **Completed Exercises**, **Total Sets**.
- Each card shows top 3 breakdowns by workout/exercise name.

#### WeightScreen

- Weight chart at top using `TimelineChart`.
- Chronological list of weight entries below.
- Swipe-to-delete entries.
- FAB to add new weight entry with date/time picker.

#### SettingsScreen

- **General**: Rest timer duration selector (30s–300s).
- **Data Management**: Export all workouts, import workouts, export logs (CSV), reset app.
- **About**: App logo, version, credits (ExerciseDB attribution), source code link, issue tracker, licenses.

---

## Reusable Widgets

### ExerciseTimer (`lib/widgets/exercise_timer.dart`)

- Consumes `WorkoutProvider` via `Consumer`.
- When inactive: shows a timer icon button that calls `startTimer()`.
- When active: shows a pill-shaped countdown (`MM:SS`), tap to `stopTimer()`.
- Formatted with zero-padded minutes and seconds.

### TimelineChart (`lib/widgets/timeline_chart.dart`)

- Configurable line chart built on `fl_chart`.
- Accepts two data series: `repsPoints` and `volumePoints` (both `List<ChartDataPoint>`).
- **Range switcher**: 1W, 1M, 3M, All — filters data and enables pagination arrows.
- **Metric switcher**: toggle between "Reps" and "Volume" data series.
- Swiping left/right on the chart paginates by the selected range.
- Styled with gradient fill under the line, dot markers, and subtle grid lines.
- Used in both `ExerciseTrackingScreen` (exercise history) and `WeightScreen` (weight trend).

### MultiSelectField / MultiSelectDialog (`lib/widgets/multi_select_widgets.dart`)

- Chip-based field that opens a searchable multi-select dialog.
- Used in exercise add/edit dialogs for selecting muscles, body parts, equipment.
- Shows selected items as dismissible chips.

### InstructionsField (`lib/widgets/multi_select_widgets.dart`)

- Multi-line text field that splits content by newlines into `List<String>`.
- Used for exercise instructions in the add/edit exercise dialog.

---

## Asset Pipeline

### Exercise Data

Exercise data comes from a fork of [ExerciseDB by ASCENDAPI](https://github.com/ExerciseDB/exercisedb-api), bundled as static JSON:

- `assets/exercises/exercises.json` — Full exercise catalog. Each entry has:
  - `exerciseId` (string) — maps to `Exercise.id`
  - `name`, `targetMuscles`, `equipments`, `bodyParts`, `secondaryMuscles`, `instructions`
- `assets/exercises/muscles.json` — `[{ "name": "..." }]` catalog
- `assets/exercises/bodyparts.json` — `[{ "name": "..." }]` catalog
- `assets/exercises/equipments.json` — `[{ "name": "..." }]` catalog
- `assets/exercises/media/<exerciseId>.gif` — Animation for each exercise

All loaded via `rootBundle.loadString()` in `WorkoutProvider._loadExercisesFromAssets()` and `_loadMetadata()`.

### On First Launch

1. `_initDefaults()` checks if `exercises` Hive box is empty.
2. If empty, reads `exercises.json` from assets and populates the box.
3. If `workouts` Hive box is empty, creates 3 sample workouts (Full Body, Upper Body, Lower Body) by matching exercises on target muscles.

---

## Data Flow

### Logging a Set

```
User types weight/reps in ExerciseTrackingScreen
  → _saveLog() called on every change
    → ExerciseLog.sets updated in-memory
    → WorkoutProvider.saveLog(log) called
      → Upsert into _logs list
      → Delete old rows from SQLite set_logs WHERE log_id = ?
      → Batch insert valid sets into SQLite
      → notifyListeners()
```

### Loading Exercise History

```
ExerciseTrackingScreen.initState()
  → _loadLog()
    → provider.getLog(exerciseId, workoutId, selectedDate)
      → Searches _logs for matching exerciseId + workoutId + date
    → provider.getLastLog(exerciseId, workoutId)
      → Returns most recent log for smart placeholders
```

### Workout Completion Check

```
WorkoutsScreen / WorkoutDetailScreen
  → provider.isWorkoutCompleted(workoutId, DateTime.now())
    → For each WorkoutExercise in the workout:
      → getLog(exercise.exerciseId, workoutId, date)
      → Count valid sets in the log
      → If valid sets < targetSets → return false
    → All exercises pass → return true
```

---

## Export / Import System

See [docs/workout_export_import.md](workout_export_import.md) for the full feature documentation.

### Export Formats

| Operation     | Format | Content                                                                      |
| ------------- | ------ | ---------------------------------------------------------------------------- |
| Export All    | JSON   | `{ version, exercises[], workouts[] }`                                       |
| Export Single | JSON   | `{ version, exercises[], workout }`                                          |
| Export Logs   | CSV    | `workout_uuid, exercise_uuid, timestamp, set_index, reps, weight, completed` |

### Import Behavior

- Reads JSON file via `FilePicker`.
- Auto-creates missing `Exercise` entries from included exercise definitions.
- Generates new UUIDs for imported workouts to avoid conflicts.
- Skips workouts with names that already exist (duplicate detection).
- Handles both single-workout and multi-workout export formats.

---

## Timer System

The rest timer persists across screen navigations and even app restarts:

1. **Start**: `startTimer()` calculates `endTime = now + duration` and stores it as `timer_end_time` in Hive `settings` box. A `Timer.periodic(1s)` ticks down.
2. **Tick**: `_updateTimer()` reads `timer_end_time` from Hive, computes remaining seconds, and calls `notifyListeners()`.
3. **Expire**: When `now >= endTime`, `stopTimer()` is called and double haptic feedback fires.
4. **Resume**: On provider construction, `_checkActiveTimer()` checks for a persisted `timer_end_time`. If it's in the future, the ticker resumes automatically.

This design ensures the timer survives:

- Navigating between exercises in the pager
- Switching tabs
- Closing and reopening the app (if the end time hasn't passed)

---

## Theme & UI Design

The app uses **Material 3** with a dark theme built around an indigo-slate palette:

```
Seed Color:       #6366F1  (Indigo)
Brightness:       Dark
Surface:          #0F172A  (Slate 900)
Background:       #020617  (Slate 950)
Card Color:       #1E293B  (Slate 800)
Card Border:      #334155  (Slate 700)
Input Fill:       #1E293B  (Slate 800)
Input Border:     #334155  (Slate 700)
Focus Border:     #6366F1  (Indigo)
Button Bg:        #6366F1  (Indigo)
```

Cards have no elevation; instead they use subtle 1px borders with rounded corners (16px radius). All text is white/light on dark backgrounds. The overall aesthetic is minimal, flat, and high-contrast.

---

## Testing

Tests live in the `test/` directory:

- `test/providers/workout_provider_test.dart` — Unit tests for the provider covering JSON serialization/deserialization, import logic, and round-trip fidelity.
- `test/logic/stats_logic_test.dart` — Unit tests for statistics calculation logic.

Run tests:

```bash
flutter test
```

Generate Hive adapters before running:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Database Migration

A one-time migration runs in `main.dart` before adapter registration:

```dart
Future<void> _migrateDatabase() async {
  // Checks 'db_version' in settings box
  // If version != '1.4.0':
  //   → Deletes exercises, workouts, weights boxes
  //   → Updates db_version to '1.4.0'
}
```

This was introduced in v1.4.0 due to a schema change that required a full data reset. The `settings` box is opened early (before other boxes) specifically for this check.

**Note**: Logs stored in SQLite are not affected by this migration; only Hive boxes are cleared.

---

## Key Design Decisions

### Single Provider

One `WorkoutProvider` manages all state. This avoids cross-provider coordination complexity for a small-to-medium app. If the app grows significantly, splitting into separate providers (e.g., `ExerciseProvider`, `LogProvider`, `WeightProvider`, `TimerProvider`) would be the natural refactoring path.

### Dual Persistence (Hive + SQLite)

- **Hive** excels at key-value lookups for entities (exercises, workouts, weight entries, settings).
- **SQLite** is better for the structured, queryable set log data (needed for stats aggregation, CSV export, and filtering by date/exercise/workout).

### In-Memory Log List

`ExerciseLog` objects are loaded from SQLite into a Dart `List` at startup. This enables fast lookups and UI responsiveness. Writes go to both the in-memory list and SQLite. The trade-off is that log data must fit in device memory — reasonable for a personal fitness tracker.

### No Routing Package

The app uses manual `Navigator.push` with `MaterialPageRoute`. This keeps the dependency list small and the navigation flow explicit. For a 5-tab app with shallow navigation depth, this is sufficient.

### UUID-Based IDs

All entities use UUID v4 for primary keys. This allows safe import/export without ID collisions and enables offline creation without server coordination.

### IndexedStack for Tabs

`HomeScreen` uses `IndexedStack` to keep all 5 tab screens alive. This preserves scroll position, search state, and form data when switching tabs, at the cost of higher memory usage.

### Asset-Bundled Exercise Data

Exercises ship as JSON in the app bundle. This eliminates the need for a first-launch network download, keeping the app truly offline-first. The trade-off is a larger APK/AAB size due to exercise GIFs.

### Smart Placeholders

When logging an exercise, the app looks up the most recent log for that exercise in that specific workout via `getLastLog()`. Weight and rep values from the previous session are pre-filled, reducing data entry during workouts.
