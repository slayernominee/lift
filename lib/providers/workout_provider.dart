import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lift/models/exercise.dart';
import 'package:lift/models/workout.dart';
import 'package:lift/models/log.dart';
import 'package:lift/models/weight.dart';

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

  // --- Log Methods ---
  List<ExerciseLog> getLogsForExercise(String exerciseId, String workoutId) {
    return _logBox.values
        .where((log) => log.exerciseId == exerciseId && log.workoutId == workoutId)
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
            DateTime(log.date.year, log.date.month, log.date.day).isAtSameMomentAs(startOfDay),
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
          WorkoutExercise.create(exerciseId: defaultExercises[2].id), // Deadlift
          WorkoutExercise.create(exerciseId: defaultExercises[10].id), // Plank
        ]);
        _workoutBox.put(fullBody.id, fullBody);

        final upperBody = Workout.create(name: 'Upper Body Power');
        upperBody.exercises.addAll([
          WorkoutExercise.create(exerciseId: defaultExercises[3].id), // OH Press
          WorkoutExercise.create(exerciseId: defaultExercises[5].id), // Pull Ups
          WorkoutExercise.create(exerciseId: defaultExercises[6].id), // Bicep Curls
          WorkoutExercise.create(exerciseId: defaultExercises[7].id), // Tricep Ext
        ]);
        _workoutBox.put(upperBody.id, upperBody);
      }
    }
  }
}
