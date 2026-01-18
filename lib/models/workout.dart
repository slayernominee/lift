import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'workout.g.dart';

@HiveType(typeId: 1)
class Workout extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<WorkoutExercise> exercises;

  Workout({
    required this.id,
    required this.name,
    List<WorkoutExercise>? exercises,
  }) : exercises = exercises ?? [];

  factory Workout.create({required String name}) {
    return Workout(id: const Uuid().v4(), name: name);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
    id: json['id'] as String,
    name: json['name'] as String,
    exercises: (json['exercises'] as List<dynamic>)
        .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  @override
  List<Object?> get props => [id, name, exercises];
}

@HiveType(typeId: 2)
class WorkoutExercise extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String exerciseId;

  @HiveField(2)
  int targetSets;

  WorkoutExercise({
    required this.id,
    required this.exerciseId,
    this.targetSets = 3,
  });

  factory WorkoutExercise.create({
    required String exerciseId,
    int targetSets = 3,
  }) {
    return WorkoutExercise(
      id: const Uuid().v4(),
      exerciseId: exerciseId,
      targetSets: targetSets,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'targetSets': targetSets,
  };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) =>
      WorkoutExercise(
        id: json['id'] as String,
        exerciseId: json['exerciseId'] as String,
        targetSets: json['targetSets'] as int,
      );

  @override
  List<Object?> get props => [id, exerciseId, targetSets];
}
