import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lift/models/exercise.dart';
import 'package:lift/models/workout.dart';
import 'package:lift/models/log.dart';
import 'package:lift/models/weight.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:lift/database/database_helper.dart';

class WorkoutProvider with ChangeNotifier {
  final Box<Exercise> _exerciseBox = Hive.box<Exercise>('exercises');
  final Box<Workout> _workoutBox = Hive.box<Workout>('workouts');
  final Box<WeightEntry> _weightBox = Hive.box<WeightEntry>('weights');

  List<ExerciseLog> _logs = [];

  WorkoutProvider() {
    _initDefaults();
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'set_logs',
      orderBy: 'timestamp ASC, set_index ASC',
    );

    final Map<String, ExerciseLog> logMap = {};

    for (final map in maps) {
      final logId = map['log_id'] as String;
      if (!logMap.containsKey(logId)) {
        logMap[logId] = ExerciseLog(
          id: logId,
          exerciseId: map['exercise_uuid'] as String,
          workoutId: map['workout_uuid'] as String,
          date: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
          sets: [],
        );
      }

      logMap[logId]!.sets.add(
        ExerciseSet(
          weight: map['weight'] as double,
          reps: map['reps'] as int,
          completed: (map['completed'] as int) == 1,
        ),
      );
    }

    _logs = logMap.values.toList();

    notifyListeners();
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

  // --- Settings Methods ---
  int get timerDuration =>
      Hive.box<dynamic>('settings').get('timer_duration', defaultValue: 120);

  void setTimerDuration(int seconds) {
    Hive.box<dynamic>('settings').put('timer_duration', seconds);
    notifyListeners();
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

  Future<String> exportLogs() async {
    try {
      if (_logs.isEmpty) {
        return 'No logs to export.';
      }

      final StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln(
        'workout_uuid,exercise_uuid,timestamp,set_index,reps,weight,completed',
      );

      for (final log in _logs) {
        for (int i = 0; i < log.sets.length; i++) {
          final set = log.sets[i];
          csvBuffer.writeln(
            '${log.workoutId},${log.exerciseId},${log.date.millisecondsSinceEpoch},$i,${set.reps},${set.weight},${set.completed ? 1 : 0}',
          );
        }
      }

      final bytes = utf8.encode(csvBuffer.toString());
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Logs Export',
        fileName: 'logs_export_$timestamp.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (outputPath == null) {
        return 'Export cancelled.';
      }

      return 'Exported logs to:\n$outputPath';
    } catch (e) {
      return 'Export failed: ${e.toString()}';
    }
  }

