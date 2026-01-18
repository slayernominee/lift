import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lift/models/exercise.dart';
import 'package:lift/models/workout.dart';
import 'package:lift/models/log.dart';
import 'package:lift/models/weight.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

class WorkoutProvider with ChangeNotifier {
  final Box<Exercise> _exerciseBox = Hive.box<Exercise>('exercises');
  final Box<Workout> _workoutBox = Hive.box<Workout>('workouts');
  final Box<ExerciseLog> _logBox = Hive.box<ExerciseLog>('logs');
  final Box<WeightEntry> _weightBox = Hive.box<WeightEntry>('weights');

  WorkoutProvider() {
    _initDefaults();
  }

  // --- Getters ---
  List<Exercise> get exercises => _exerciseBox.values.toList();
  List<Workout> get workouts => _workoutBox.values.toList();
  List<WeightEntry> get weightEntries =>
      _weightBox.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  // --- Exercise Methods ---
  void addExercise(Exercise exercise) {
    _exerciseBox.put(exercise.id, exercise);
    notifyListeners();
  }

  Exercise? getExerciseById(String id) {
    return _exerciseBox.get(id);
  }

  // --- Workout Methods ---
  void addWorkout(Workout workout) {
    _workoutBox.put(workout.id, workout);
    notifyListeners();
  }

  void updateWorkout(Workout workout) {
    workout.save();
    notifyListeners();
  }

  void deleteWorkout(String id) {
    _workoutBox.delete(id);
    notifyListeners();
  }

