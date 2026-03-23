import 'dart:math';
import 'package:aliolo/data/models/card_model.dart';

class MathService {
  static final MathService _instance = MathService._internal();
  factory MathService() => _instance;
  MathService._internal();

  ({String question, String answer, List<String> options}) generateProblem(
    int level,
  ) {
    // Logic for generating math problems...
    return (question: '2 + 2', answer: '4', options: ['3', '4', '5', '6']);
  }

  List<String> generateDistractors(int correct, int count) {
    final List<int> distractors = [];
    final random = Random();
    
    // Attempt to generate unique distractors near the correct answer
    int attempts = 0;
    while (distractors.length < count - 1 && attempts < 100) {
      attempts++;
      // Range depends on the size of the answer
      int range = correct < 10 ? 5 : 10;
      int offset = random.nextInt(range * 2) - range; 
      int val = correct + offset;
      
      if (val >= 0 && val != correct && !distractors.contains(val)) {
        distractors.add(val);
      }
    }
    
    // If we still need more, just add some
    int fallback = 0;
    while (distractors.length < count - 1) {
      if (fallback != correct && !distractors.contains(fallback)) {
        distractors.add(fallback);
      }
      fallback++;
    }

    distractors.add(correct);
    distractors.shuffle();
    return distractors.map((e) => e.toString()).toList();
  }
}
