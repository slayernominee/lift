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
  List<String> targetMuscles;

  @HiveField(4)
  List<String> equipment;

  @HiveField(5)
  List<String> bodyParts;

  @HiveField(6)
  List<String> secondaryMuscles;

  @HiveField(7)
  List<String> instructions;

  @HiveField(8)
  String? gifAsset;

  Exercise({
    required this.id,
    required this.name,
    this.description,
    required this.targetMuscles,
    required this.equipment,
    required this.bodyParts,
    required this.secondaryMuscles,
    required this.instructions,
    this.gifAsset,
  });

  factory Exercise.create({
    required String name,
    String? description,
    List<String>? targetMuscles,
    List<String>? equipment,
    List<String>? bodyParts,
    List<String>? secondaryMuscles,
    List<String>? instructions,
    String? gifAsset,
  }) {
    return Exercise(
      id: const Uuid().v4(),
      name: name,
      description: description,
      targetMuscles: targetMuscles ?? [],
      equipment: equipment ?? [],
      bodyParts: bodyParts ?? [],
      secondaryMuscles: secondaryMuscles ?? [],
      instructions: instructions ?? [],
      gifAsset: gifAsset,
    );
  }

  String get primaryTargetMuscle =>
      targetMuscles.isNotEmpty ? targetMuscles.first : 'Other';

  String get instructionsAsText =>
      instructions.isNotEmpty ? instructions.join('\n\n') : '';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'targetMuscles': targetMuscles,
    'equipment': equipment,
    'bodyParts': bodyParts,
    'secondaryMuscles': secondaryMuscles,
    'instructions': instructions,
    'gifAsset': gifAsset,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['exerciseId'] as String,
    name: json['name'] as String,
    description: null,
    targetMuscles:
        (json['targetMuscles'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    equipment:
        (json['equipments'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    bodyParts:
        (json['bodyParts'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    secondaryMuscles:
        (json['secondaryMuscles'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    instructions:
        (json['instructions'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    gifAsset: json['gifUrl'] != null
        ? 'assets/exercises/media/${json['exerciseId'] as String}.gif'
        : null,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    targetMuscles,
    equipment,
    bodyParts,
    secondaryMuscles,
    instructions,
    gifAsset,
  ];
}
