# Workout Export/Import Feature

## Overview

The workout export/import feature allows users to:

- **Export** their workouts to a JSON file for backup or sharing
- **Import** workout configurations from JSON files to restore or share workout routines
- **Choose custom export locations** for better file management
- **Share individual workouts** directly from the workout detail screen
- **Duplicate workouts** for quick variations

This feature is particularly useful for:

- Backing up workout configurations to custom locations
- Sharing workout plans with friends
- Transferring workouts between devices
- Creating and distributing workout templates
- Managing multiple workout libraries

## Feature Locations

### General Export/Import (All Workouts)

Accessed from the **About** screen (Settings > About):

- **Export All Workouts** - Exports all workouts to a JSON file
- **Import Workouts** - Imports workout configurations from a JSON file

### Per-Workout Export/Duplicate

Accessed from the **Workout Detail** screen (tap on a workout):

- **Menu (⋮)** > **Export Workout** - Exports the current workout to a JSON file
- **Menu (⋮)** > **Duplicate Workout** - Creates a copy of current workout

**Note**: All imports (both single and multiple workouts) are done through the **About** section.

## Usage

### Exporting All Workouts

1. Navigate to **Settings > About**
2. Tap **Export All Workouts**
3. Choose the file location using the system file picker
4. Confirm the save location and filename
5. A dialog will appear showing:
   - Number of workouts exported
   - Full path where the file was saved

The exported file is named: `workouts_export_YYYY-MM-DD.json`

### Importing Workouts

The import function in About section handles workout exports (both single and multiple):

1. Navigate to **Settings > About**
2. Tap **Import Workouts**
3. Select a JSON file containing workout data using the file picker
4. The app will automatically create any missing exercises from the export file
5. A dialog will appear showing:
   - Number of workouts successfully imported (or name if importing one)
   - Number of exercises created (if any)
   - Number of workouts skipped (due to duplicate names)

### Exporting a Single Workout

1. Navigate to the workout you want to export
2. Tap the **menu icon (⋮)** in the app bar
3. Select **Export Workout**
4. Choose the file location using the system file picker
5. Confirm the save location and filename
6. A dialog will appear showing the export location

The exported file is named: `workout_[name]_YYYY-MM-DD.json`

All exported files include exercise definitions, so when imported, missing exercises are automatically created.

Note: All exports (single and multiple) use the same format with version 1.1.0, including exercise definitions for automatic creation during import.

### Duplicating a Workout

1. Navigate to the workout you want to duplicate
2. Tap the **menu icon (⋮)** in the app bar
3. Select **Duplicate Workout**
4. Enter a name for the new workout (default: "[name] (copy)")
5. Tap **Duplicate** to create the copy
6. The new workout will appear in your workouts list

## Export Format

Workouts are exported as JSON with different formats depending on how you export them. All exports include exercise definitions for automatic creation during import.

### Single Workout Export (from Workout Detail screen)

```json
{
  "version": "1.1.0",
  "exercises": [
    {
      "id": "exercise-uuid-1",
      "name": "Bench Press",
      "description": null,
      "muscleGroup": "Chest"
    }
  ],
  "workout": {
    "id": "uuid-1",
    "name": "Full Body Session",
    "exercises": [
      {
        "id": "uuid-2",
        "exerciseId": "exercise-uuid-1",
        "targetSets": 3
      }
    ]
  }
}
```

### Multiple Workouts Export (from About screen - "Export All Workouts")

```json
{
  "version": "1.1.0",
  "exercises": [
    {
      "id": "exercise-uuid-1",
      "name": "Bench Press",
      "description": null,
      "muscleGroup": "Chest"
    },
    {
      "id": "exercise-uuid-3",
      "name": "Overhead Press",
      "description": null,
      "muscleGroup": "Shoulders"
    }
  ],
  "workouts": [
    {
      "id": "uuid-1",
      "name": "Full Body Session",
      "exercises": [
        {
          "id": "uuid-2",
          "exerciseId": "exercise-uuid-1",
          "targetSets": 3
        }
      ]
    },
    {
      "id": "uuid-3",
      "name": "Upper Body Power",
      "exercises": [
        {
          "id": "uuid-4",
          "exerciseId": "exercise-uuid-3",
          "targetSets": 4
        }
      ]
    }
  ]
}
```

### Export Format Fields

