import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'log.g.dart';

@HiveType(typeId: 3)
class ExerciseSet extends HiveObject with EquatableMixin {
  @HiveField(0)
  double weight;

  @HiveField(1)
  int reps;

  @HiveField(2)
  bool completed;

  ExerciseSet({
    required this.weight,
    required this.reps,
    this.completed = false,
  });

  @override
  List<Object?> get props => [weight, reps, completed];
}

@HiveType(typeId: 4)
class ExerciseLog extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String exerciseId;

  @HiveField(2)
  final String workoutId;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  List<ExerciseSet> sets;

  ExerciseLog({
    required this.id,
    required this.exerciseId,
    required this.workoutId,
    required this.date,
    List<ExerciseSet>? sets,
  }) : sets = sets ?? [];

  factory ExerciseLog.create({
    required String exerciseId,
    required String workoutId,
    required DateTime date,
  }) {
    return ExerciseLog(
      id: const Uuid().v4(),
      exerciseId: exerciseId,
      workoutId: workoutId,
      date: date,
    );
  }

  @override
  List<Object?> get props => [id, exerciseId, workoutId, date, sets];
}
