import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'exercise.g.dart';

@HiveType(typeId: 0)
class Exercise extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? description;

  @HiveField(3)
  String? muscleGroup;

  Exercise({
    required this.id,
    required this.name,
    this.description,
    this.muscleGroup,
  });

  factory Exercise.create({required String name, String? description, String? muscleGroup}) {
    return Exercise(
      id: const Uuid().v4(),
      name: name,
      description: description,
      muscleGroup: muscleGroup,
    );
  }

  @override
  List<Object?> get props => [id, name, description, muscleGroup];
}