| Field                            | Type             | Description                                                       |
| -------------------------------- | ---------------- | ----------------------------------------------------------------- |
| `version`                        | string           | Export format version for backwards compatibility                 |
| `exercises`                      | array (optional) | List of exercise definitions referenced by workouts               |
| `exercises[].id`                 | string           | Unique identifier for the exercise (UUID)                         |
| `exercises[].name`               | string           | Display name of the exercise                                      |
| `exercises[].description`        | string (null)    | Optional description of the exercise                              |
| `exercises[].muscleGroup`        | string (null)    | Optional muscle group categorization                              |
| `workouts` (or `workout`)        | array or object  | Single workout object (for single export) or array (for multiple) |
| `workout.id`                     | string           | Unique identifier for the workout (UUID)                          |
| `workout.name`                   | string           | Display name of the workout                                       |
| `workout.exercises`              | array            | List of exercises in the workout                                  |
| `workout.exercises[].id`         | string           | Unique identifier for the workout exercise entry (UUID)           |
| `workout.exercises[].exerciseId` | string           | Reference ID to the actual exercise                               |
| `workout.exercises[].targetSets` | number           | Number of sets for this exercise                                  |

### Field Descriptions

| Field                    | Type   | Description                                                               |
| ------------------------ | ------ | ------------------------------------------------------------------------- |
| `id`                     | string | Unique identifier for the workout (UUID)                                  |
| `name`                   | string | Display name of the workout                                               |
| `exercises`              | array  | List of exercises in the workout                                          |
| `exercises[].id`         | string | Unique identifier for the workout exercise entry (UUID)                   |
| `exercises[].exerciseId` | string | Reference ID to the actual exercise (must exist in your exercise library) |
| `exercises[].targetSets` | number | Number of sets for this exercise                                          |

## Import Behavior

### Auto-Creation of Exercises

When importing, the system automatically creates missing exercises if their definitions are included in the export file:

- **Modern exports (v1.1.0+)**: Include exercise definitions, so missing exercises are created automatically during import
- **Legacy exports**: May not include exercise definitions, resulting in warning messages

This ensures that workouts can be shared without requiring users to manually create exercises first.

### Duplicate Detection

When importing through the About section, the system checks for duplicate workout names:

- If importing a **single workout** and a workout with the same name already exists, it will be **skipped** with a message indicating it was skipped
- If importing **multiple workouts**, each workout is checked individually and duplicates are **skipped** (not failed)
- The import process continues for all valid workouts regardless of duplicates found

This prevents conflicts while allowing imports to complete successfully.

### ID Generation

During import:

- New UUIDs are generated for all imported workouts to avoid conflicts
- New UUIDs are generated for all workout exercise entries

This means you can safely import the same workout multiple times without ID conflicts.

## Technical Implementation

### Components

1. **Model Layer** (`lib/models/workout.dart`)
   - `Workout.toJson()` - Serializes workout to JSON
   - `Workout.fromJson()` - Deserializes JSON to workout
   - `WorkoutExercise.toJson()` - Serializes workout exercise to JSON
   - `WorkoutExercise.fromJson()` - Deserializes JSON to workout exercise

2. **Provider Layer** (`lib/providers/workout_provider.dart`)
   - `exportWorkouts()` - Exports all workouts to JSON file (with file picker)
   - `importWorkouts()` - Imports workouts from JSON file with validation (handles both single and multiple)
   - `exportWorkout()` - Exports single workout to JSON file (with file picker)

3. **UI Layer**
   - `lib/screens/about_screen.dart` - Import/Export buttons (handles all imports)
   - `lib/screens/workout_detail_screen.dart` - Per-workout export and duplicate
   - `lib/screens/workouts_screen.dart` - Main workouts list

### Dependencies

- `dart:io` - File I/O operations
- `dart:convert` - JSON encoding/decoding
- `file_picker` - File selection and save dialogs for both import and export
- `uuid` - Generating unique IDs

### File Picker Integration

The `file_picker` package is used for both import and export:

**For Export (saveFile)**:

```dart
final outputPath = await FilePicker.platform.saveFile(
  dialogTitle: 'Save Workouts Export',
  fileName: 'workouts_export_$timestamp.json',
  type: FileType.custom,
  allowedExtensions: ['json'],
);
```

**For Import (pickFiles)**:

```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['json'],
);
```

This provides a native, platform-appropriate experience for file operations.

## Testing

