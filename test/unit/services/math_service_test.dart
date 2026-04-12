import 'package:flutter_test/flutter_test.dart';
import 'package:aliolo/data/services/math_service.dart';

void main() {
  late MathService mathService;

  setUp(() {
    mathService = MathService();
  });

  group('MathService', () {
    test('generateDistractors should return correct count of options', () {
      const correct = 10;
      const count = 6;
      final distractors = mathService.generateDistractors(correct, count);

      expect(distractors.length, equals(count));
      expect(distractors.contains(correct.toString()), isTrue);
    });

    test('generateDistractors should return unique values', () {
      const correct = 10;
      const count = 6;
      final distractors = mathService.generateDistractors(correct, count);

      final uniqueDistractors = distractors.toSet();
      expect(uniqueDistractors.length, equals(distractors.length));
    });

    test('generateDistractors should handle small correct values', () {
      const correct = 1;
      const count = 4;
      final distractors = mathService.generateDistractors(correct, count);

      expect(distractors.length, equals(count));
      expect(distractors.contains(correct.toString()), isTrue);
      // Ensure all distractors are non-negative
      for (var d in distractors) {
        expect(int.parse(d) >= 0, isTrue);
      }
    });
   group('generateProblem', () {
      // We can add more tests here for generateProblem by mocking SubjectModel
    });
  });
}
