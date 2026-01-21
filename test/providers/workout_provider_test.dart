import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lift/models/exercise.dart';
import 'package:lift/models/workout.dart';
import 'package:lift/providers/workout_provider.dart';

void main() {
  group('Workout Serialization Tests', () {
    late Box<Exercise> exerciseBox;
    late Box<Workout> workoutBox;

    setUpAll(() async {
      Hive.init('./test_hive');
      Hive.registerAdapter(ExerciseAdapter());
      Hive.registerAdapter(WorkoutAdapter());
      Hive.registerAdapter(WorkoutExerciseAdapter());
      await Hive.openBox<Exercise>('exercises');
      await Hive.openBox<Workout>('workouts');
    });

    setUp(() {
      exerciseBox = Hive.box<Exercise>('exercises');
      workoutBox = Hive.box<Workout>('workouts');
      exerciseBox.clear();
      workoutBox.clear();
    });

    tearDown(() {
      exerciseBox.clear();
      workoutBox.clear();
    });

    tearDownAll(() async {
      await Hive.close();
    });

    group('Workout.toJson', () {
      test('should serialize workout with all fields', () {
        final exercise = Exercise.create(
          name: 'Bench Press',
          muscleGroup: 'Chest',
        );
        final workout = Workout.create(name: 'Test Workout');
        workout.exercises.add(
          WorkoutExercise.create(exerciseId: exercise.id, targetSets: 5),
        );
        exerciseBox.put(exercise.id, exercise);

        final json = workout.toJson();

        expect(json['id'], workout.id);
        expect(json['name'], 'Test Workout');
        expect(json['exercises'], isList);
        expect(json['exercises'].length, 1);
        expect(json['exercises'][0]['exerciseId'], exercise.id);
        expect(json['exercises'][0]['targetSets'], 5);
      });

      test('should serialize workout without exercises', () {
        final workout = Workout.create(name: 'Empty Workout');

        final json = workout.toJson();

        expect(json['id'], workout.id);
        expect(json['name'], 'Empty Workout');
        expect(json['exercises'], isEmpty);
      });

      test('should serialize workout with multiple exercises', () {
        final exercise1 = Exercise.create(name: 'Squat', muscleGroup: 'Legs');
        final exercise2 = Exercise.create(
          name: 'Bench Press',
          muscleGroup: 'Chest',
        );
        final workout = Workout.create(name: 'Full Body');
        workout.exercises.add(
          WorkoutExercise.create(exerciseId: exercise1.id, targetSets: 3),
        );
        workout.exercises.add(
          WorkoutExercise.create(exerciseId: exercise2.id, targetSets: 4),
        );

        final json = workout.toJson();

        expect(json['exercises'].length, 2);
        expect(json['exercises'][0]['exerciseId'], exercise1.id);
        expect(json['exercises'][0]['targetSets'], 3);
        expect(json['exercises'][1]['exerciseId'], exercise2.id);
        expect(json['exercises'][1]['targetSets'], 4);
      });
    });

    group('Workout.fromJson', () {
      test('should deserialize workout from valid JSON', () {
        final json = {
          'id': 'test-id',
          'name': 'Imported Workout',
          'exercises': [
            {'id': 'ex-1', 'exerciseId': 'bench-press', 'targetSets': 3},
          ],
        };

        final workout = Workout.fromJson(json);

        expect(workout.id, 'test-id');
        expect(workout.name, 'Imported Workout');
        expect(workout.exercises.length, 1);
        expect(workout.exercises[0].exerciseId, 'bench-press');
        expect(workout.exercises[0].targetSets, 3);
      });

      test('should deserialize workout with multiple exercises', () {
        final json = {
          'id': 'test-id',
          'name': 'Complex Workout',
          'exercises': [
            {'id': 'ex-1', 'exerciseId': 'squat', 'targetSets': 5},
            {'id': 'ex-2', 'exerciseId': 'bench', 'targetSets': 4},
            {'id': 'ex-3', 'exerciseId': 'deadlift', 'targetSets': 3},
          ],
        };

        final workout = Workout.fromJson(json);

        expect(workout.exercises.length, 3);
        expect(workout.exercises[0].exerciseId, 'squat');
        expect(workout.exercises[1].exerciseId, 'bench');
        expect(workout.exercises[2].exerciseId, 'deadlift');
      });

      test('should deserialize workout with empty exercises list', () {
        final json = {
          'id': 'test-id',
          'name': 'Empty Workout',
          'exercises': [],
        };

        final workout = Workout.fromJson(json);

        expect(workout.name, 'Empty Workout');
        expect(workout.exercises, isEmpty);
      });
    });

    group('WorkoutExercise.toJson', () {
      test('should serialize exercise with all fields', () {
        final exercise = WorkoutExercise.create(
          exerciseId: 'bench-press',
          targetSets: 4,
        );

        final json = exercise.toJson();

        expect(json['id'], exercise.id);
        expect(json['exerciseId'], 'bench-press');
        expect(json['targetSets'], 4);
      });

      test('should use default target sets if not specified', () {
        final exercise = WorkoutExercise.create(exerciseId: 'squat');

        final json = exercise.toJson();

        expect(json['targetSets'], 3);
      });
    });

    group('WorkoutExercise.fromJson', () {
      test('should deserialize exercise from valid JSON', () {
        final json = {'id': 'ex-id', 'exerciseId': 'deadlift', 'targetSets': 5};

        final exercise = WorkoutExercise.fromJson(json);

        expect(exercise.id, 'ex-id');
        expect(exercise.exerciseId, 'deadlift');
        expect(exercise.targetSets, 5);
      });
    });

    group('Serialization Round-trip', () {
      test('should preserve data through serialize/deserialize cycle', () {
        final originalWorkout = Workout.create(name: 'Round-trip Test');
        originalWorkout.exercises.add(
          WorkoutExercise.create(exerciseId: 'squat', targetSets: 5),
        );
        originalWorkout.exercises.add(
          WorkoutExercise.create(exerciseId: 'bench', targetSets: 4),
        );

        final json = originalWorkout.toJson();
        final deserializedWorkout = Workout.fromJson(json);

        expect(deserializedWorkout.id, originalWorkout.id);
        expect(deserializedWorkout.name, 'Round-trip Test');
        expect(deserializedWorkout.exercises.length, 2);
        expect(deserializedWorkout.exercises[0].exerciseId, 'squat');
        expect(deserializedWorkout.exercises[0].targetSets, 5);
        expect(deserializedWorkout.exercises[1].exerciseId, 'bench');
        expect(deserializedWorkout.exercises[1].targetSets, 4);
      });

      test('should handle JSON encoding and decoding', () {
        final workout = Workout.create(name: 'JSON Test');
        workout.exercises.add(
          WorkoutExercise.create(exerciseId: 'pull-up', targetSets: 3),
        );

        final json = workout.toJson();
        final jsonString = jsonEncode([json]);
        final decodedList = jsonDecode(jsonString) as List;
        final decodedJson = decodedList.first as Map<String, dynamic>;
        final decodedWorkout = Workout.fromJson(decodedJson);

        expect(decodedWorkout.name, 'JSON Test');
        expect(decodedWorkout.exercises.length, 1);
        expect(decodedWorkout.exercises[0].exerciseId, 'pull-up');
      });
    });

    group('Import Logic Tests', () {
      test('should handle single workout JSON object', () {
        final exercise = Exercise.create(
          name: 'Bench Press',
          muscleGroup: 'Chest',
        );
        exerciseBox.put(exercise.id, exercise);

        final singleWorkoutJson = {
          'version': '1.1.0',
          'exercises': [
            {
              'id': exercise.id,
              'name': 'Bench Press',
              'description': null,
              'muscleGroup': 'Chest',
            },
          ],
          'workout': {
            'id': 'single-workout-id',
            'name': 'Single Workout',
            'exercises': [
              {'id': 'ex-1', 'exerciseId': exercise.id, 'targetSets': 3},
            ],
          },
        };

        // This simulates what importWorkouts does with new format
        final exportData = singleWorkoutJson as Map<String, dynamic>;
        final workoutData = exportData['workout'] as Map<String, dynamic>;
        final List<dynamic> jsonList = [workoutData];

        expect(jsonList.length, 1);
        expect(jsonList.first['name'], 'Single Workout');
      });

      test('should handle multiple workouts JSON array', () {
        final exercise1 = Exercise.create(name: 'Squat', muscleGroup: 'Legs');
        final exercise2 = Exercise.create(
          name: 'Bench Press',
          muscleGroup: 'Chest',
        );
        exerciseBox.put(exercise1.id, exercise1);
        exerciseBox.put(exercise2.id, exercise2);

        final multipleWorkoutsJson = {
          'version': '1.1.0',
          'exercises': [
            {
              'id': exercise1.id,
              'name': 'Squat',
              'description': null,
              'muscleGroup': 'Legs',
            },
            {
              'id': exercise2.id,
              'name': 'Bench Press',
              'description': null,
              'muscleGroup': 'Chest',
            },
          ],
          'workouts': [
            {
              'id': 'workout-1',
              'name': 'Leg Day',
              'exercises': [
                {'id': 'ex-1', 'exerciseId': exercise1.id, 'targetSets': 5},
              ],
            },
            {
              'id': 'workout-2',
              'name': 'Chest Day',
              'exercises': [
                {'id': 'ex-2', 'exerciseId': exercise2.id, 'targetSets': 4},
              ],
            },
          ],
        };

        // This simulates what importWorkouts does with new format
        final exportData = multipleWorkoutsJson as Map<String, dynamic>;
        final workoutsData = exportData['workouts'] as List<dynamic>;
        final List<dynamic> jsonList = workoutsData;

        expect(jsonList.length, 2);
        expect(jsonList[0]['name'], 'Leg Day');
        expect(jsonList[1]['name'], 'Chest Day');
      });

      test('should auto-create missing exercises from new export format', () {
        // Clear exercises to start fresh
        exerciseBox.clear();

        final newFormatExport = {
          'version': '1.1.0',
          'exercises': [
            {
              'id': 'ex-1',
              'name': 'Deadlift',
              'description': null,
              'muscleGroup': 'Back',
            },
            {
              'id': 'ex-2',
              'name': 'Lat Pulldown',
              'description': 'Great for lats',
              'muscleGroup': 'Back',
            },
          ],
          'workouts': [
            {
              'id': 'workout-1',
              'name': 'Back Day',
              'exercises': [
                {'id': 'we-1', 'exerciseId': 'ex-1', 'targetSets': 5},
                {'id': 'we-2', 'exerciseId': 'ex-2', 'targetSets': 4},
              ],
            },
          ],
        };

        // Simulate import logic
        final dynamic jsonData = newFormatExport;
        final exportData = jsonData as Map<String, dynamic>;
        final exercisesData = exportData['exercises'] as List<dynamic>;

        // Auto-create missing exercises
        int exercisesCreated = 0;
        for (final exJson in exercisesData) {
          final exerciseData = exJson as Map<String, dynamic>;
          final exerciseId = exerciseData['id'] as String;

          // Create exercise if it doesn't exist
          if (!exerciseBox.containsKey(exerciseId)) {
            final exercise = Exercise.fromJson(exerciseData);
            exerciseBox.put(exercise.id, exercise);
            exercisesCreated++;
          }
        }

        // Verify exercises were created
        expect(exercisesCreated, 2);
        expect(exerciseBox.length, 2);

        final deadlift = exerciseBox.get('ex-1');
        expect(deadlift?.name, 'Deadlift');
        expect(deadlift?.muscleGroup, 'Back');

        final latPulldown = exerciseBox.get('ex-2');
        expect(latPulldown?.name, 'Lat Pulldown');
        expect(latPulldown?.description, 'Great for lats');
      });

      test('should skip existing exercises during auto-creation', () {
        // Create an existing exercise
        final existingExercise = Exercise.create(
          name: 'Bench Press',
          muscleGroup: 'Chest',
        );
        exerciseBox.put(existingExercise.id, existingExercise);
        final existingId = existingExercise.id;

        final newFormatExport = {
          'version': '1.1.0',
          'exercises': [
            {
              'id': existingId,
              'name': 'Bench Press',
              'description': null,
              'muscleGroup': 'Chest',
            },
            {
              'id': 'new-ex-1',
              'name': 'Incline Dumbbell Press',
              'description': null,
              'muscleGroup': 'Chest',
            },
          ],
        };

        // Simulate import logic
        final dynamic jsonData = newFormatExport;
        final exportData = jsonData as Map<String, dynamic>;
        final exercisesData = exportData['exercises'] as List<dynamic>;

        int exercisesCreated = 0;
        for (final exJson in exercisesData) {
          final exerciseData = exJson as Map<String, dynamic>;
          final exerciseId = exerciseData['id'] as String;

          if (!exerciseBox.containsKey(exerciseId)) {
            final exercise = Exercise.fromJson(exerciseData);
            exerciseBox.put(exercise.id, exercise);
            exercisesCreated++;
          }
        }

        // Only the new exercise should be created
        expect(exercisesCreated, 1);
        expect(exerciseBox.length, 2);

        // Original exercise should be unchanged
        final benchPress = exerciseBox.get(existingId);
        expect(benchPress?.id, existingId);
        expect(benchPress?.name, 'Bench Press');

        // New exercise should be created
        final newExercise = exerciseBox.get('new-ex-1');
        expect(newExercise?.name, 'Incline Dumbbell Press');
      });

      test('should handle single workout export format with exercises', () {
        // Clear exercises to start fresh
        exerciseBox.clear();

        final singleWorkoutWithExercises = {
          'version': '1.1.0',
          'exercises': [
            {
              'id': 'ex-1',
              'name': 'Squat',
              'description': null,
              'muscleGroup': 'Legs',
            },
          ],
          'workout': {
            'id': 'workout-1',
            'name': 'Leg Day',
            'exercises': [
              {'id': 'we-1', 'exerciseId': 'ex-1', 'targetSets': 5},
            ],
          },
        };

        // Simulate import logic for single workout format
        final dynamic jsonData = singleWorkoutWithExercises;
        final exportData = jsonData as Map<String, dynamic>;
        final exercisesData = exportData['exercises'] as List<dynamic>;
        final workoutData = exportData['workout'] as Map<String, dynamic>;

        // Auto-create exercises
        for (final exJson in exercisesData) {
          final exerciseData = exJson as Map<String, dynamic>;
          final exerciseId = exerciseData['id'] as String;

          if (!exerciseBox.containsKey(exerciseId)) {
            final exercise = Exercise.fromJson(exerciseData);
            exerciseBox.put(exercise.id, exercise);
          }
        }

        // Get workout list (single workout)
        final List<dynamic> jsonList = [workoutData];

        expect(jsonList.length, 1);
        expect(jsonList.first['name'], 'Leg Day');
        expect(exerciseBox.length, 1);
        expect(exerciseBox.get('ex-1')?.name, 'Squat');
      });

      test('should detect duplicate workout names', () {
        final existingWorkout = Workout.create(name: 'Existing Workout');
        workoutBox.put(existingWorkout.id, existingWorkout);

        final newWorkout = Workout.create(name: 'Existing Workout');

        final hasDuplicate = workoutBox.values.any(
          (w) => w.name == newWorkout.name,
        );

        expect(hasDuplicate, true);
      });

      test('should allow importing workouts with unique names', () {
        final existingWorkout = Workout.create(name: 'Existing Workout');
        workoutBox.put(existingWorkout.id, existingWorkout);

        final newWorkout = Workout.create(name: 'New Unique Workout');

        final hasDuplicate = workoutBox.values.any(
          (w) => w.name == newWorkout.name,
        );

        expect(hasDuplicate, false);
      });
    });
  });
}