Unit tests are provided in `test/providers/workout_provider_test.dart` covering:

- JSON serialization for workouts and exercises
- JSON deserialization from valid JSON
- Round-trip serialization (serialize → deserialize)
- Missing exercise detection
- Duplicate name detection

Run tests with:

```bash
flutter test test/providers/workout_provider_test.dart
```

## Example Workflows

### Sharing a Single Workout

1. **Exporter**: Open the workout they want to share
2. **Exporter**: Tap menu (⋮) > Export Workout
3. **Exporter**: Choose save location and confirm
4. **Exporter**: Share the JSON file via email, messaging, or file sharing
5. **Importer**: Receive the JSON file
6. **Importer**: Navigate to Settings > About
7. **Importer**: Tap Import Workouts
8. **Importer**: Select the shared JSON file
9. **Importer**: Review import results (exercises are auto-created)

### Creating a Workout Backup

1. Navigate to Settings > About
2. Tap Export All Workouts
3. Choose your preferred backup location
4. Confirm the save location and filename
5. Store the exported file in a safe location

### Restoring from Backup

1. Locate your backup JSON file
2. Navigate to Settings > About
3. Tap Import Workouts
4. Select the backup file
5. Review import results (imported count, skipped count, warnings)

### Creating Workout Variations

1. Open a workout you want to base a variation on
2. Tap menu (⋮) > Duplicate Workout
3. Enter a descriptive name (e.g., "Full Body - Heavy Day")
4. Tap Duplicate
5. Edit the duplicated workout to make your changes

## Troubleshooting

### Export shows "Export cancelled"

This occurs when the file picker save dialog is cancelled. Ensure you:

- Select a valid location
- Confirm the save action
- Have write permissions to the chosen location

### Import shows "No file selected"

This occurs if the file picker is cancelled. Ensure you select a valid `.json` file.

### Import shows "A workout named 'X' already exists"

The import process will skip workouts with duplicate names rather than failing. The message will indicate which workouts were skipped. To import a duplicate workout:

- Rename the existing workout
- Rename the workout in the JSON file before importing

### Import shows missing exercises warnings

For modern exports (v1.1.0+), exercises are auto-created, so this warning should not appear. If you see this warning, it may indicate a corrupted export file.

### Duplicate workouts not importing

If a workout with the same name already exists, it will be skipped. To import it anyway:

1. Rename the existing workout
2. Re-import the file
3. The workout will be imported with the original name

## Import Format

All imports use the unified format:

| Feature                | Import Workouts                            |
| ---------------------- | ------------------------------------------ |
| **Location**           | About screen                               |
| **File Format**        | JSON with version, exercises, and workouts |
| **Duplicate Handling** | Skips duplicates                           |
| **Missing Exercises**  | Auto-creates from exercise definitions     |
| **Use Case**           | Single or multiple workout sharing/backup  |
| **Best For**           | All import operations                      |

**Note**: All imports go through the Import Workouts function in the About section, regardless of whether the file contains a single workout or multiple workouts. Exercises are automatically created from the definitions included in the export file.

## Best Practices

### Export Naming

When exporting, choose descriptive filenames:

- `workouts_backup_2024-01-15.json` - Clear date-based backup
- `push_day_template.json` - Descriptive workout name
- `my_complete_routine.json` - Purposeful naming

### Organizing Exports

Create folders for different purposes:

```
/Backups/
  monthly_backup_2024_01.json
  monthly_backup_2024_02.json

/Templates/
  push_template.json
  pull_template.json
  legs_template.json

/Shared/
  workout_for_friend.json
  gym_bro_routine.json
```

### Before Importing

1. **Review existing workouts**: Check for potential name conflicts
2. **Backup current data**: Export your current workouts before importing new ones
3. **Start with single import**: Test with one workout before importing many

### Version Control

Keep track of different workout versions:

```
full_body_v1.json - Original
full_body_v2.json - Modified with new exercises
full_body_final.json - Final polished version
```

## Future Enhancements

Potential improvements for future versions:

- **Selective Export**: Choose specific workouts to export in "Export All"
- **Merge Mode**: Option to merge instead of skipping duplicates
- **Version Support**: Handle different export format versions
- **Cloud Sync**: Sync workouts across devices via cloud storage
- **Bulk Operations**: Export/import multiple selected workouts
- **Export Preview**: Show what will be exported before confirming
- **Import Preview**: Show what will be imported before confirming
