# Contributing to Lift

Thank you for your interest in contributing to **Lift**! This guide covers everything you need to know to set up your development environment, understand the codebase, and submit changes.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Overview](#project-overview)
- [Code Generation](#code-generation)
- [Running Tests](#running-tests)
- [Building](#building)
- [Code Style & Conventions](#code-style--conventions)
- [Architecture Summary](#architecture-summary)
- [Making Changes](#making-changes)
- [Commit Messages](#commit-messages)
- [Pull Requests](#pull-requests)
- [Reporting Issues](#reporting-issues)
- [License](#license)

---

## Code of Conduct

Be respectful, constructive, and helpful. We're all here to build something great together.

---

## Getting Started

### Prerequisites

- **Flutter SDK**: `^3.10.4` (stable channel recommended)
- **Dart SDK**: `^3.10.4`
- An IDE with Flutter support (VS Code with Flutter extension, or Android Studio / IntelliJ)
- A physical device or emulator for testing (Android or iOS)

### Verify your setup

```bash
flutter doctor
```

Ensure all checks pass with no critical issues.

---

## Development Setup

1. **Fork and clone the repository**:

   ```bash
   git clone https://github.com/<your-username>/lift.git
   cd lift
   ```

2. **Install dependencies**:

   ```bash
   flutter pub get
   ```

3. **Generate Hive adapters** (required before running):

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**:

   ```bash
   flutter run
   ```

---

## Project Overview

Lift is a privacy-first, offline gym workout tracker built with Flutter. Key features include workout management, exercise logging, statistics, body weight tracking, and data export/import — all 100% offline.

For a detailed technical breakdown, see [docs/ARCHITECTURE.md](ARCHITECTURE.md).

### Directory Layout

```
lib/
├── main.dart                    # Entry point, Hive init, theme
├── models/                      # Data models (Exercise, Workout, Log, Weight)
├── providers/                   # State management (WorkoutProvider)
├── screens/                     # UI screens
├── widgets/                     # Reusable UI components
└── database/                    # SQLite helper for set logs

assets/
└── exercises/                   # Exercise database (JSON) + GIF animations

test/                            # Unit tests
docs/                            # Documentation
```

---

## Code Generation

Lift uses Hive for local persistence, which requires generated adapters (`.g.dart` files).

**Generate once**:

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Watch for changes during development**:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

> **Important**: The `.g.dart` files are checked into version control. If you modify any model class (fields, HiveField annotations, etc.), you must re-run code generation before committing.

Models that require code generation:
- `lib/models/exercise.dart` → `exercise.g.dart` (TypeId: 0)
- `lib/models/workout.dart` → `workout.g.dart` (TypeId: 1, 2)
- `lib/models/weight.dart` → `weight.g.dart` (TypeId: 5)

`lib/models/log.dart` does **not** use Hive adapters (it's persisted in SQLite, not Hive).

---

## Running Tests

Run the full test suite:

```bash
flutter test
```

Run a specific test file:

```bash
flutter test test/providers/workout_provider_test.dart
flutter test test/logic/stats_logic_test.dart
```

Run with verbose output:

```bash
flutter test --reporter expanded
```

### Test Locations

| Area | Path |
|------|------|
| Provider logic (serialization, import/export) | `test/providers/workout_provider_test.dart` |
| Stats calculations | `test/logic/stats_logic_test.dart` |

When adding new business logic to `WorkoutProvider`, please add corresponding unit tests.

---

## Building

### Debug Build

```bash
flutter run
```

### Release APK

```bash
flutter build apk --release --no-tree-shake-icons
```

### Release App Bundle (for Play Store)

```bash
flutter build appbundle --no-tree-shake-icons
```

### Full build + test script

```bash
./build.sh
```

This runs tests, builds the APK, generates a SHA-256 checksum, and builds the App Bundle.

---

## Code Style & Conventions

### General

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines.
- Use `flutter analyze` to catch lint issues before committing.
- Maximum line length: 80 characters where practical.

### Naming

- **Files**: `snake_case.dart` (e.g., `workout_detail_screen.dart`)
- **Classes**: `PascalCase` (e.g., `WorkoutProvider`, `ExerciseTrackingScreen`)
- **Variables/fields**: `camelCase` (e.g., `workoutExercise`, `targetSets`)
- **Private fields**: Prefix with underscore (e.g., `_logs`, `_exerciseBox`)
- **Constants**: `camelCase` per Dart convention (e.g., `timerDuration`)

### State Management

- All state flows through `WorkoutProvider` (a `ChangeNotifier`).
- Screens read state using `Consumer<WorkoutProvider>` for reactive rebuilds.
- Mutations use `context.read<WorkoutProvider>()`.
- Always call `notifyListeners()` after state changes in the provider.

### Models

- Models use `EquatableMixin` for value equality.
- Hive models use `@HiveType` and `@HiveField` annotations.
- Provide a `create()` factory for new instances (generates UUID).
- Provide `toJson()` and `fromJson()` for serialization/export.

### UI

- The app uses **Material 3** with a dark indigo-slate theme.
- Cards use no elevation — use subtle borders instead (`borderRadius: 16`, 1px `BorderSide`).
- Follow the existing color palette defined in `main.dart`:
  - Background: `#020617`
  - Surface: `#0F172A`
  - Card: `#1E293B`
  - Border: `#334155`
  - Primary: `#6366F1`

### Navigation

- Manual `Navigator.push(MaterialPageRoute(...))` — no routing packages.
- Deep links are not currently supported.

---

## Architecture Summary

```
┌──────────────────────────────────────┐
│            Screens (UI)              │
├──────────────────────────────────────┤
│          Widgets (Reusable)          │
├──────────────────────────────────────┤
│        WorkoutProvider               │
│   (ChangeNotifier, all state)        │
├───────────────────┬──────────────────┤
│   Hive Boxes      │    SQLite DB     │
│ exercises/workouts│    set_logs      │
│ weights/settings  │                  │
└───────────────────┴──────────────────┘
```

**Key principle**: One provider, dual persistence (Hive for entities, SQLite for logs), all offline.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full technical documentation.

---

## Making Changes

### Workflow

1. **Create a branch** from `main`:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**, following the code style conventions above.

3. **Run code generation** if you modified models:

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run tests** to ensure nothing is broken:

   ```bash
   flutter test
   ```

5. **Run the analyzer**:

   ```bash
   flutter analyze
   ```

6. **Test manually** on a device/emulator, especially:
   - Creating/editing/deleting workouts and exercises
   - Logging sets and verifying completion indicators
   - Exporting and importing data
   - The rest timer across screen navigation
   - Weight tracking and charts

7. **Commit and push** your changes.

8. **Open a Pull Request** against the `main` branch.

### Types of Contributions

| Type | Examples |
|------|----------|
| Bug fixes | Fix crashes, incorrect behavior, UI glitches |
| New features | New screens, export formats, exercise metadata fields |
| Improvements | Performance, UX, accessibility, code quality |
| Documentation | README, architecture docs, code comments |
| Tests | Unit tests, widget tests, integration tests |
| Translations | Currently not supported, but welcome as a future feature |

### Adding a New Exercise Field

If you need to add a new field to the `Exercise` model:

1. Add the field to `lib/models/exercise.dart` with a `@HiveField(n)` annotation (use the next available number).
2. Run `dart run build_runner build --delete-conflicting-outputs`.
3. Update `toJson()` and `fromJson()` methods.
4. Update the exercise add/edit dialog in `ExercisesScreen`.
5. Note: This will require a database version bump or migration for existing users.

### Adding a New Screen

1. Create the file in `lib/screens/`.
2. If it's a new tab, add it to `_screens` and `destinations` in `HomeScreen`.
3. If it's a sub-screen, use `Navigator.push(MaterialPageRoute(...))` from the parent.
4. Use `Consumer<WorkoutProvider>` for reactive data.

---

## Commit Messages

Use clear, descriptive commit messages:

```
feat: add body fat percentage tracking to weight screen
fix: resolve crash when deleting exercise from empty workout
docs: update architecture documentation for v1.8
refactor: extract chart data filtering into reusable method
test: add tests for workout completion check logic
```

Prefix format:
- `feat:` — New feature
- `fix:` — Bug fix
- `docs:` — Documentation only
- `refactor:` — Code restructuring without behavior change
- `test:` — Adding or updating tests
- `chore:` — Build, dependencies, tooling

---

## Pull Requests

### Before Submitting

- [ ] Code compiles without errors (`flutter analyze` passes)
- [ ] Tests pass (`flutter test`)
- [ ] Generated files are up to date (`.g.dart` files)
- [ ] Tested on a device/emulator
- [ ] No unrelated changes in the PR
- [ ] PR description clearly explains the change and motivation

### PR Template

```markdown
## Description
Brief description of what this PR does.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How was this tested?

## Screenshots (if applicable)
Add screenshots for UI changes.

## Related Issues
Fixes #<issue-number>
```

### Review Process

1. A maintainer will review your PR.
2. Address any feedback by pushing additional commits.
3. Once approved, a maintainer will merge your PR.

---

## Reporting Issues

### Bug Reports

Open an issue at [GitHub Issues](https://github.com/slayernominee/lift/issues) with:

- **Device info**: OS version, device model
- **App version**: Found in Settings > About
- **Steps to reproduce**: Clear, numbered steps
- **Expected behavior**: What should happen
- **Actual behavior**: What actually happens
- **Screenshots/screen recordings**: If applicable

### Feature Requests

Open an issue with:

- **Use case**: What problem does this solve?
- **Proposed solution**: How should it work?
- **Alternatives considered**: Other approaches you've thought of

---

## License

By contributing to Lift, you agree that your contributions will be licensed under the **AGPL-3.0 License**. See the [LICENSE](../LICENSE) file for details.

---

Thanks for contributing to Lift! 🏋️
