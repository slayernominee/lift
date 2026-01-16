import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'weight.g.dart';

@HiveType(typeId: 5)
class WeightEntry extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date;

  @HiveField(2)
  double weight;

  @HiveField(3)
  String? note;

  WeightEntry({
    required this.id,
    required this.date,
    required this.weight,
    this.note,
  });

  factory WeightEntry.create({
    required double weight,
    required DateTime date,
    String? note,
  }) {
    return WeightEntry(
      id: const Uuid().v4(),
      date: date,
      weight: weight,
      note: note,
    );
  }

  @override
  List<Object?> get props => [id, date, weight, note];
}
