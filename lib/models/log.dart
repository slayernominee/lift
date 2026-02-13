import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class ExerciseSet with EquatableMixin {
  double weight;
  int reps;
  bool completed;

  ExerciseSet({
    required this.weight,
    required this.reps,
    this.completed = false,
  });

  /// Returns true if the set has data or is explicitly marked as completed.
  bool get isValid => reps > 0 || weight > 0 || completed;

  @override
  List<Object?> get props => [weight, reps, completed];
}

class ExerciseLog with EquatableMixin {
  final String id;
  final String exerciseId;
  final String workoutId;
  final DateTime date;
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

  /// Returns the number of valid sets in this log.
  int get validSetCount => sets.where((s) => s.isValid).length;
}