  // --- Export/Import Methods ---
  Future<String> exportWorkouts() async {
    try {
      final workouts = _workoutBox.values.toList();

      if (workouts.isEmpty) {
        return 'No workouts to export.';
      }

      // Convert to JSON
      final List<Map<String, dynamic>> workoutsJson = workouts
          .map((w) => w.toJson())
          .toList();
      // Include exercise definitions in export for auto-creation during import
      final exerciseDefinitions = _exerciseBox.values
          .map((e) => e.toJson())
          .toList();

      final exportData = {
        'version': '1.1.0',
        'exercises': exerciseDefinitions,
        'workouts': workoutsJson,
      };
      final jsonString = jsonEncode(exportData);
      final bytes = utf8.encode(jsonString);

      // Use file picker to let user choose save location
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Workouts Export',
        fileName: 'workouts_export_$timestamp.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes, // Required for mobile (iOS/Android)
      );

      if (outputPath == null) {
        return 'Export cancelled.';
      }

      return 'Exported ${workouts.length} workout(s) to:\n$outputPath';
    } catch (e) {
      return 'Export failed: ${e.toString()}';
    }
  }

  Future<Map<String, dynamic>> importWorkouts() async {
    try {
      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return {'success': false, 'message': 'No file selected'};
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      // Parse JSON - new format: {version, exercises, workouts/workout}
      final exportData = jsonDecode(jsonString) as Map<String, dynamic>;
      final exercisesData = exportData['exercises'] as List<dynamic>?;

      int exercisesCreated = 0;

      // Auto-create missing exercises from definitions
      if (exercisesData != null) {
        for (final exJson in exercisesData) {
          final exerciseData = exJson as Map<String, dynamic>;
          final exerciseId = exerciseData['id'] as String;

          // Create exercise if it doesn't exist
          if (!_exerciseBox.containsKey(exerciseId)) {
            final exercise = Exercise.fromJson(exerciseData);
            _exerciseBox.put(exercise.id, exercise);
            exercisesCreated++;
          }
        }
      }

      // Get workouts list - handle both 'workouts' (array) and 'workout' (single object)
      final workoutsData = exportData['workouts'] as List<dynamic>?;
      final workoutData = exportData['workout'] as Map<String, dynamic>?;

      final List<dynamic> jsonList;
      if (workoutsData != null) {
        jsonList = workoutsData;
      } else if (workoutData != null) {
        jsonList = [workoutData];
      } else {
        jsonList = [];
      }

      int imported = 0;
      int skipped = 0;

      // Import workouts
      for (final jsonItem in jsonList) {
        final workoutJson = jsonItem as Map<String, dynamic>;
        final exercisesList = workoutJson['exercises'] as List<dynamic>;

        // Create new workout with new ID to avoid conflicts
        final newWorkout = Workout(
          id: const Uuid().v4(),
          name: workoutJson['name'] as String,
          exercises: exercisesList
              .map(
                (e) => WorkoutExercise(
                  id: const Uuid().v4(),
                  exerciseId: e['exerciseId'] as String,
                  targetSets: e['targetSets'] as int,
                ),
              )
              .toList(),
        );

        // Only add if name doesn't already exist
        final nameExists = _workoutBox.values.any(
          (w) => w.name == newWorkout.name,
        );
        if (!nameExists) {
          _workoutBox.put(newWorkout.id, newWorkout);
          imported++;
        } else {
          skipped++;
        }
      }

      notifyListeners();

      String message = 'Imported $imported workout(s)';
      if (imported == 1 && jsonList.length == 1) {
        final workoutName = jsonList.first['name'] as String?;
        if (workoutName != null) {
          message = 'Imported "$workoutName"';
        }
      }
      if (exercisesCreated > 0) {
        message += ' and created $exercisesCreated exercise(s)';
      }
      if (skipped > 0) {
        message += ', skipped $skipped (duplicate names)';
      }

      return {
        'success': true,
        'message': message,
        'imported': imported,
        'skipped': skipped,
      };
    } catch (e) {
      return {'success': false, 'message': 'Import failed: ${e.toString()}'};
    }
  }

  // --- Single Workout Export Method ---
  Future<String> exportWorkout(Workout workout) async {
    try {
      // Convert to JSON
      final workoutJson = workout.toJson();

      // Get exercise definitions for auto-creation during import
      final exerciseIds = workout.exercises.map((e) => e.exerciseId).toSet();
      final exerciseDefinitions = exerciseIds
          .map((id) => _exerciseBox.get(id))
          .where((e) => e != null)
          .map((e) => e!.toJson())
          .toList();

      // Include exercise definitions in export
      final exportData = {
        'version': '1.1.0',
        'exercises': exerciseDefinitions,
        'workout': workoutJson,
      };
      final jsonString = jsonEncode(exportData);
      final bytes = utf8.encode(jsonString);

      // Use file picker to let user choose save location
      final safeName = workout.name
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_');
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Workout Export',
        fileName: 'workout_${safeName}_$timestamp.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes, // Required for mobile (iOS/Android)
      );

      if (outputPath == null) {
        return 'Export cancelled.';
      }

      return 'Exported "${workout.name}" to:\n$outputPath';
    } catch (e) {
      return 'Export failed: ${e.toString()}';
    }
  }

  // --- Log Methods ---
  List<ExerciseLog> getLogsForExercise(String exerciseId, String workoutId) {
    return _logBox.values
        .where(
          (log) => log.exerciseId == exerciseId && log.workoutId == workoutId,
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  ExerciseLog? getLog(String exerciseId, String workoutId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    try {
      return _logBox.values.firstWhere(
        (log) =>
            log.exerciseId == exerciseId &&
            log.workoutId == workoutId &&
            DateTime(
              log.date.year,
              log.date.month,
              log.date.day,
            ).isAtSameMomentAs(startOfDay),
      );
    } catch (_) {
      return null;
    }
  }

  void saveLog(ExerciseLog log) {
    _logBox.put(log.id, log);
    notifyListeners();
  }

  ExerciseLog? getLastLog(String exerciseId, String workoutId) {
    final logs = getLogsForExercise(exerciseId, workoutId);
    if (logs.isEmpty) return null;
    return logs.first;
  }

  // --- Reordering ---
  void reorderWorkoutExercise(Workout workout, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = workout.exercises.removeAt(oldIndex);
    workout.exercises.insert(newIndex, item);
    updateWorkout(workout);
  }

  // --- Weight Methods ---
  void addWeightEntry(WeightEntry entry) {
    _weightBox.put(entry.id, entry);
    notifyListeners();
  }

  void deleteWeightEntry(String id) {
    _weightBox.delete(id);
    notifyListeners();
  }

  // --- Initial Defaults ---
  void _initDefaults() {
    if (_exerciseBox.isEmpty) {
      final defaultExercises = [
        Exercise.create(name: 'Bench Press', muscleGroup: 'Chest'),
        Exercise.create(name: 'Squat', muscleGroup: 'Legs'),
        Exercise.create(name: 'Deadlift', muscleGroup: 'Back'),
        Exercise.create(name: 'Overhead Press', muscleGroup: 'Shoulders'),
        Exercise.create(name: 'Barbell Row', muscleGroup: 'Back'),
        Exercise.create(name: 'Pull Ups', muscleGroup: 'Back'),
        Exercise.create(name: 'Bicep Curl', muscleGroup: 'Arms'),
        Exercise.create(name: 'Tricep Extension', muscleGroup: 'Arms'),
        Exercise.create(name: 'Lunges', muscleGroup: 'Legs'),
        Exercise.create(name: 'Lateral Raises', muscleGroup: 'Shoulders'),
        Exercise.create(name: 'Plank', muscleGroup: 'Core'),
      ];
      for (var e in defaultExercises) {
        _exerciseBox.put(e.id, e);
      }

      if (_workoutBox.isEmpty) {
        final fullBody = Workout.create(name: 'Full Body Session');
        fullBody.exercises.addAll([
          WorkoutExercise.create(exerciseId: defaultExercises[1].id), // Squat
          WorkoutExercise.create(exerciseId: defaultExercises[0].id), // Bench
          WorkoutExercise.create(
            exerciseId: defaultExercises[2].id,
          ), // Deadlift
          WorkoutExercise.create(exerciseId: defaultExercises[10].id), // Plank
        ]);
        _workoutBox.put(fullBody.id, fullBody);

        final upperBody = Workout.create(name: 'Upper Body Power');
        upperBody.exercises.addAll([
          WorkoutExercise.create(
            exerciseId: defaultExercises[3].id,
          ), // OH Press
          WorkoutExercise.create(
            exerciseId: defaultExercises[5].id,
          ), // Pull Ups
          WorkoutExercise.create(
            exerciseId: defaultExercises[6].id,
          ), // Bicep Curls
          WorkoutExercise.create(
            exerciseId: defaultExercises[7].id,
          ), // Tricep Ext
        ]);
        _workoutBox.put(upperBody.id, upperBody);
      }
    }
  }
}