  // --- Log Methods ---
  List<ExerciseLog> getLogsForExercise(String exerciseId, String workoutId) {
    return _logs
        .where(
          (log) => log.exerciseId == exerciseId && log.workoutId == workoutId,
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  ExerciseLog? getLog(String exerciseId, String workoutId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    try {
      return _logs.firstWhere(
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

  Future<void> saveLog(ExerciseLog log) async {
    // Save to Memory
    final index = _logs.indexWhere((l) => l.id == log.id);
    if (index >= 0) {
      _logs[index] = log;
    } else {
      _logs.add(log);
    }

    // Save to SQLite
    final db = await DatabaseHelper.instance.database;
    await db.delete('set_logs', where: 'log_id = ?', whereArgs: [log.id]);

    final batch = db.batch();
    for (int i = 0; i < log.sets.length; i++) {
      final set = log.sets[i];
      batch.insert('set_logs', {
        'log_id': log.id,
        'workout_uuid': log.workoutId,
        'exercise_uuid': log.exerciseId,
        'timestamp': log.date.millisecondsSinceEpoch,
        'set_index': i,
        'reps': set.reps,
        'weight': set.weight,
        'completed': set.completed ? 1 : 0,
      });
    }
    await batch.commit(noResult: true);

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

  // --- Data Reset Methods ---
  Future<void> resetAllData() async {
    // Clear all Hive boxes
    await _exerciseBox.clear();
    await _workoutBox.clear();
    await _weightBox.clear();

    // Clear all logs from SQLite database
    final db = await DatabaseHelper.instance.database;
    await db.delete('set_logs');

    // Clear in-memory logs
    _logs.clear();

    // Re-initialize default exercises
    _initDefaults();

    notifyListeners();
  }

  // --- Initial Defaults ---
  Future<void> _initDefaults() async {
    if (_exerciseBox.isEmpty) {
      // Load exercises from assets/exercises/exercises.json
      final exercises = await _loadExercisesFromAssets();
      for (var e in exercises) {
        _exerciseBox.put(e.id, e);
      }
    }

    // Create sample workouts from loaded exercises
    if (_workoutBox.isEmpty) {
      await _createSampleWorkouts();
    }
  }

  Future<void> _createSampleWorkouts() async {
    final exercises = _exerciseBox.values.toList();
    if (exercises.isEmpty) return;

    // Full Body Workout
    final fullBody = Workout.create(name: 'Full Body Session');

    // Find some exercises for full body
    final squat = exercises.firstWhere(
      (e) => e.targetMuscles.contains('quadriceps'),
      orElse: () => exercises[0],
    );
    final benchPress = exercises.firstWhere(
      (e) =>
          e.targetMuscles.contains('pectorals') ||
          e.targetMuscles.contains('chest'),
      orElse: () => exercises.length > 1 ? exercises[1] : exercises[0],
    );
    final plank = exercises.firstWhere(
      (e) =>
          e.targetMuscles.contains('abdominals') ||
          e.targetMuscles.contains('abs'),
      orElse: () => exercises.length > 2 ? exercises[2] : exercises[0],
    );
    final deadlift = exercises.firstWhere(
      (e) =>
          e.targetMuscles.contains('lower back') ||
          e.targetMuscles.contains('glutes'),
      orElse: () => exercises.length > 3 ? exercises[3] : exercises[0],
    );

    fullBody.exercises.addAll([
      WorkoutExercise.create(exerciseId: squat.id),
      WorkoutExercise.create(exerciseId: benchPress.id),
      WorkoutExercise.create(exerciseId: deadlift.id),
      WorkoutExercise.create(exerciseId: plank.id),
    ]);
    _workoutBox.put(fullBody.id, fullBody);

    // Upper Body Workout
    final upperBody = Workout.create(name: 'Upper Body Power');

    final overheadPress = exercises.firstWhere(
      (e) =>
          e.targetMuscles.contains('deltoids') ||
          e.targetMuscles.contains('shoulders'),
      orElse: () => exercises.length > 4 ? exercises[4] : exercises[0],
    );
    final pullUps = exercises.firstWhere(
      (e) =>
          e.targetMuscles.contains('latissimus dorsi') ||
          e.targetMuscles.contains('lats'),
      orElse: () => exercises.length > 5 ? exercises[5] : exercises[0],
    );
    final bicepCurl = exercises.firstWhere(
      (e) => e.targetMuscles.contains('biceps'),
      orElse: () => exercises.length > 6 ? exercises[6] : exercises[0],
    );
    final tricepExtension = exercises.firstWhere(
      (e) => e.targetMuscles.contains('triceps'),
      orElse: () => exercises.length > 7 ? exercises[7] : exercises[0],
    );

    upperBody.exercises.addAll([
      WorkoutExercise.create(exerciseId: overheadPress.id),
      WorkoutExercise.create(exerciseId: pullUps.id),
      WorkoutExercise.create(exerciseId: bicepCurl.id),
      WorkoutExercise.create(exerciseId: tricepExtension.id),
    ]);
    _workoutBox.put(upperBody.id, upperBody);

    // Lower Body Workout
    final lowerBody = Workout.create(name: 'Lower Body Power');

    final lunge = exercises.firstWhere(
      (e) =>
          e.targetMuscles.contains('quadriceps') ||
          e.targetMuscles.contains('glutes'),
      orElse: () => exercises.length > 8 ? exercises[8] : exercises[0],
    );
    final legPress = exercises.firstWhere(
      (e) =>
          e.targetMuscles.contains('quadriceps') &&
          e.bodyParts.contains('upper legs'),
      orElse: () => exercises.length > 9 ? exercises[9] : exercises[0],
    );
    final calfRaise = exercises.firstWhere(
      (e) =>
          e.targetMuscles.contains('calves') ||
          e.targetMuscles.contains('soleus'),
      orElse: () => exercises.length > 10 ? exercises[10] : exercises[0],
    );
    final legExtension = exercises.firstWhere(
      (e) =>
          e.targetMuscles.contains('quadriceps') &&
          e.bodyParts.contains('upper legs'),
      orElse: () => exercises.length > 11 ? exercises[11] : exercises[0],
    );

    lowerBody.exercises.addAll([
      WorkoutExercise.create(exerciseId: lunge.id),
      WorkoutExercise.create(exerciseId: legPress.id),
      WorkoutExercise.create(exerciseId: calfRaise.id),
      WorkoutExercise.create(exerciseId: legExtension.id),
    ]);
    _workoutBox.put(lowerBody.id, lowerBody);
  }

  Future<List<Exercise>> _loadExercisesFromAssets() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/exercises/exercises.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString) as List;

      return jsonList.map((json) {
        return Exercise(
          id: json['exerciseId'] as String,
          name: json['name'] as String,
          description: null,
          targetMuscles: (json['targetMuscles'] as List)
              .map((e) => e as String)
              .toList(),
          equipment: (json['equipments'] as List)
              .map((e) => e as String)
              .toList(),
          bodyParts: (json['bodyParts'] as List)
              .map((e) => e as String)
              .toList(),
          secondaryMuscles: (json['secondaryMuscles'] as List)
              .map((e) => e as String)
              .toList(),
          instructions: (json['instructions'] as List)
              .map((e) => e as String)
              .toList(),
          gifAsset: 'assets/exercises/media/${json['exerciseId']}.gif',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading exercises from assets: $e');
      return [];
    }
  }
}
