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

  @HiveField(4)
  String? equipment;

  Exercise({
    required this.id,
    required this.name,
    this.description,
    this.muscleGroup,
    this.equipment,
  });

  factory Exercise.create({
    required String name,
    String? description,
    String? muscleGroup,
    String? equipment,
  }) {
    return Exercise(
      id: const Uuid().v4(),
      name: name,
      description: description,
      muscleGroup: muscleGroup,
      equipment: equipment,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'muscleGroup': muscleGroup,
    'equipment': equipment,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    muscleGroup: json['muscleGroup'] as String?,
    equipment: json['equipment'] as String?,
  );

  @override
  List<Object?> get props => [id, name, description, muscleGroup, equipment];
}
