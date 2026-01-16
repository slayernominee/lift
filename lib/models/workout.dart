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
    return Workout(
      id: const Uuid().v4(),
      name: name,
    );
  }

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

  factory WorkoutExercise.create({required String exerciseId, int targetSets = 3}) {
    return WorkoutExercise(
      id: const Uuid().v4(),
      exerciseId: exerciseId,
      targetSets: targetSets,
    );
  }

  @override
  List<Object?> get props => [id, exerciseId, targetSets];
}
