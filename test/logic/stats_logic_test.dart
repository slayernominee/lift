import 'package:flutter_test/flutter_test.dart';
import 'package:lift/models/log.dart';

void main() {
  group('Stats Logic Tests', () {
    test('Valid Set Counting Logic', () {
      // A set is considered valid if it has reps > 0 OR weight > 0 OR is marked as completed.
      // This ensures 0-rep sets that are explicitly logged (completed=true) are counted.

      final set1 = ExerciseSet(
        reps: 10,
        weight: 50,
        completed: true,
      ); // Valid: Normal set
      final set2 = ExerciseSet(
        reps: 0,
        weight: 0,
        completed: true,
      ); // Valid: Explicit 0-rep log
      final set3 = ExerciseSet(
        reps: 0,
        weight: 10,
        completed: false,
      ); // Valid: Has weight
      final set4 = ExerciseSet(
        reps: 5,
        weight: 0,
        completed: false,
      ); // Valid: Has reps
      final set5 = ExerciseSet(
        reps: 0,
        weight: 0,
        completed: false,
      ); // Invalid: Empty/Reset set

      final sets = [set1, set2, set3, set4, set5];

      final validSetsCount = sets.where((s) => s.isValid).length;

      expect(validSetsCount, 4, reason: 'Should count 4 valid sets out of 5');
    });

    test('Exercise Completion Logic', () {
      const targetSets = 3;

      // Case 1: Enough valid sets (including a 0-rep completed set)
      final setsSuccess = [
        ExerciseSet(reps: 10, weight: 10, completed: true),
        ExerciseSet(reps: 10, weight: 10, completed: true),
        ExerciseSet(reps: 0, weight: 0, completed: true), // Valid
      ];
      final validCountSuccess = setsSuccess.where((s) => s.isValid).length;
      expect(
        validCountSuccess >= targetSets,
        isTrue,
        reason: 'Exercise should be completed with 3 valid sets',
      );

      // Case 2: Not enough valid sets (one is invalid)
      final setsFail = [
        ExerciseSet(reps: 10, weight: 10, completed: true),
        ExerciseSet(reps: 10, weight: 10, completed: true),
        ExerciseSet(reps: 0, weight: 0, completed: false), // Invalid
      ];
      final validCountFail = setsFail.where((s) => s.isValid).length;
      expect(
        validCountFail >= targetSets,
        isFalse,
        reason: 'Exercise should NOT be completed with only 2 valid sets',
      );
    });
  });
}
